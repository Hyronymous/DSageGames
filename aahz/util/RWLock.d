module aahz.util.RWLock;

import tango.core.Thread;
import aahz.util.Lockable;

class RWLock {
private:
	Lockable!(uint) m_reading;
	bool m_writing = false;

public:
	this() {
		m_reading = new Lockable!(uint);
		m_reading.x = 0;
		m_writing = false;
	}
	
	void lockRead() {
		while (true) {
			synchronized (this) {
				if (!m_writing) synchronized (m_reading) {
					++m_reading.x;
					return;
				}
			}
			Thread.yield;
		}
	}
	
	bool tryLockRead() {
		synchronized (this) {
			if (!m_writing) synchronized (m_reading) {
				++m_reading.x;
				return true;
			}
		}
		return false;
	}
	
	void unlockRead() {
		synchronized (m_reading) {
			if (m_reading.x > 0) --m_reading.x;
		}
	}
	
	void lockWrite() {
		while (true) {
			synchronized (this) {
				if (!m_writing) {
					m_writing = true;
					while (true) {	// May as well continue to block m_writing since the writer can't continue until we're done anyways
						synchronized (m_reading) {
							if (m_reading.x == 0) {
								return;
							}
						}
						Thread.yield();
					}
				}
			}
			Thread.yield();
		}
	}
	
	bool tryLockWrite(bool waitRead = false) {
		if (waitRead) {
			synchronized (this) {
				if (!m_writing) {
					m_writing = true;
					while (true) {
						synchronized (m_reading) {
							if (m_reading.x == 0) {
								return true;
							}
						}
						Thread.yield();
					}
				}
			}
		}
		else {
			synchronized (this) {
				if (!m_writing) {
					synchronized (m_reading) {
						if (m_reading.x == 0) {
							m_writing = true;
							return true;
						}
					}
				}
			}
		}
		return false;
	}
	
	void unlockWrite() {
		synchronized (this) {
			m_writing = false;
		}
		Thread.yield;
	}
}
