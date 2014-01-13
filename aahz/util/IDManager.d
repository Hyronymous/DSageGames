module aahz.util.IDManager;

class IDManager(T) {	// Recycle IDs that have been freed
private:
	T[] freeIDs;
	T currID;
	T maxID;
	
public:
	this(T start, T max) {
		currID = start;
		maxID = max;
	}
	
	T getID() {
		T ret;
		if (freeIDs.length == 0) {
			ret = currID;
			++currID;
		}
		else {
			ret = freeIDs[$-1];
			freeIDs.length = freeIDs.length - 1;
		}
		return ret;
	}
	
	void releaseID(T id) {
		freeIDs ~= id;
	}
}
