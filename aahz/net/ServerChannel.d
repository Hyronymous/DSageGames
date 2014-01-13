module aahz.net.ServerChannel;

import tango.core.sync.Mutex;
import tango.util.container.HashSet;

import aahz.net.ServerManager;
//import aahz.net.NetAddress;
import aahz.net.NetSocket;
/*
class ServerChannel : Mutex {
package:
	HashSet!(NetAddress) m_clients;

public:
	char[] password;
	
	static this() {
		ServerManager.m_channelCreate[ "ServerChannel" ] = &createServerChannel;
	}
	
	static ServerChannel createServerChannel(char[] password) {
		return (new ServerChannel(password));
	}
	
	this(char[] password) {
		this.password = password.dup;
	}
	
	bool addClient(NetAddress address, char[] pass) {
		if (pass == password) {
			synchronized (m_clients) {
				if ( !m_clients.contains(address) ) m_clients.add(address);
			}
			return true;
		}
		return false;
	}
}
*/
