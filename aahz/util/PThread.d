module aahz.util.PThread;

import tango.core.Thread;
import aahz.util.TimeUpdate;
import tango.io.Stdout;

enum ThreadPause {
	TIMED_OUT,
	AWOKEN
}

class PThread : Thread {
private:
	bool m_paused = false;
	bool m_unpause = false;
	
public:
	this(void function() fn, size_t sz = 0) {
		super(fn, sz);
	}

	this(void delegate() dg, size_t sz = 0) {
		super(dg, sz);
	}
	
	ThreadPause pause(uint milliseconds = 0) {
		ThreadPause ret;
		
		if (milliseconds == 0) {
			synchronized (this) {
				if (m_unpause) {
					m_unpause = false;
					m_paused = false;
					return ThreadPause.AWOKEN;
				}
				m_paused = true;
			}
			
			while (true) {
				synchronized (this) {
					if (m_unpause) {
						m_unpause = false;
						m_paused = false;
						break;
					}
				}
				Thread.yield();
			}
			ret = ThreadPause.AWOKEN;
		}
		else {
			TimeUpdate tu = new TimeUpdate();
			synchronized (this) {
				if (m_unpause) {
					m_unpause = false;
					m_paused = false;
					return ThreadPause.AWOKEN;
				}
				m_paused = true;
			}
			while (true) {
				synchronized (this) {
					if (m_unpause) {
						m_unpause = false;
						m_paused = false;
						ret = ThreadPause.AWOKEN;
						break;
					}
					
					tu.update();
					if (tu.time >= milliseconds) {
						ret = ThreadPause.TIMED_OUT;
						break;
					}
				}
				Thread.yield();
			}
		}
		
		return ret;
	}
	
	void unpause() {
		synchronized (this) {
			m_unpause = true;
		}
	}
	
	void clear() {
		synchronized (this) {
			m_paused = false;
			m_unpause = false;
		}
	}
}
