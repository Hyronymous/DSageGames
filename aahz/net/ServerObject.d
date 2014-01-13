module aahz.net.ServerObject;

import aahz.net.NetObject;

abstract class ServerObject : NetObject {
public:
	this(int uid) {
		super(uid);
	}
}
