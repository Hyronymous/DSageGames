module aahz.util.Timer;

import tango.core.Thread;

class Timer {
private:
	Thread m_thread;
	double m_delay;
	double m_interval;
	bool m_keepGoing = true;
	
	void function() m_fn;
	void delegate() m_dg;

	void fnTimer() {
		Thread.sleep(m_delay);
		if (m_interval == 0 && m_keepGoing) {
			m_fn();
		}
		else {
			while (m_keepGoing) {
				m_fn();
				Thread.sleep(m_interval);
			}
		}
	}
	
	void dgTimer() {
		Thread.sleep(m_delay);
		if (m_interval == 0 && m_keepGoing) {
			m_dg();
		}
		else {
			while (m_keepGoing) {
				m_dg();
				Thread.sleep(m_interval);
			}
		}
	}

public:
	this(void function() fn, double delay, double interval = 0) {
		m_fn = fn;
		m_delay = delay;
		m_interval = interval;
		m_thread = new Thread(&fnTimer);
		m_thread.start();
	}
	
	this(void delegate() dg, double delay, double interval = 0) {
		m_dg = dg;
		m_delay = delay;
		m_interval = interval;
		m_thread = new Thread(&dgTimer);
		m_thread.start();
	}
	
	~this() {
		m_keepGoing = false;
		m_thread.join();
	}
	
	void kill() {
		m_keepGoing = false;
	}
}
