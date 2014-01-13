module aahz.net.NetConnections;

import aahz.net.Net;
import aahz.net.NetSocket;
import aahz.util.RWLock;
import tango.core.Thread;
import tango.io.Stdout;

class NetConnections : RWLock {
private:
	const float MAX_FILL = 0.85;
	ConnectionData[] m_data;
	size_t m_inserted = 0;
	
	void rehash(inout hash_t h, int depth) {
		h ^= depth;
		h *= 0x91E404FF;
	}
	
public:
	this() {
		m_data = new ConnectionData[2];
	}

	void insert(ConnectionData o) {
		uint depth = 0;
		hash_t h = o.address.toHash();
		uint index = h % m_data.length;
		while (true) {
			if (m_data[index] is null) break;
			if (m_data[index].address == o.address) return;	// Already have it -- Ignore it
			rehash(h, depth++);
			index = h % m_data.length;
		}
		m_data[index] = o;
		
		++m_inserted;
		float filled = cast(float)m_inserted / cast(float)m_data.length;
		if (filled >= MAX_FILL) {
			ConnectionData[] newData;
			uint oldLength = m_data.length;
			uint newLength = oldLength + (oldLength >> 1);
			newData = new ConnectionData[newLength];
			
			for (uint L = 0; L < oldLength; L++) {
				if (m_data[L] !is null) {
					depth = 0;
					h = m_data[L].address.toHash();
					index = h % newData.length;
					while (newData[index] !is null) {
						rehash(h, depth++);
						index = h % newData.length;
					}
					newData[index] = m_data[L];
				}
			}
			delete m_data;
			m_data = newData;
		}
	}
	
	bool contains(NetAddress o) {
		uint depth = 0;
		hash_t h = o.toHash();
		uint index = h % m_data.length;
		while (true) {
			if (m_data[index] is null) return false;
			if (m_data[index].address == o) return true;
			rehash(h, depth++);
			index = h % m_data.length;
		}
	}
	
	ConnectionData get(NetAddress o) {
		uint depth = 0;
		hash_t h = o.toHash();
		uint index = h % m_data.length;
		while (true) {
			if (m_data[index] is null) return null;
			if (m_data[index].address == o) return m_data[index];
			rehash(h, depth++);
			index = h % m_data.length;
		}
	}
	
	void remove(NetAddress o) {
		uint depth = 0;
		hash_t h = o.toHash();
		uint index = h % m_data.length;
		while (true) {
			if (m_data[index] is null) return;
			if (m_data[index].address == o) {
				m_data[index] = null;
				--m_inserted;
				return;
			}
			rehash(h, depth++);
			index = h % m_data.length;
		}
	}
	
	void clear() {
		m_data.length = 2;
		m_data[0] = null;
		m_data[1] = null;
		m_inserted = 0;
	}
	
	size_t length() {
		return m_inserted;
	}
	
	int opApply(int delegate(ref ConnectionData) dg) {
		int result = 0;
		for (uint L = 0; L < m_data.length; L++) {
			if (m_data[L] !is null) {
				result = dg(m_data[L]);
				if (result) break;
			}
		}
		return result;
	}
	

/*
	void lockRead() {
synchronized (Stdout) Stdout("->R\n").flush;
		super.lockRead();
synchronized (Stdout) Stdout("->R2\n").flush;
	}
	
	bool tryLockRead() {
synchronized (Stdout) Stdout("->TR\n").flush;
		return super.tryLockRead();
synchronized (Stdout) Stdout("->TR2\n").flush;
	}
	
	void unlockRead() {
synchronized (Stdout) Stdout("<-R\n").flush;
		super.unlockRead();
synchronized (Stdout) Stdout("<-R2\n").flush;
	}
	
	void lockWrite() {
synchronized (Stdout) Stdout("->W\n").flush;
		super.lockWrite();
synchronized (Stdout) Stdout("->W2\n").flush;
	}
	
	bool tryLockWrite(bool waitRead = false) {
synchronized (Stdout) Stdout("->TW\n").flush;
		return super.tryLockWrite(waitRead);
synchronized (Stdout) Stdout("->TW2\n").flush;
	}
	
	void unlockWrite() {
synchronized (Stdout) Stdout("<-W\n").flush;
		super.unlockWrite();
synchronized (Stdout) Stdout("<-W2\n").flush;
	}
*/
}
