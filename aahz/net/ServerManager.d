module aahz.net.ServerManager;

import tango.core.Exception;
import tango.io.Stdout;
import tango.math.BigInt;

import dcrypt.crypto.ciphers.AES;
import dcrypt.crypto.ManagedBlockCipher;
import dcrypt.crypto.modes.CBC;
import dcrypt.crypto.padding.PKCS7;
import dcrypt.crypto.params.SymmetricKey;
import dcrypt.crypto.prngs.PBKDF2;

import derelict.sdl.sdl;

import tango.core.Thread;
import Crypt = aahz.crypt.Crypt;
import aahz.crypt.RSA;
import aahz.net.Net;
import aahz.net.NetCache;
import aahz.net.NetChannel;
import aahz.net.NetInternal;
import aahz.net.NetObject;
import aahz.net.NetPacket;
import aahz.net.NetThread;
import aahz.util.LinkedList;
import aahz.util.Lockable;
import aahz.util.Persistent;

struct ServerManager {
	mixin NetCache Cache;	// Caching. Is used by NetInternal but must be mixed in here
	mixin NetInternal!(true) Internal;	// Low-level I/O code has been broken out to another file (it still has access to private data since it's mixed in)

static private:
	synchronized NetObject[ ulong ] m_objects;
	Lockable!( NetChannel[ char[] ] ) m_localChannels;
	
	alias void function() StartupFunc;
	alias void function() ShutdownFunc;
	alias bool function(char[] username, char[] password) ConnectFunc;
	alias void function() DisconnectFunc;
	
	StartupFunc m_onStartup;
	ShutdownFunc m_onShutdown;
	ConnectFunc m_onConnect;
	DisconnectFunc m_onDisconnect;
	
	PHolder!(char[], uint) m_foreignChannels;
	
	bool m_keepGoing = false;
	uint m_uid;	// server id
	RSA m_rsa;
	
	enum ServerSetup {
		DEFAULT		= 0,
		CALLBACKS	= 0x1,
		SECURITY	= 0x2,
		FOLDER		= 0x4,
		COMPLETE = CALLBACKS | SECURITY | FOLDER
	}
	ServerSetup m_setupStatus = ServerSetup.DEFAULT;
	
	char[] m_folder;
	bool m_running = false;
	NetAddress[ uint ] m_serverAddress;
	uint[ NetAddress ] m_serverUID;
	
static package:
	ManagedBlockCipher m_cipher;
	
static public:
	NetChannel function(char[])[ char[] ] m_channelCreate;
	
static private:
	void connectionLost(inout NetAddress address) {	// Also called by Internal
		m_connections.lockWrite();
		scope (exit) m_connections.unlockWrite();
		
		m_connections.remove(address);	// Delete from the tracked connections so that they can try to reconnect
		Cache.removeConnection(address);
	}

	void threadFunc() {
		NetPacketX packet;	// Input
		NetAddress address;	// Input
		NetPacket response;	// Output
		NetThread t = cast(NetThread)NetThread.getThis();
		
		while (m_keepGoing) {
			try {
				packet.sendType = SendType.UNRELIABLE;	// We're essentially zeroing the struct (without actually going through the effort of doing that) so that the "finally" statement at the bottom of the function doesn't keep re-finalizing a sequential packet
				if (!Internal.receivePacket(packet, address)) {	// Try to get a packet. Will lock incoming ConnectionData to t.conn if there was one
					Thread.yield();	// No packets. Let another thread have a go
					continue;
				}
				
				if ((packet.command & NetCommand.DESTINATION_MASK) == NetCommand.S2S) {	// Make sure that S2S commands are coming from a registered server
					uint* ptr = (address in m_serverUID);
					if (ptr == null) goto SKIP_PACKET;	// Drop the packet
				}
				bool isConnected = t.conn !is null;
				
				switch (packet.command) {
				case NetCommand.S2S_SERVER_CONNECT:
					if (!isConnected) {
						m_connections.lockWrite();
						ConnectionData server = new ConnectionData(address);
						server.isServer = true;
						t.push(server);
						m_connections.insert(server);
						m_connections.unlockWrite();
					}

					Internal.initPacket(response, NetCommand.S2S_SERVER_CREATED);
					Internal.sendPacket(address, response);
				break;
				case NetCommand.P2S_Q_CONNECT:
synchronized (Stdout) Stdout("Client connect\n").flush;
					if (!isConnected) {	// New client
						BigInt rsaBig;
						ubyte[] clientKey;
						
						packet.read(clientKey);
						rsaBig = Crypt.fromBytes(clientKey);
						rsaBig = m_rsa.decrypt(rsaBig);
						clientKey = Crypt.toBytes(rsaBig);
						
						if (clientKey.length == 16) {
							m_connections.lockWrite();
							ClientData client = new ClientData(address, clientKey);
							t.push(client);
							m_connections.insert(client);
							m_connections.unlockWrite();
							
							Internal.initPacket(response, NetCommand.P2S_R_CONNECT, packet.queryID);
							Internal.sendPacket(address, response);
						}
						// There never should be a bad key so it's not worth bothering to tell someone they failed to connect
					}
					else {	// Client didn't receive response
						if (!t.conn.loggedIn) {	// If they've resent the command instead of going on to logging in, probably the ack response was missed. Verify that the encryption code is the same and return success
							BigInt rsaBig;
							ubyte[] clientKey;
							ClientData client = cast(ClientData)t.conn;
							
							packet.read(clientKey);
							rsaBig = Crypt.fromBytes(clientKey);
							synchronized (m_rsa) rsaBig = m_rsa.decrypt(rsaBig);
							clientKey = Crypt.toBytes(rsaBig);
							
							if (
								clientKey.length == 16
								&& clientKey == (cast(SymmetricKey)client.params.parameters).key
							) {
								Internal.initPacket(response, NetCommand.P2S_R_CONNECT, packet.queryID);
								Internal.sendPacket(address, response);
							}
						}
					}
				break;
				case NetCommand.P2S_SERVER_STATUS:
synchronized (Stdout) Stdout("Server status\n").flush;
					Internal.initPacket(response, NetCommand.P2S_SERVER_STATUS);
					{
						m_connections.lockRead();
						scope (exit) m_connections.unlockRead();
						response.write(cast(int)m_connections.length);
					}
					Internal.sendPacket(address, response);	// P2S_SERVER_STATUS is sent unreliably/unencrypted so t.conn doesn't need to be set
				break;
				case NetCommand.P2S_CLIENT_DISCONNECT:
synchronized (Stdout) Stdout("Client disconnect\n").flush;
					m_connections.lockWrite();
					m_connections.remove(address);
					Cache.removeConnection(address);
					m_connections.unlockWrite();
				break;
				default:
					if (isConnected) switch (packet.command) {	// CONNECTED -- t.conn is set to the incoming connection
					case NetCommand.P2S_Q_LOGIN:
synchronized (Stdout) Stdout("Client login\n").flush;
						char[] username, password;
						packet.read(username);
						packet.read(password);
						
						if (m_onConnect(username, password)) {	// Successful login
							(cast(ClientData)t.conn).loggedIn = true;
							Internal.initPacket(response, NetCommand.P2S_R_LOGIN, packet.queryID);
							Internal.sendPacket(address, response);
						}
						else {	// Bad username/password
							m_connections.lockWrite();
							m_connections.remove(address);	// Delete it. They have to try all over again
							Cache.removeConnection(address);
							m_connections.unlockWrite();

							Internal.initPacket(response, NetCommand.P2S_R_EXCEPTION, packet.queryID);
							response.write(cast(uint)NetException.AUTHORIZATION_FAIL);
							Internal.sendPacket(address, response);
						}
					break;
					default:
						if (t.conn.loggedIn) switch (packet.command) {	// CONNECTED && LOGGED -- t.conn is set to the incoming connection
						case NetCommand.P2S_Q_JOIN_CHANNEL:
synchronized (Stdout) Stdout("Join Channel\n").flush;
							char[] channelType, channelName, password;
							
							packet.read(channelType);
							packet.read(channelName);
							packet.read(password);
							
							bool found = false;
							synchronized (m_foreignChannels) {	// Keep this locked while we adjust channel lists
								uint[] location = m_foreignChannels.getValue(channelName);
								if (location.length != 0) {	// Channel is on another server
									Internal.initPacket(response, NetCommand.P2S_R_EXCEPTION, packet.queryID);
									response.write(cast(uint)NetException.WRONG_SERVER);
									Internal.sendPacket(address, response);
								}
								else synchronized (m_localChannels) {	// Local or non-existant channel
									NetChannel* ptr = (channelName in m_localChannels.x);
									
									if (ptr != null) {	// Channel exists locally
										NetChannel channel = *ptr;
										if (channel.addClient(t.conn, password)) {
											Internal.initPacket(response, NetCommand.P2S_R_JOIN_CHANNEL, packet.queryID);
											Internal.sendPacket(address, response);
										}
										else {
											Internal.initPacket(response, NetCommand.P2S_R_EXCEPTION, packet.queryID);
											response.write(cast(uint)NetException.AUTHORIZATION_FAIL);
											Internal.sendPacket(address, response);
										}
									}
									else {	// Doesn't exist. Create it
										NetChannel channel = m_channelCreate[ channelType ]( password );
										m_localChannels.x[ channelName ] = channel;
										channel.addClient(t.conn, password);
										
										Internal.initPacket(response, NetCommand.P2S_R_JOIN_CHANNEL, packet.queryID);
										Internal.sendPacket(address, response);
										
										t.pop();	// Done with client. Now, busy ourselves with servers

										m_connections.lockRead();
										foreach (serverAddress; m_serverAddress) {	// Let other servers know
											ConnectionData conn = m_connections.get(serverAddress);
											if (conn !is null && conn.connected) {
												Internal.initPacket(response, NetCommand.S2S_CHANNEL_CREATED);
												response.write(channelName);
												t.push(conn);
												Internal.sendPacket(serverAddress, response);
												t.pop();
											}
										}
										m_connections.unlockRead();
									}
								}
							}
						break;
						case NetCommand.S2S_CHANNEL_CREATED:
							t.pop();	// Nothing to write to the incoming connection
						
							char[] channelName;
							packet.read(channelName);
							
							synchronized (m_foreignChannels) {
								m_foreignChannels.add(channelName, m_serverUID[address]);	// Register the server as having the channel
								
								synchronized (m_localChannels) {	// If we already have a channel of the same name, kill it. It's very unlikely for this to happen (two channels with the same name being registered in a short enough time frame for the servers to have not informed one another) so it's easiest to just kill it
									NetChannel* ptr = (channelName in m_localChannels.x);
									
									if (ptr != null) {	// Channel exists locally
										NetChannel channel = *ptr;
										
										Internal.initPacket(response, NetCommand.P2S_CHANNEL_DROPPED);
										response.write(channelName);
										Internal.sendPacket(channel.m_clients, response);
										
										m_localChannels.x.remove(channelName);
									}
								}
							}
						break;
						case NetCommand.P2S_Q_CHANNEL_LOCATION:
synchronized (Stdout) Stdout("Channel locate\n").flush;
							char[] channelName;
							packet.read(channelName);
							
							synchronized (m_foreignChannels) {	// Check if it's on a foreign server (most likely)
								uint[] serverUID = m_foreignChannels.getValue(channelName);
								if (serverUID.length != 0) {
									bool exists = true;
									Internal.initPacket(response, NetCommand.P2S_R_CHANNEL_LOCATION, packet.queryID);
									response.write(exists);
									response.write(serverUID[0]);
									Internal.sendPacket(address, response);
								}
								else synchronized (m_localChannels) {	// Check if it's local
									NetChannel* ptr = (channelName in m_localChannels.x);
									
									if (ptr != null) {	// Channel exists
										bool exists = true;
										Internal.initPacket(response, NetCommand.P2S_R_CHANNEL_LOCATION, packet.queryID);
										response.write(exists);
										response.write(m_uid);
										Internal.sendPacket(address, response);
									}
									else {	// Doesn't appear to exist
										bool exists = false;
										Internal.initPacket(response, NetCommand.P2S_R_CHANNEL_LOCATION, packet.queryID);
										response.write(exists);
										Internal.sendPacket(address, response);
									}
								}
							}
						break;
						}
					break;
					}
				break;
				}
				
SKIP_PACKET:	;	// We want the "finally" to run
			}
			catch (ClientDisconnect e) {	// User needs to be disconnected for some reason (sequential data lost, etc.)
				if (t.conn !is null) {
					m_connections.lockWrite();
					m_connections.remove(address);
					Cache.removeConnection(address);
					m_connections.unlockWrite();
					
					Internal.initPacket(response, NetCommand.P2S_CLIENT_DISCONNECT);
					Internal.sendPacket(address, response);
				}
			}
			catch (SocketException e) {	// We've lost network. Shut down.
				m_keepGoing = false;
			}
			catch (Exception e) {	// Probably we got bad data that couldn't be properly parsed. Keep going
synchronized (Stdout) Stdout.format("ERROR! {}\n", e.toString()).flush;
			}
			finally {
				if (t.conn !is null) t.pop();	// Make sure the thread has freed
				if (packet.sendType == SendType.SEQUENTIAL) Cache.finalizeSequential(address);
			}
		}
	}
	
static public:
	void init() {
		m_localChannels = new Lockable!( NetChannel[ char[] ] );
	}

	NetObject createObject(T : NetObject, A...)(A a) {
		static ulong objectID = 0;
		ulong uid;
		T ret;
		
		synchronized {
			uid = objectID;
			++objectID;
		}
		
		m_objects[ uid ] = new T(a);
		ret = m_objects[ uid ];
		return ret;
	}
	
	void deleteObject(ulong uid) {
		m_objects.remove( uid );
	}
	
	void setCallbacks(
		StartupFunc onStartup,
		ShutdownFunc onShutdown,
		ConnectFunc onConnect,
		DisconnectFunc onDisconnect
	) {
		if (m_running) throw new Exception("Cannot be modified while running");
		
		m_onStartup = onStartup;
		m_onShutdown = onShutdown;
		m_onConnect = onConnect;
		m_onDisconnect = onDisconnect;
		
		m_setupStatus |= ServerSetup.CALLBACKS;
	}
	
	void registerServer(uint uid, char[] ip, ushort port) {	// Only to be called before calling run()
		if (m_running) throw new Exception("Cannot be modified while running");
		
		NetAddress address;
		address.set(ip, port);
		m_serverAddress[uid] = address;
		m_serverUID[address] = uid;
	}
	
	void setRSA(RSAPublicKey pub, RSAPrivateKey prv) {
		if (m_running) throw new Exception("Cannot be modified while running");
		m_rsa = new RSA(pub, prv);
		m_cipher = new ManagedBlockCipher(new CBC(new AES), new PKCS7);
		m_setupStatus |= ServerSetup.SECURITY;
	}
	
	void setCacheFolder(char[] folder) {
		if (m_running) throw new Exception("Cannot be modified while running");
		m_folder = folder.dup;
		m_setupStatus |= ServerSetup.FOLDER;
	}
	
	void run(uint uid, char[] ip, ushort port, uint threadCount) {
		scope (exit) m_running = false;
		if (m_setupStatus != ServerSetup.COMPLETE) throw new Exception("Setup incomplete. Make sure all settings have been called.");
		if (m_running) throw new Exception("Already running");
		
		int res;
		m_running = true;
		m_keepGoing = true;
		
		m_foreignChannels = new PHolder!(char[], uint);	// Store list of all channels (on foreign servers) on the hard drive to save memory space
		m_foreignChannels.open(m_folder, "foreignchannels", PHolderEnum.UNIQUE | PHolderEnum.INDEXED, PHolderEnum.INDEXED);
		
		m_uid = uid;
		Internal.init(ip, port);
		
		// Start up main loop
		
		m_onStartup();	// Init channels or whatever
		
		NetThread[] threads;	// Create and start threads
		threads.length = threadCount;
		for (uint L = 0; L < threadCount; L++) {
			threads[L] = new NetThread(&threadFunc);
			threads[L].start();
		}
		Internal.start();
		
		foreach (thread; threads) thread.join();	// Wait for threads to end
		Internal.stop();
		m_onShutdown();	// And do any user finalization
		
		m_foreignChannels.clear();	// Delete everything from the database
		m_foreignChannels.close();
		
		Internal.cleanup();
	}
}
