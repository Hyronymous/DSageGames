module client.Link;

import aahz.widget.Event;
import tango.core.sync.Mutex;

Mutex graphicsMutex;

static this() {
	graphicsMutex = new Mutex();
}

abstract class SageApp {
public:
	alias SageApp function() AppCreate;
	static AppCreate[ char[] ] appCreator;
	
	void init();
	void cleanup();
}
