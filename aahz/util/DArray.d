module aahz.util.DArray;

import tango.core.BitManip;
import tango.io.Stdout;

// The Array object resizes itself without moving data to a new location.
// This speeds reallocation times, but hinders access times. The principal
// advantage is that pointers to data remain valid through resizings.

class DArray(T) {
private:
	T[][32] m_buffers;
	uint m_bufferCount = 0;
	static const uint[] MASK = [
		0x1,		0x1,		0x3,		0x7,		0xf,		0x1f,		0x3f,		0x7f,
		0xff,		0x1ff,		0x3ff,		0x7ff,		0xfff,		0x1fff,		0x3fff,		0x7fff,
		0xffff,		0x1ffff,	0x3ffff,	0x7ffff,	0xfffff,	0x1fffff,	0x3fffff,	0x7fffff,
		0xffffff,	0x1ffffff,	0x3ffffff,	0x7ffffff,	0xfffffff,	0x1fffffff,	0x3fffffff,	0x7fffffff
	];
	size_t m_length;
	
public:
	this() {
		m_buffers[0].length = 2;
		m_bufferCount = 1;
	}

	size_t length() {
		return m_length;
	}
	
	size_t length(size_t len) {
		m_length = len;
		
		len -= 1;
		uint newCount = (len == 0) ? 1 : (bsr(len) + 1);
		
		if (newCount > m_bufferCount) {
			for (uint L = m_bufferCount; L < newCount; L++) {
				m_buffers[L].length = 0x1 << L;
			}
			m_bufferCount = newCount;
		}
		
		return m_length;
	}
	
    T opIndex(size_t i) {
		uint buffer = 0;
		if (i != 0) buffer = bsr(i);
		return m_buffers[buffer][ i & MASK[buffer] ];
	}
	
    T opIndexAssign(T value, size_t i) {
		uint buffer = 0;
		if (i != 0) buffer = bsr(i);
		
		m_buffers[buffer][ i & MASK[buffer] ] = value;
		return m_buffers[buffer][ i & MASK[buffer] ];
	}
	
	T* opCall(size_t i) {
		uint buffer = 0;
		if (i != 0) buffer = bsr(i);
		return &(m_buffers[buffer][ i & MASK[buffer] ]);
	}
}
