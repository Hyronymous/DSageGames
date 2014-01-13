module aahz.net.NetChannel;

import aahz.net.Net;
import aahz.net.ClientManager;
import aahz.net.NetConnections;
import aahz.net.NetSocket;
import aahz.net.ServerManager;

class NetChannel {
package:
	NetConnections m_clients;

public:
	char[] password;
	
	static this() {
		ServerManager.m_channelCreate[ "NetChannel" ] = &createChannel;
	}
	
	static NetChannel createChannel(char[] password) {
		return (new NetChannel(password));
	}
	
	this(char[] password) {
		this.password = password.dup;
		m_clients = new NetConnections();
	}
	
	bool addClient(ConnectionData conn, char[] pass) {
		bool passOkay = false;
		synchronized (this) {	// So that password isn't changed while testing
			passOkay = (pass == password);
		}
		if (passOkay) {
			m_clients.lockWrite();
			m_clients.insert(conn);
			m_clients.unlockWrite();
			return true;
		}
		return false;
	}
}

class NetChannelLink {
package:
	ConnectionData m_conn;
	
public:
	static this() {
		ClientManager.m_channelCreate[ "NetChannel" ] = &createChannel;
	}
	
	static NetChannelLink createChannel() {
		return (new NetChannelLink());
	}
	
	
}
