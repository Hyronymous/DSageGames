module aahz.util.TimeUpdate;

import tango.time.Clock;
import tango.time.Time;

class TimeUpdate {
private:
	Time m_start;
	
public:
	ulong time;
	ulong delta;
	
	this() {
		m_start = Clock.now();
		time = 0;
		delta = 0;
	}
	
	void update() {
		Time totalTime = Clock.now();
		ulong newTime = (totalTime - m_start).millis();
		delta = newTime - time;
		time = newTime;
	}
}
