module aahz.net.NetThread;

public import aahz.util.PThread;
import aahz.net.Net;

class NetThread : PThread {
package:
	ConnectionData conn = null;

public:
	this(void function() fn, size_t sz = 0) {
		super(fn, sz);
	}

	this(void delegate() dg, size_t sz = 0) {
		super(dg, sz);
	}
	
	void push(ConnectionData cd) {
		if (conn !is null) throw new Exception("Attempted to push second connection to thread");
		conn = cd;
		conn.lock();
	}
	
	void pop() {
		if (conn !is null) conn.unlock();
		conn = null;
	}
}
