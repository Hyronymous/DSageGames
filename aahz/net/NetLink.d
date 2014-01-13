module aahz.net.NetLink;

abstract class NetLink {
package:
	ulong m_id;
	
public:
	this(ulong uid) {
		m_id = uid;
	}

	ulong id() {
		return m_id;
	}
}
