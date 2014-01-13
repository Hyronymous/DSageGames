module aahz.net.NetInternal;

public import aahz.net.NetConnections;
public import aahz.net.NetSocket;
public import aahz.util.Lockable;
public import aahz.util.TimeUpdate;
public import tango.core.Thread;

package:

template NetInternal(bool IS_SERVER) {	// Can be mixed in to either ServerManager or ClientManager for low-level code. Only slight differences in code, handled by static ifs. Presumes that Cache is defined
static private:
	const ulong PING_DELTA = 1_000;	// Ping a connection if we haven't seen it in at least a second
	const ulong DC_DELTA = 10_000;	// Consider it to have DCed if we haven't seen it for 10 seconds
	const ulong FLUSH_DELTA = 11_000;	// After a DC, drop all related information (extra second there just to not worry about any edges overlapping)
	const ulong RECONNECT_DELTA = 20_000;	// Allow a reconnection after 20 seconds
	
	TimeUpdate m_time;
	Thread m_timerThread;
	Lockable!(uint) m_unreliableID;
	NetConnections m_connections;
	
	void timerFunc() {	// Happens every 3/10th of a second. Checks stuff and does housecleaning, etc.
		ulong currTime;
		NetAddress[] drop;
		
		while (m_keepGoing) {
			m_time.update();
			currTime = m_time.time;

			static if (!IS_SERVER) {	// Check server load every ten seconds
				static ulong previousPing = 0;
				if ((currTime - previousPing) > 10_000UL) {
					previousPing = currTime;
					
					foreach (server; m_serverAddress) {
						if (server.clientCount < uint.max) {	// Since we're sending an unreliable packet, we can't guarantee a response. The server might be packed or simply have a bad connection. Either way, keep bumping the clientCount so that we are less likely to try and connect to it. If it's a clear connection, it will be bumped back quickly enough
							ulong temp = server.clientCount;
							temp += (server.clientCount >> 2) + 10;	// Add a quarter (and a little in case it's zero)
							if (temp > cast(ulong)uint.max) temp = uint.max; 
							server.clientCount = cast(uint)temp;
						}
						
						NetPacket packet;
						Internal.initPacket(packet, NetCommand.P2S_SERVER_STATUS);
						Internal.sendPacket(server.address, packet);
					}
				}
			}
			
			Cache.update( currTime );	// Clears out old data
			
			{
				m_connections.lockRead();
				scope (exit) m_connections.unlockRead();
				NetAddress[] spottedServers;
				
				foreach (source; m_connections) {
					if (!source.tryLock()) continue;	// Speed things up by skipping anyone busy
					
					static if (IS_SERVER) {
						if (source.isServer) {
							spottedServers.length = spottedServers.length + 1;
							spottedServers[$-1] = source.address;
						}
					}
					
					ulong lastSeenDelta = (currTime - source.lastSeen);
					if (lastSeenDelta < DC_DELTA) {	// If it hasn't DCed
						NetPacket packet;
						initPacket(packet, NetCommand.PACKET_STATUS);

						packet.write(source.reliableBase);
						packet.write(source.sequentialBase);
						packet.write(source.fragmentBase);
						packet.write(source.reliableBits);
						packet.write(source.sequentialBits);
						packet.write(source.fragmentBits);
						
						sendPacket(source.address, packet);	// Is an unreliable, non-encrypted packet, so ConnectionData is not altered. No need to lock it to the thread before calling sendPacket()
					}
					else if (lastSeenDelta >= RECONNECT_DELTA) {
						drop.length = drop.length + 1;
						drop[$-1] = source.address;	// Store for once we leave the foreach. (We can't modify m_connections in a foreach statement)
					}
					else if (
						lastSeenDelta >= FLUSH_DELTA	// If it can safely be considered DCed
						&& source.connected	// If it hasn't already been listed as DCed
					) {
						source.connected = false;
					}
					
					source.unlock();
				}
				
				static if (IS_SERVER) {	// Check what servers aren't connected and try to connect to them (if we are a server ourself)
					if (m_serverAddress.length != spottedServers.length) foreach (address; m_serverAddress) {
						bool found = false;
						
						for (uint L = 0; L < spottedServers.length; L++) {
							if (address == spottedServers[L]) {
								found = true;
								break;
							}
						}
						
						if (!found) {	// Not connected
							NetPacket packet;
							initPacket(packet, NetCommand.S2S_SERVER_CONNECT);
							sendPacket(address, packet);
						}
					}
					spottedServers.length = 0;
				}
			}
			
			foreach (address; drop) {
				connectionLost(address);	// Defined in both ClientManager and ServerManager
			}
			drop.length = 0;
			
			Thread.sleep(0.2);
		}
	}
	
static package:
	void init(char[] ip, ushort port) {
		m_unreliableID = new Lockable!(uint);
		m_connections = new NetConnections();
		
		Cache.open(m_folder);
		
		static if (IS_SERVER) {
			assert(ServerManager.m_cipher.blockSize == 16);	// NetPacket assumes this to be so and must be modified so that encrypted data (which gets padded to the block size) doesn't overfloat the packet size
			NetSocket.open(ip, port, 1000);
		}
		else {
			assert(ClientManager.m_cipher.blockSize == 16);	// NetPacket assumes this to be so and must be modified so that encrypted data (which gets padded to the block size) doesn't overfloat the packet size
			NetSocket.open(ip, port, 1000);
		}
	}
	
	void start() {
		m_time = new TimeUpdate();
		m_timerThread = new Thread(&timerFunc);	// Every 3/10th of a second
		m_timerThread.start();
	}
	
	void stop() {
		m_timerThread.join();
	}
	
	void cleanup() {
		NetSocket.close();
		Cache.close();
	}

	void initPacket(inout NetPacket packet, NetCommand cmd, uint queryID = 0, SendType sType = SendType.DEFAULT) {
		SendType reliability = DEFAULT_SEND_TYPE[cmd];
		if (sType != SendType.DEFAULT) reliability = sType;

		packet.command = cmd;
		packet.sendType = reliability;
		packet.queryID = queryID;
		efix!(uint)(packet.queryID);
		
		packet.packetSize = NetPacket.headerData.sizeof;
		packet.m_ptr = &packet.userData[0];
	}

	void initPacketX(inout NetPacketX packet, NetCommand cmd, SendType sType = SendType.DEFAULT) {
		if ((cmd & NetCommand.TYPE_MASK) != NetCommand.NORMAL) throw new Exception("NetCommand type cannot be QUERY nor REPLY");

		SendType reliability = DEFAULT_SEND_TYPE[cmd];
		if (sType != SendType.DEFAULT) reliability = sType;
		if (reliability != SendType.RELIABLE) throw new Exception("SendType cannot be UNRELIABLE nor SEQUENTIAL");
		
		packet.command = cmd;
		packet.sendType = SendType.RELIABLE;
		packet.fragmentAll = 0;
		
		packet.packetSize = NetPacket.headerData.sizeof;
		packet.m_ptr = &packet.userData[0];	// skip to the end of the data for next write (if there is any)
	}
	
	bool receivePacket(inout NetPacketX packet, inout NetAddress address) {
		if (!Cache.getCachedInput(packet, address)) {	// Grab something from the cache if there is something to be had. Otherwise go on and get new data from the socket
			size_t amount;
			NetThread t = cast(NetThread)NetThread.getThis();
			
			amount = NetSocket.read(packet.packetData, address);
			if (
				amount <= 0	// No data
				|| amount < NetPacket.headerData.sizeof
			) {
				return false;
			}
			
			efix!(uint)( packet.magic );
			if (packet.magic != AAHZ_MAGIC) return false;	// Ignore if its not our protocol
			else if (packet.nVersion > NET_VERSION) return false;	// Assume to be non-compatible. Ignore
			
			packet.packetSize = amount;
			efix!(uint)( packet.packetID );
			
			{
				m_connections.lockRead();
				scope (exit) m_connections.unlockRead();
				
				ConnectionData conn = m_connections.get(address);
				if (conn !is null) {	// Check if it's a connected user, and if so lock and save it to the thread's data
					if (!conn.connected) return false;	// Has been DCed
					t.push( conn );
					conn.lastSeen = m_time.time;
				}
			}
			if (packet.sendType == SendType.RELIABLE && t.conn is null) return false;	// Reliable packets can only come from connected sources
			
			if (	// Fragment
				packet.sendType == SendType.RELIABLE
				&& (packet.command & NetCommand.TYPE_MASK) == NetCommand.NORMAL
				&& packet.fragmentAll != 0
			) {
				efix!(ushort)(packet.fragmentCount);
				
				if (packet.encrypted) {
					ubyte[] buffer = new ubyte[ packet.fragmentCount * NetPacket.userData.length ];
					
					static if (IS_SERVER) {
						ClientData source;
						if (t.conn is null) return false;
						source = cast(ClientData)t.conn;
						
						synchronized (ServerManager.m_cipher) {
							ServerManager.m_cipher.init(ServerManager.m_cipher.DECRYPT, source.params);
							amount = ServerManager.m_cipher.update(packet.userData, buffer);
							ServerManager.m_cipher.finish(buffer[amount..buffer.length]);
						}
					}
					else {
						synchronized (ClientManager.m_cipher) {
							ClientManager.m_cipher.init(ClientManager.m_cipher.DECRYPT, ClientManager.m_params);
							amount = ClientManager.m_cipher.update(packet.userData, buffer);
							ClientManager.m_cipher.finish(buffer[amount..buffer.length]);
						}
					}
					
					delete buffer;
				}
			}
			else {	// Not fragment
				efix!(uint)(packet.queryID);
				
				if (packet.encrypted) {
					uint count;
					ubyte[] packetData = packet.userData[0..(amount - packet.headerData.sizeof)];
					ubyte[NetPacket.userData.length] buffer;
					
					static if (IS_SERVER) {
						ClientData source;
						if (t.conn is null) return false;
						source = cast(ClientData)t.conn;	
						
						synchronized (ServerManager.m_cipher) {
							ServerManager.m_cipher.init(ServerManager.m_cipher.DECRYPT, source.params);
							count = ServerManager.m_cipher.update(packetData, buffer);
							count += ServerManager.m_cipher.finish(buffer[count..$]);
						}
						packet.userData[0..count] = buffer[0..count];
						packet.packetSize = packet.headerData.sizeof + count;
					}
					else {
						synchronized (ClientManager.m_cipher) {
							ClientManager.m_cipher.init(ClientManager.m_cipher.DECRYPT, ClientManager.m_params);
							count = ClientManager.m_cipher.update(packetData, buffer);
							count += ClientManager.m_cipher.finish(buffer[count..$]);
						}
						packet.userData[0..count] = buffer[0..count];
						packet.packetSize = packet.headerData.sizeof + count;
					}
				}
			}
			packet.unwind();	// Ready it to be read
			
			if (packet.sendType == SendType.UNRELIABLE) {
				if ((packet.command & NetCommand.TYPE_MASK) != NetCommand.INTERNAL) {
					return true;	// No processing needed at the low-level
				}

				switch (packet.command) {	// Handle INTERNAL (low level) packets
				case NetCommand.PACKET_STATUS:	// Resend any packets which haven't arrived at the far end
					if (t.conn is null) return false;
					
					uint reliableBase;
					uint sequentialBase;
					uint fragmentBase;
					ubyte[] reliableBits;
					ubyte[] sequentialBits;
					ubyte[] fragmentBits;
					
					packet.read(reliableBase);
					packet.read(sequentialBase);
					packet.read(fragmentBase);
					packet.read(reliableBits);
					packet.read(sequentialBits);
					packet.read(fragmentBits);
					
					ubyte bit;
					uint diff = t.conn.reliableID - reliableBase + 1;
					if (diff > (reliableBits.length * 8)) diff = reliableBits.length * 8;
					
					for (uint L = 0; L < diff; L++) {
						bit = 0x1 << (L & 0x7);
						if ((bit & reliableBits[L]) == 0) {	// Packet hasn't been received. Resend
							NetPacket outPacket;
							
							if (
								Cache.getReliableOutput(
									reliableBase + L,
									address,
									outPacket
								)
							) {
								sendPacket(address, outPacket);
							}
						}
					}
					
					diff = t.conn.sequentialID - sequentialBase + 1;
					if (diff > (sequentialBits.length * 8)) diff = sequentialBits.length * 8;
					
					for (uint L = 0; L < diff; L++) {
						bit = 0x1 << (L & 0x7);
						if ((bit & sequentialBits[L]) == 0) {	// Packet hasn't been received. Resend
							NetPacket outPacket;
							
							if (
								Cache.getSequentialOutput(
									sequentialBase + L,
									address,
									outPacket
								)
							) {
								sendPacket(address, outPacket);
							}
						}
					}
					
					diff = t.conn.fragmentID - fragmentBase + 1;
					if (diff > fragmentBits.length) diff = fragmentBits.length;
					
					for (uint L = 0; L < diff; L++) {
						for (uint L2 = 0; L2 < 5; L2++) {
							bit = 1 << L2;
							if ((bit & fragmentBits[L]) == 0) {	// Packet hasn't been received. Resend
								NetPacket outPacket;
								
								if (
									Cache.getFragmentOutput(
										fragmentBase + L,
										cast(ushort)L2,
										address,
										outPacket
									)
								) {
									packet.fragmentCount = fragmentBits[L] >> 5;
									efix!(ushort)(packet.fragmentCount);
									sendPacket(address, outPacket);
								}
							}
						}
					}
				break;
				default:	// Ignore
				break;
				}

				if (t.conn !is null) t.pop();	// Release the connection data
				return false;	// Upper level doesn't get the packet
			}
			else {	// Reliable
				ulong currTime;
				synchronized (m_time) currTime = m_time.time;
				bool ret = Cache.received(currTime, address, packet);	// Will tell us whether the packet can be used as-is.
				if (!ret) t.pop();
				return ret;
			}
		}
		return true;
	}
	
	void sendPacket(inout NetAddress address, inout NetPacket packet) {
		size_t amount;
		NetThread t = cast(NetThread)NetThread.getThis();
		
		if (packet.resend) {	// Don't need to do modify packet contents. Everything is all ready to go and in the right endianess
			void[] outData = packet.packetData[0 .. packet.packetSize];
			NetSocket.write(outData, address);
			return;
		}
		
		switch (packet.sendType) {
		case SendType.UNRELIABLE:
			synchronized (m_unreliableID) {
				packet.packetID = m_unreliableID.x;
				++m_unreliableID.x;
			}
		break;
		case SendType.RELIABLE:
			packet.packetID = t.conn.reliableID;
			++t.conn.reliableID;
		break;
		case SendType.SEQUENTIAL:
			packet.packetID = t.conn.sequentialID;
			++t.conn.sequentialID;
		break;
		}
		efix!(uint)(packet.packetID);
		
		if (packet.encrypted) {
			ubyte[] plaintext = packet.userData[0..(packet.packetSize - packet.headerData.sizeof)];
			ubyte[NetPacket.userData.length] buffer;
			
			static if (IS_SERVER) {
				ClientData client = cast(ClientData)t.conn;
				
				synchronized (ServerManager.m_cipher) {
					ServerManager.m_cipher.init(ServerManager.m_cipher.ENCRYPT, client.params);
					amount = ServerManager.m_cipher.update(plaintext, buffer);
					ServerManager.m_cipher.finish(buffer[amount..buffer.length]);
				}
				packet.userData[0..$] = buffer[0..$];
				packet.packetSize = ServerManager.m_cipher.finishOutputSize(plaintext.length) + packet.headerData.sizeof;
			}
			else {	// is client
				synchronized (ClientManager.m_cipher) {
					ClientManager.m_cipher.init(ClientManager.m_cipher.ENCRYPT, ClientManager.m_params);
					amount = ClientManager.m_cipher.update(plaintext, buffer);
					ClientManager.m_cipher.finish(buffer[amount..buffer.length]);
				}
				packet.userData[0..$] = buffer[0..$];
				packet.packetSize = ClientManager.m_cipher.finishOutputSize(plaintext.length) + packet.headerData.sizeof;
			}
		}
		
		if (packet.sendType != SendType.UNRELIABLE) {
			Cache.sent(m_time.time, address, packet);
		}

		void[] outData = packet.packetData[0 .. packet.packetSize];
		NetSocket.write(outData, address);
	}
	
	void sendPacketX(inout NetAddress address, inout NetPacketX packet) {
		if (packet.sendType != SendType.RELIABLE) throw new Exception("NetPacketX can only be sent reliably");
		else if ((packet.command & NetCommand.TYPE_MASK) != NetCommand.NORMAL) throw new Exception("NetPacketX cannot be a query");

		NetThread t = cast(NetThread)NetThread.getThis();
		
		if (packet.encrypted) {
			uint count;
			ubyte[] plaintext = packet.userData[0..(packet.packetSize - packet.headerData.sizeof)];
			ubyte[NetPacketX.userData.length] buffer;
			
			static if (IS_SERVER) {
				ClientData client = cast(ClientData)t.conn;
				
				synchronized (ServerManager.m_cipher) {
					ServerManager.m_cipher.init(ServerManager.m_cipher.ENCRYPT, client.params);
					count = ServerManager.m_cipher.update(plaintext, buffer);
					count += ServerManager.m_cipher.finish(buffer[count..buffer.length]);
				}
				packet.userData[0..$] = buffer[0..$];
				packet.packetSize = count + packet.headerData.sizeof;
			}
			else {	// is client
				synchronized (ClientManager.m_cipher) {
					ClientManager.m_cipher.init(ClientManager.m_cipher.ENCRYPT, ClientManager.m_params);
					count = ClientManager.m_cipher.update(plaintext, buffer);
					count += ClientManager.m_cipher.finish(buffer[count..buffer.length]);
				}
				packet.userData[0..$] = buffer[0..$];
				packet.packetSize = count + packet.headerData.sizeof;
			}
		}
		
		uint uDataLength = packet.packetSize - NetPacket.headerData.sizeof;
		uint count = uDataLength / PacketMax.SINGLE;
		if ((uDataLength % PacketMax.SINGLE) != 0) ++count;
		
		if (count == 1) {	// Only one packet. Leave NetPacket.fragmentID as 0
			packet.packetID = t.conn.reliableID;
			++t.conn.reliableID;
			efix!(uint)(packet.packetID);
			
			Cache.sent(m_time.time, address, cast(NetPacket)packet);
			void[] outData = packet.packetData[0 .. packet.packetSize];
			NetSocket.write(outData, address);
		}
		else {	// Fragmented
			uint startPoint = 0;
			NetPacket[] oPack = new NetPacket[ count ];
			for (uint L = 0; L < count; L++) {
				oPack[L].headerData[0 .. $] = packet.headerData[0 .. $];
				oPack[L].fragment = L;
				efix!(ushort)(oPack[L].fragment);
				oPack[L].fragmentCount = count;
				efix!(ushort)(oPack[L].fragmentCount);
				
				uint copyAmount = startPoint + PacketMax.SINGLE;
				if (copyAmount > uDataLength) copyAmount = uDataLength;
				oPack[L].userData[0 .. copyAmount] = packet.userData[startPoint .. (startPoint + copyAmount)];
				oPack[L].packetSize = oPack[L].headerData.sizeof + copyAmount;
				
				oPack[L].packetID = t.conn.fragmentID;
				++t.conn.fragmentID;
				efix!(uint)(oPack[L].packetID);
				
				Cache.sent(m_time.time, address, oPack[L]);
				
				startPoint += copyAmount;
				uDataLength -= copyAmount;
			}
			
			for (uint L = 0; L < count; L++) {
				void[] outData = oPack[L].packetData[0 .. oPack[L].packetSize];
				NetSocket.write(outData, address);
			}
		}
	}
	
	void sendPacket(NetConnections connections, inout NetPacket packet) {
		size_t amount;
		NetThread t = cast(NetThread)NetThread.getThis();
		
		connections.lockRead();
		scope (exit) connections.unlockRead();
		
		if (packet.sendType == SendType.UNRELIABLE) {	// Don't need to lock
			synchronized (m_unreliableID) {
				packet.packetID = m_unreliableID.x;	// Send all as the same id
				++m_unreliableID.x;
			}
			efix!(uint)(packet.packetID);
			
			void[] outData = packet.packetData[0 .. packet.packetSize];
			foreach (conn; connections) NetSocket.write(outData, conn.address);
		}
		else {	// RELIABLE or SEQUENTIAL
			if (packet.encrypted) {
				ubyte[] plaintext = packet.userData[0..(packet.packetSize - packet.headerData.sizeof)];
				ubyte[NetPacket.userData.length] buffer;
				
				static if (IS_SERVER) {
					ClientData client = cast(ClientData)t.conn;
					
					synchronized (ServerManager.m_cipher) {
						ServerManager.m_cipher.init(ServerManager.m_cipher.ENCRYPT, client.params);
						amount = ServerManager.m_cipher.update(plaintext, buffer);
						ServerManager.m_cipher.finish(buffer[amount..buffer.length]);
					}
					packet.userData[0..$] = buffer[0..$];
					packet.packetSize = ServerManager.m_cipher.finishOutputSize(plaintext.length) + packet.headerData.sizeof;
				}
				else {	// is client
					synchronized (ClientManager.m_cipher) {
						ClientManager.m_cipher.init(ClientManager.m_cipher.ENCRYPT, ClientManager.m_params);
						amount = ClientManager.m_cipher.update(plaintext, buffer);
						ClientManager.m_cipher.finish(buffer[amount..buffer.length]);
					}
					packet.userData[0..$] = buffer[0..$];
					packet.packetSize = ClientManager.m_cipher.finishOutputSize(plaintext.length) + packet.headerData.sizeof;
				}
			}
			
			foreach (conn; connections) {
				conn.lock();
				
				switch (packet.sendType) {
				case SendType.RELIABLE:
					packet.packetID = conn.reliableID;
					++conn.reliableID;
				break;
				case SendType.SEQUENTIAL:
					packet.packetID = conn.sequentialID;
					++conn.sequentialID;
				break;
				}
				efix!(uint)(packet.packetID);
				
				Cache.sent(m_time.time, conn.address, packet);
				void[] outData = packet.packetData[0 .. packet.packetSize];
				NetSocket.write(outData, conn.address);

				conn.unlock();
			}
		}
	}
	
	void sendPacketX(NetConnections connections, inout NetPacketX packet) {
		if (packet.sendType != SendType.RELIABLE) throw new Exception("NetPacketX can only be sent reliably");
		else if ((packet.command & NetCommand.TYPE_MASK) != NetCommand.NORMAL) throw new Exception("NetPacketX cannot be a query");

		NetThread t = cast(NetThread)NetThread.getThis();
		
		if (packet.encrypted) {
			uint count;
			ubyte[] plaintext = packet.userData[0..(packet.packetSize - packet.headerData.sizeof)];
			ubyte[NetPacketX.userData.length] buffer;
			
			static if (IS_SERVER) {
				ClientData client = cast(ClientData)t.conn;
				
				synchronized (ServerManager.m_cipher) {
					ServerManager.m_cipher.init(ServerManager.m_cipher.ENCRYPT, client.params);
					count = ServerManager.m_cipher.update(plaintext, buffer);
					count += ServerManager.m_cipher.finish(buffer[count..buffer.length]);
				}
				packet.userData[0..$] = buffer[0..$];
				packet.packetSize = count + packet.headerData.sizeof;
			}
			else {	// is client
				synchronized (ClientManager.m_cipher) {
					ClientManager.m_cipher.init(ClientManager.m_cipher.ENCRYPT, ClientManager.m_params);
					count = ClientManager.m_cipher.update(plaintext, buffer);
					count += ClientManager.m_cipher.finish(buffer[count..buffer.length]);
				}
				packet.userData[0..$] = buffer[0..$];
				packet.packetSize = count + packet.headerData.sizeof;
			}
		}
		
		uint uDataLength = packet.packetSize - NetPacket.headerData.sizeof;
		uint count = uDataLength / PacketMax.SINGLE;
		if ((uDataLength % PacketMax.SINGLE) != 0) ++count;
		
		if (count == 1) {	// Only one packet. Leave NetPacket.fragmentID as 0
			foreach (conn; connections) {
				conn.lock();
				
				packet.packetID = conn.reliableID;
				++conn.reliableID;
				efix!(uint)(packet.packetID);
				
				Cache.sent(m_time.time, conn.address, cast(NetPacket)packet);
				void[] outData = packet.packetData[0 .. packet.packetSize];
				NetSocket.write(outData, conn.address);
				
				conn.unlock();
			}
		}
		else {	// Fragmented
			uint startPoint = 0;
			NetPacket[] oPack = new NetPacket[ count ];
			for (uint L = 0; L < count; L++) {
				oPack[L].headerData[0 .. $] = packet.headerData[0 .. $];
				oPack[L].fragment = L;
				efix!(ushort)(oPack[L].fragment);
				oPack[L].fragmentCount = count;
				efix!(ushort)(oPack[L].fragmentCount);
				
				uint copyAmount = startPoint + PacketMax.SINGLE;
				if (copyAmount > uDataLength) copyAmount = uDataLength;
				oPack[L].userData[0 .. copyAmount] = packet.userData[startPoint .. (startPoint + copyAmount)];
				oPack[L].packetSize = oPack[L].headerData.sizeof + copyAmount;
				
				startPoint += copyAmount;
				uDataLength -= copyAmount;
			}
			
			foreach (conn; connections) {
				conn.lock();
				
				for (uint L = 0; L < count; L++) {
					oPack[L].packetID = conn.fragmentID;
					++conn.fragmentID;
					efix!(uint)(oPack[L].packetID);
					
					Cache.sent(m_time.time, conn.address, oPack[L]);
					void[] outData = oPack[L].packetData[0 .. oPack[L].packetSize];
					NetSocket.write(outData, conn.address);
				}
				
				conn.unlock();
			}
		}
	}
}
