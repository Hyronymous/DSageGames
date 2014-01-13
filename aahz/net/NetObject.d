module aahz.net.NetObject;

abstract class NetObject {
package:
	int m_id;
	
public:
	this(int uid) {
		m_id = uid;
	}

	uint id() {
		return m_id;
	}
}
