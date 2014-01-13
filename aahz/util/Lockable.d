module aahz.util.Lockable;

import tango.core.Thread;

class Lockable(T) {	// Lets us lock basic types
public:
	T x;
}
