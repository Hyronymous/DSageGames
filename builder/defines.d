module defines;

import tango.io.stream.TextFileStream;
import tango.text.Regex;
import tango.text.convert.Integer;
import aahz.net.NetDefines;	// NetLocation and NetTypes

enum NetPersistence {
	PERSIST,
	TRANSITORY
}

enum NetAccess {
	SHARED,
	LOCAL
}

enum NetAttribute {
	DEFAULT,
	STATIC,
	CONST
}

enum NetReliability {
	RELIABLE,
	UNRELIABLE
}

struct NetMember {
	NetPersistence persist;
	NetAccess access;
	NetAttribute attribute;
	NetType type;
	char[] name;
	char[] init;
}

struct NetMethod {
	NetAccess access;
	NetReliability reliability;
	char[] name;
	NetType[] params;
	char[] code;
}

struct NetObjectDef {
	NetLocation classLoc;
	char[] className;
	NetMethod constructor;
	NetMethod destructor;
	NetMember[] members;
	NetMethod[] methods;
}

char[] objectBoilerplate = `
class {} : NetObject {
{}

	this(char[] name{}) {
		/* Ignore -- Boilerplate */
		m_owner = -1;
		m_location = {};
{}
{}
		/* Ignore -- Boilerplate */
{}
		/* Ignore -- Boilerplate */
		NetManager.addObject(name, this);
		/* Ignore -- Boilerplate */
	}
	
	~this() {
		/* Ignore -- Boilerplate */
		
		/* Ignore -- Boilerplate */
{}
		/* Ignore -- Boilerplate */
		
		/* Ignore -- Boilerplate */
	}

{}
}
`;
char[] linkBoilerplate = `
class L_{} : NetObjectLink {
{}
	
	this(char[] name, uint clientID) {
		NetManager.addLink(name, this, clientID);
	}
	
	~this() {
		
	}

{}
}
`;
char[] serverObjectMethodStart = `
	{0} {1}(...) {
		/* Ignore -- Boilerplate */
		bool aahz_isTop = false;
		
		synchronized (this) {	// If we're on the server and calling a server object, lock it -- but only if we haven't already locked it (e.g. Foo calls another function in itself)
			if (m_owner != thread) {
				m_owner = thread;
				aahz_isTop = true;
				m_mutex.lock();
			}
		}
{2}
		/* Ignore -- Boilerplate */
	}
`;
char[] serverObjectMethodEnd = `
		/* Ignore -- Boilerplate */
		if (aahz_isTop) {	// If I'm at the top of the calling tree to this object, send out all the changes made before exiting
			sendMyself();
			m_owner = -1;
			m_mutex.unlock();
		}
		/* Ignore -- Boilerplate */
`;
char[] clientObjectMethodStart = `
		/* Ignore -- Boilerplate */
		bool aahz_isTop = false;
		
		if (m_owner == -1) {
			m_owner = 0;
			aahz_isTop = true;
		}		
{0}
		/* Ignore -- Boilerplate */
`;
char[] clientObjectMethodEnd = `
		/* Ignore -- Boilerplate */
		if (aahz_isTop) {	// If I'm at the top of the calling tree to this object, send out all the changes made before exiting
			sendMyself();
			m_owner = -1;
		}
		/* Ignore -- Boilerplate */
`;
char[] methodParam = `
		if (_arguments[{0}] == typeid({1})) {
			{2} = *cast({1} *)_argptr;
			_argptr += {1}.sizeof;
		}
		else {
			throw new Exception("Invalid type passed to method");
		}
`;
