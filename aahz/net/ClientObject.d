module aahz.net.ClientObject;

import aahz.net.NetObject;

abstract class ClientObject : NetObject {
public:
	this(int uid) {
		super(uid);
	}
}
