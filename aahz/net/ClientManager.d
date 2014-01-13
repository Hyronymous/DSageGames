module aahz.net.ClientManager;

import Crypt = aahz.crypt.Crypt;
import aahz.crypt.RSA;
import aahz.net.Net;
import aahz.net.NetCache;
import aahz.net.NetChannel;
import aahz.net.NetInternal;
import aahz.net.NetLink;
import aahz.net.NetObject;
import aahz.net.NetPacket;
import aahz.net.NetThread;
import aahz.util.Lockable;
import aahz.util.RWLock;

import dcrypt.crypto.ciphers.AES;
import dcrypt.crypto.ManagedBlockCipher;
import dcrypt.crypto.modes.CBC;
import dcrypt.crypto.padding.PKCS7;
import dcrypt.crypto.params.ParametersWithIV;
import dcrypt.crypto.params.SymmetricKey;
import dcrypt.crypto.prngs.PBKDF2;

import tango.core.Thread;
import CPU = tango.core.tools.Cpuid;
import tango.io.FileSystem;
import tango.io.Stdout;
import tango.math.BigInt;
import tango.math.random.Random;
import tango.time.Clock;
import tango.time.StopWatch;
import tango.util.Convert;
import tango.util.container.HashSet;

struct ClientManager {
	mixin NetCache Cache;	// Caching. Is used by NetInternal but must be mixed in here
	mixin NetInternal!(false) Internal;	// Low-level I/O code has been broken out to another file (it still has access to private data since it's mixed in)
	
static private:
	enum ClientSetup {
		DEFAULT		= 0,
		SERVERS		= 0x1,
		SECURITY	= 0x2,
		FOLDER		= 0x4,
		LOGIN		= 0x8,
		COMPLETE = SERVERS | SECURITY | FOLDER
	}
	enum ServerStatus {
		DISCONNECTED,
		CONNECTING,
		LOGGING_IN,
		CONNECTED
	}
	class ServerInfo : RWLock {	// Always lock ServerInfo object before locking m_connections if adjusting both
	public:
		ServerStatus status = ServerStatus.DISCONNECTED;	// Must lock ->
		HashSet!(NetChannelLink) channels;
		
		uint clientCount = uint.max;	// No need to lock ->
		uint uid;
		NetAddress address;
		
		this(uint id, NetAddress add) {
			uid = id;
			address = add;
			channels = new HashSet!(NetChannelLink);
		}
	}
	ServerInfo[uint] m_serverUID;	// Allow us to look it up by either means
	ServerInfo[NetAddress] m_serverAddress;
	
	struct Wakeup {
		NetThread t;
		NetPacketX* packet;
	}
	Lockable!( Wakeup*[uint] ) m_wakeupThreads;
	uint m_queryID = 0;	// Lock m_wakeupThreads
	
	ClientSetup m_setupStatus = ClientSetup.DEFAULT;
	bool m_running = false;
	bool m_keepGoing;
	char[] m_folder;
	
	RSA m_rsa;
	ManagedBlockCipher m_cipher;
	ParametersWithIV m_params;
	char[] m_username;
	char[] m_password;
	
static public:
	enum ConnectionStatus {
		DISCONNECTED,
		FINDING_SERVERS,
		CONNECTING,
		LOGGING_IN,
		CONNECTED
	}
	ConnectionStatus m_connStatus = ConnectionStatus.DISCONNECTED;
	NetChannelLink function()[ char[] ] m_channelCreate;
	
static private:
	void sendQuery(ref bool cancel, inout NetAddress address, inout NetPacket packet, inout NetPacketX res, bool isUnreliable = false) {
		Wakeup w;
		NetThread t = cast(NetThread)Thread.getThis();
		
		synchronized (m_wakeupThreads) {	// push
			packet.queryID = m_queryID;
			++m_queryID;
			
			w.t = t;
			w.packet = &res;
			m_wakeupThreads.x[ packet.queryID ] = &w;
		}
		scope (exit) synchronized (m_wakeupThreads) {	// pop
			m_wakeupThreads.x.remove(packet.queryID);
			t.clear();	// Clear the pause variables
		}
		
		if (!isUnreliable) {
			{
				m_connections.lockRead();
				scope (exit) m_connections.unlockRead();
				ConnectionData conn = m_connections.get(address);
				if (conn is null) throw new ConnectionLost("Connection lost");
				t.push(conn);
			}
			{
				scope (exit) t.pop();
				Internal.sendPacket(address, packet);
			}
		}
		
		bool receivedResponse = false;
		for (uint L = 0; L < 10; L++) {
			if (isUnreliable) {
				Internal.sendPacket(address, packet);
			}
			
			ThreadPause tp = t.pause(1_000);	// One second
			if (tp != ThreadPause.TIMED_OUT) {
				receivedResponse = true;
				break;
			}
			else if (cancel) {
				throw new OperationCancelled("Operation cancelled");
			}
		}
		if (!receivedResponse) throw new TimedOut("Timed out");
		if (packet.command == NetCommand.P2S_R_EXCEPTION) {
			uint exceptionCode;
			packet.read(exceptionCode);
			toException(exceptionCode);	// Will throw the appropriate exception
		}
	}
	
	void connectInternal(ref bool cancel, inout NetAddress address) {	// Assumes that the ServerInfo object is already locked
		if (m_serverAddress[address].status == ServerStatus.CONNECTED) return;	// Already connected
		
		NetPacketX res;
		NetPacket packet;
		NetThread t = cast(NetThread)Thread.getThis();
		
		m_serverAddress[address].status = ServerStatus.CONNECTING;

		BigInt keyInt = Crypt.fromBytes((cast(SymmetricKey)m_params.parameters).key);	// Encrypt our key with RSA
		keyInt = m_rsa.encrypt(keyInt);
		ubyte[] encKey = Crypt.toBytes(keyInt);
		
		Internal.initPacket(packet, NetCommand.P2S_Q_CONNECT);	// Send the key
		packet.write(encKey);
		sendQuery(cancel, address, packet, res, true);	// Sends query and pauses thread while waiting for response
		if (res.command != NetCommand.P2S_R_CONNECT) throw new BadPacket("Bad packet");
		
		scope (failure) {
			Internal.initPacket(packet, NetCommand.P2S_CLIENT_DISCONNECT);
			Internal.sendPacket(address, packet);
		}

		m_serverAddress[address].status = ServerStatus.LOGGING_IN;

		{
			m_connections.lockWrite();
			scope (exit) m_connections.unlockWrite();
			ConnectionData conn = new ConnectionData(address);
			m_connections.insert(conn);
		}
		scope (failure) {
			m_connections.lockWrite();
			m_connections.remove(address);
			m_connections.unlockWrite();
		}
		
		Internal.initPacket(packet, NetCommand.P2S_Q_LOGIN);
		packet.encrypted = true;
		packet.write(m_username);
		packet.write(m_password);
		sendQuery(cancel, address, packet, res);
		if (res.command != NetCommand.P2S_R_LOGIN)  throw new BadPacket("Bad packet");						

		m_serverAddress[address].status = ServerStatus.CONNECTED;
	}
	
	void connectionLost(inout NetAddress address) {	// Also called by Internal
		ServerInfo server = m_serverAddress[address];
		server.lockWrite();
		scope (exit) server.unlockWrite();
		
		m_connections.lockWrite();
		scope (exit) m_connections.unlockWrite();
		
		server.channels.clear();
		server.status = ServerStatus.DISCONNECTED;
		
		m_connections.remove(address);	// Delete from the tracked connections so that they can try to reconnect
		Cache.removeConnection(address);
	}
	
static public:
	void registerServer(uint uid, char[] ip, ushort port) {
		if (m_running) throw new Exception("Cannot be modified while running");
		
		NetAddress address;
		address.set(ip, port);
		ServerInfo sI = new ServerInfo(uid, address);
		m_serverUID[uid] = sI;
		m_serverAddress[address] = sI;
		
		m_setupStatus |= ClientSetup.SERVERS;
	}
	
	void setRSA(RSAPublicKey pub) {
		if (m_running) throw new Exception("Cannot be modified while running");
		
		m_rsa = new RSA(pub);
		m_cipher = new ManagedBlockCipher(new CBC(new AES), new PKCS7);
		
		char[] currTime = to!(char[])( Clock.now().ticks() );
		char[] salt =
			to!(char[])( FileSystem.freeSpace("/") )
			~ to!(char[])( FileSystem.totalSpace("/") )
			~ CPU.vendor()
			~ CPU.processor
		;
		PBKDF2 prng = new PBKDF2(currTime, salt);
		
		ubyte[] key = new ubyte[16];
		BigInt keyInt;
		do {
			prng.read(key);
			keyInt = Crypt.fromBytes(key);
		}
		while (!m_rsa.encryptable(keyInt))
		
		ubyte[] iv = new ubyte[ m_cipher.blockSize ];
		prng = new PBKDF2(cast(char[])key, "fnord", 3);
		prng.read(iv);
		
		m_params = new ParametersWithIV(new SymmetricKey(key), iv);
		
		m_setupStatus |= ClientSetup.SECURITY;
	}
	
	void setCacheFolder(char[] folder) {
		if (m_running) throw new Exception("Cannot be modified while running");
		m_folder = folder.dup;
		m_setupStatus |= ClientSetup.FOLDER;
	}
	
	void setLoginInfo(char[] username, char[] password) {
		m_username = username.dup;
		m_password = password.dup;
		m_setupStatus |= ClientSetup.LOGIN;
	}
	
	void run(char[] ip, ushort port) {
		if (m_running) throw new Exception("Already running");
		else if ((m_setupStatus & ClientSetup.COMPLETE) != ClientSetup.COMPLETE) throw new Exception("Minimum settings not yet specified");
		
		NetThread t = cast(NetThread)NetThread.getThis();
		m_keepGoing = true;
		m_wakeupThreads = new Lockable!( Wakeup*[uint] );
		
		Internal.init(ip, port);
		Internal.start();
		scope (failure) {
			Internal.stop();
			Internal.cleanup();
		}
		m_running = true;
		scope (exit) m_running = false;
		
		foreach (server; m_serverAddress) {	// Immediately send off a request to find how busy the servers are
			NetPacket packet;
			Internal.initPacket(packet, NetCommand.P2S_SERVER_STATUS);
			Internal.sendPacket(server.address, packet);
		}
		
		NetPacketX packet;
		NetAddress address;
		while (m_keepGoing) {
			try {
				packet.sendType = SendType.UNRELIABLE;	// We're essentially zeroing the struct (without actually going through the effort of doing that) so that the "finally" statement at the bottom of the function doesn't keep re-finalizing a sequential packet
				if (!Internal.receivePacket(packet, address)) {	// Try to get a packet
					Thread.yield();
					continue;
				}
				if ((address in m_serverAddress) == null) goto SKIP_PACKET;	// Ignore data from non-registered locations

				bool isConnected = t.conn !is null;
				
				// -------------------------
				if (t.conn !is null) t.pop();	// We don't use this (yet)
				// -------------------------
				
				if (isConnected) {
					if ((packet.command & NetCommand.TYPE_MASK) != NetCommand.REPLY) {
						switch (packet.command) {	// CONNECTED
						case NetCommand.P2S_SERVER_STATUS:
							int clientCount;
							packet.read(clientCount);
							m_serverAddress[address].clientCount = clientCount;
						break;
						default:	// ignore it
						break;
						}
					}
					else {	// NetCommand.REPLY
						synchronized (m_wakeupThreads) {
							Wakeup** wp;
							if ((wp = (packet.queryID in m_wakeupThreads.x)) != null) {	// If there's a thread waiting for the data, copy the data over and wake it up
								Wakeup* w = *wp;
								w.packet.packetData[0 .. packet.packetSize] = packet.packetData[0 .. packet.packetSize];
								w.packet.packetSize = packet.packetSize;
								w.packet.unwind();
								
								w.t.unpause();
							}
						}
					}
				}
				else {	// NOT CONNECTED
					if ((packet.command & NetCommand.TYPE_MASK) != NetCommand.REPLY) {
						switch (packet.command) {
						case NetCommand.P2S_SERVER_STATUS:
							int clientCount;
							packet.read(clientCount);
							m_serverAddress[address].clientCount = clientCount;
						break;
						default:	// ignore it
						break;
						}
					}
					else if (packet.command == NetCommand.P2S_R_CONNECT) {	// NetCommand.REPLY	// The only acceptable REPLY command that comes from an unconnected source
						synchronized (m_wakeupThreads) {
							Wakeup** wp;
							if ((wp = (packet.queryID in m_wakeupThreads.x)) != null) {	// If there's a thread waiting for the data, copy the data over and wake it up
								Wakeup* w = *wp;
								w.packet.packetData[0 .. packet.packetSize] = packet.packetData[0 .. packet.packetSize];
								w.packet.packetSize = packet.packetSize;
								w.packet.unwind();
								
								w.t.unpause();
							}
						}
					}
				}
				
SKIP_PACKET:	;
			}
			catch (Exception e) {
			}
			finally {
				if (t.conn !is null) t.pop();
				if (packet.sendType == SendType.SEQUENTIAL) Cache.finalizeSequential(address);
			}
		}
	}
	
	void stop() {
		m_keepGoing = false;
		if (m_running) NetThread.yield();	// Give the main network loop a chance to end
		
		Internal.stop();
		
		m_connections.lockWrite();
		m_connections.clear();
		m_connections.unlockWrite();
		
		foreach (server; m_serverAddress) {
			server.lockWrite();
			scope (exit) server.unlockWrite();
			if (server.status != ServerStatus.DISCONNECTED) {
				NetPacket packet;
				Internal.initPacket(packet, NetCommand.P2S_CLIENT_DISCONNECT);
				Internal.sendPacket(server.address, packet);
				server.status = ServerStatus.DISCONNECTED;
			}
		}
		
		Internal.cleanup();
	}
	
	void connect(ref bool cancel, int uid = -1) {	// -1 indicates that we don't care which server we connect to
		if ((m_setupStatus & ClientSetup.LOGIN) != ClientSetup.LOGIN) throw new Exception("Username and password not set");
		
		NetAddress address;
		if (uid == -1) {
			uint lowest = uint.max;			
			foreach (server; m_serverAddress) {	// Choose the least populated server
				if (server.clientCount < lowest) {
					lowest = server.clientCount;
					address = server.address;
				}
			}
			
			if (lowest == uint.max) {	// Haven't yet received server info? Pick a random server to connect to
				Random rand = new Random();
				uint i = 0;
				uint take = rand.uniformR(m_serverAddress.length);
				
				foreach (server; m_serverAddress) {
					if (i == take) {
						address = server.address;
					}
					++i;
				}
			}
		}
		else {
			uint serverID = cast(uint)uid;
			if ((serverID in m_serverUID) == null) throw new Exception("Invalid server ID");
			address = m_serverUID[serverID].address;
		}
		
		{
			m_serverAddress[address].lockWrite();	// Don't let anyone else try to connect/disconnect while we're connecting to this address
			scope (exit) m_serverAddress[address].unlockWrite();
			connectInternal(cancel, address);
		}
	}
	
	NetChannelLink joinChannel(ref bool cancel, char[] channelType, char[] channelName, char[] password) {
		if (!m_running) throw new Exception("Not connected");
		
		NetChannelLink ret;
		NetAddress address;
		
		{
			bool decidedServer = false;
			uint lowest = uint.max;

			while (!cancel) {
				foreach (server; m_serverAddress) {
					server.lockRead();
					scope (exit) server.unlockRead();
					
					if (server.status == ServerStatus.CONNECTED && server.clientCount <= lowest) {
						decidedServer = true;
						address = server.address;
						lowest = server.clientCount;
					}
				}
				if (!decidedServer) {	// We don't appear to be connected to any servers, so connect to one
					connect(cancel);
				}
				else {
					break;
				}
			}
			if (!decidedServer) throw new OperationCancelled("Cancelled join channels");
		}
		
		NetThread t = cast(NetThread)NetThread.getThis();
		NetPacket packet;
		NetPacketX res;
		
		Internal.initPacket(packet, NetCommand.P2S_Q_CHANNEL_LOCATION);
		packet.write(channelName);
		sendQuery(cancel, address, packet, res);
		if (res.command != NetCommand.P2S_R_CHANNEL_LOCATION) throw new BadPacket("Bad packet");
		
		bool channelExists;
		res.read(channelExists);
		if (channelExists) {
			uint serverID;
			res.read(serverID);
			if ((serverID in m_serverUID) == null) throw new NoSuchServer("No such server registered");
			
			bool serverConnected = false;
			ServerInfo server = m_serverUID[serverID];
			{
				server.lockWrite();
				scope (exit) server.unlockWrite();
				if (server.status == ServerStatus.CONNECTED) serverConnected = true;

				if (!serverConnected) connectInternal(cancel, server.address);	// Will throw exception on failure
				
				Internal.initPacket(packet, NetCommand.P2S_Q_JOIN_CHANNEL);
				packet.encrypted = true;
				packet.write(channelType);
				packet.write(channelName);
				packet.write(password);
				sendQuery(cancel, address, packet, res);
				if (res.command != NetCommand.P2S_R_JOIN_CHANNEL) throw new BadPacket("Bad packet");
				
				ret = m_channelCreate[ channelType ]();
				ret.m_conn = t.conn;
				server.channels.add(ret);
			}
		}
		else {	// !channelExists
			ServerInfo server = m_serverAddress[address];
			
			{
				server.lockWrite();
				scope (exit) server.unlockWrite();
				if (server.status != ServerStatus.CONNECTED) throw new ConnectionLost("Connection lost");
				
				Internal.initPacket(packet, NetCommand.P2S_Q_JOIN_CHANNEL);
				packet.encrypted = true;
				packet.write(channelType);
				packet.write(channelName);
				packet.write(password);
				sendQuery(cancel, address, packet, res);
				if (res.command != NetCommand.P2S_R_JOIN_CHANNEL) throw new BadPacket("Bad packet");
				
				ret = m_channelCreate[ channelType ]();
				ret.m_conn = t.conn;
				server.channels.add(ret);
			}
		}
		
		return ret;
	}
	
	bool isRunning() {
		return m_running;
	}
}
