module aahz.util.LinkedList;

import aahz.util.DArray;

// Reuses memory so that the garbage collector doesn't have to work, memory doesn't get fragmented, etc.
// Also allows items to be placed into "purgatory". This allows different threads to claim items in the queue and modify them without having to keep them locked

typedef uint LHandle = 0xffff_ffff;

class SList(T) {
private:
	enum ItemPlace : ubyte {
		QUEUE,
		PURGATORY,
		FREELIST
	}
	struct QueueItem {
		LHandle next;
		debug ItemPlace place;	// track where an item is so that we can check method parameters for sanity
		T item;
	}
	debug size_t m_purgatoryCount = 0;	// track these so people can verify that their own code is cleaning up properly
	debug size_t m_freeCount = 0;	// track these so people can verify that their own code is cleaning up properly

	DArray!(QueueItem) m_items;	// The Array object resizes itself without moving data to a new location. Thus, pointers to data in the array stay valid
	LHandle m_head, m_tail, m_freeHead;
	size_t m_itemCount = 0;
	
public:
	this() {
		m_items = new DArray!(QueueItem);
	}

	LHandle create(out T* item) {	// Creates an item in "purgatory" (untouchable by anyone who doesn't know its handle)
		LHandle handle;
		
		if (m_freeHead != LHandle.init) {	// Grab from the free list
			handle = m_freeHead;
			m_freeHead = m_items[m_freeHead].next;
			debug --m_freeCount;
		}
		else {	// Expand the buffer and use the new slot
			handle = cast(LHandle)m_items.length;
			m_items.length = cast(uint)handle + 1;
		}
		
		item = &((*m_items(handle)).item);
		
		debug ++m_purgatoryCount;
		debug { (*m_items(handle)).place = ItemPlace.PURGATORY; }
		
		return handle;
	}
	
	void queue(LHandle handle) {	// Moves item from purgatory to the queue
		debug {
			if (handle == LHandle.init || handle >= m_items.length) throw new Exception("Invalid handle");
			if ((*m_items(handle)).place != ItemPlace.PURGATORY) throw new Exception("Item is not in purgatory");
		}
		if (m_head == LHandle.init) {
			m_head = handle;
		}
		if (m_tail != LHandle.init) {
			(*m_items(m_tail)).next = handle;
		}
		(*m_items(handle)).next = LHandle.init;
		m_tail = handle;
		
		++m_itemCount;
		debug { (*m_items(handle)).place = ItemPlace.QUEUE; }
		debug --m_purgatoryCount;
	}
	
	LHandle claim(out T* item) {	// Moves the item at the head of the queue to purgatory
		LHandle handle;
		if (m_head == LHandle.init) {	// No items to claim
			handle = LHandle.init;
			return handle;
		}
		
		handle = m_head;
		item = &((*m_items(handle)).item);
		m_head = (*m_items(m_head)).next;
		
		--m_itemCount;
		debug ++m_purgatoryCount;
		debug { (*m_items(handle)).place = ItemPlace.PURGATORY; }
		
		return handle;
	}
	
	void release(LHandle handle) {	// Moves the specified item from purgatory to the free list
		debug {
			if (handle == LHandle.init || handle >= m_items.length) throw new Exception("Invalid handle");
			if ((*m_items(handle)).place != ItemPlace.PURGATORY) throw new Exception("Item is not in purgatory");
		}
		(*m_items(handle)).next = m_freeHead;
		m_freeHead = handle;
		
		debug --m_purgatoryCount;
		debug ++m_freeCount;
		debug { (*m_items(handle)).place = ItemPlace.FREELIST; }
	}
	
	void insertAfter(LHandle position, LHandle handle) {	// assumes that "position" is the handle to an item in the queue and "handle" is in purgatory
		debug {
			if (position == LHandle.init || position >= m_items.length) throw new Exception("Invalid handle");
			if (handle == LHandle.init || handle >= m_items.length) throw new Exception("Invalid handle");
			if ((*m_items(position)).place != ItemPlace.QUEUE) throw new Exception("Item is not in queue");
			if ((*m_items(handle)).place != ItemPlace.PURGATORY) throw new Exception("Item is not in purgatory");
		}
		if (position == m_tail) {	// make sure to update the tail if that's where we are
			m_tail = handle;
		}
		
		(*m_items(handle)).next = (*m_items(position)).next;
		(*m_items(position)).next = handle;
		
		++m_itemCount;
		debug --m_purgatoryCount;
		debug { (*m_items(handle)).place = ItemPlace.QUEUE; }
	}
	
	void insertBefore(LHandle position, LHandle handle) {	// assumes that "position" is the handle to an item in the queue and "handle" is in purgatory
		debug {
			if (position == LHandle.init || position >= m_items.length) throw new Exception("Invalid handle");
			if (handle == LHandle.init || handle >= m_items.length) throw new Exception("Invalid handle");
			if ((*m_items(position)).place != ItemPlace.QUEUE) throw new Exception("Item is not in queue");
			if ((*m_items(handle)).place != ItemPlace.PURGATORY) throw new Exception("Item is not in purgatory");
		}
		if (position == m_head) {	// see if we're adding it to the start of the queue
			(*m_items(handle)).next = m_head;
			m_head = handle;
			
			++m_itemCount;
			debug --m_purgatoryCount;
			debug { (*m_items(handle)).place = ItemPlace.QUEUE; }
			return;
		}
		
		LHandle curr = m_head;
		LHandle next = (*m_items(curr)).next;
		while (next != LHandle.init) {	// scan the queue, starting from the head, trying to find the one whose "next" is "position"
			if (next == position) {	// insert before "position"
				(*m_items(curr)).next = handle;
				(*m_items(handle)).next = position;
				
				++m_itemCount;
				debug --m_purgatoryCount;
				debug { (*m_items(handle)).place = ItemPlace.QUEUE; }
				return;
			}
			
			curr = next;
			next = (*m_items(curr)).next;
		}
	}
	
	void kill(LHandle handle) {	// assumes "handle" to be on the queue. Removes it from the queue and adds to the free list
		debug {
			if (handle == LHandle.init || handle >= m_items.length) throw new Exception("Invalid handle");
			if ((*m_items(handle)).place != ItemPlace.QUEUE) throw new Exception("Item is not in queue");
		}
		if (handle == m_head) {
			m_head = (*m_items(m_head)).next;
			(*m_items(handle)).next = m_freeHead;
			m_freeHead = handle;
			
			--m_itemCount;
			debug ++m_freeCount;
			debug { (*m_items(handle)).place = ItemPlace.FREELIST; }
			return;
		}
		
		LHandle curr = m_head;
		LHandle next = (*m_items(curr)).next;
		while (next != LHandle.init) {	// scan the queue, starting from the head, trying to find the one whose "next" is "handle"
			if (next == handle) {
				(*m_items(curr)).next = (*m_items(handle)).next;	// update the guy before it
				if (handle == m_tail) m_tail = curr;	// who might be the new tail
				
				(*m_items(handle)).next = m_freeHead;
				m_freeHead = handle;
			
				--m_itemCount;
				debug ++m_freeCount;
				debug { (*m_items(handle)).place = ItemPlace.FREELIST; }
				return;
			}
			
			curr = next;
			next = (*m_items(curr)).next;
		}
	}
	
	T* peek() {	// Looks at the item on the head
		if (m_head == LHandle.init) {	// No items to claim
			return null;
		}
		return &((*m_items(m_head)).item);
	}
	
	T* get(LHandle handle) {
		debug {
			if (handle == LHandle.init || handle >= m_items.length) throw new Exception("Invalid handle");
			if ((*m_items(handle)).place == ItemPlace.FREELIST) throw new Exception("Access of items in the freelist is undefined");
		}
		return &((*m_items(handle)).item);
	}
	
	LHandle head() {
		return m_head;
	}
	
	LHandle tail() {
		return m_tail;
	}
	
	LHandle next(LHandle handle) {
		debug {
			if (handle == LHandle.init || handle >= m_items.length) throw new Exception("Invalid handle");
		}
		return (*m_items(handle)).next;
	}
	
	size_t count() {
		return m_itemCount;
	}
	
	debug {
		size_t freeCount() {
			return m_freeCount;
		}
		
		size_t purgatoryCount() {
			return m_purgatoryCount;
		}
	}
	
	//iterate
	int opApply(int delegate(ref T*) dg) {
		int result = 0;
		LHandle currHandle = m_head;

		while (currHandle != LHandle.init) {
			T* thing = &((*m_items(currHandle)).item);
			result = dg( thing );
			if (result) break;
			
			currHandle = (*m_items(currHandle)).next;
		}
		return result;
	}
	
	int opApply(int delegate (ref T*, ref LHandle) dg) {
		int result = 0;
		LHandle currHandle = m_head;

		while (currHandle != LHandle.init) {
			T* thing = &((*m_items(currHandle)).item);
			result = dg( thing, currHandle );
			if (result) break;
			
			currHandle = (*m_items(currHandle)).next;
		}
		return result;
	}
}

class DList(T) {
private:
	enum ItemPlace : ubyte {
		QUEUE,
		PURGATORY,
		FREELIST
	}
	struct QueueItem {
		LHandle prev;
		LHandle next;
		debug ItemPlace place;	// track where an item is so that we can check method parameters for sanity
		T item;
	}
	debug size_t m_purgatoryCount = 0;	// track these so people can verify that their own code is cleaning up properly
	debug size_t m_freeCount = 0;	// track these so people can verify that their own code is cleaning up properly

	DArray!(QueueItem) m_items;	// The Array object resizes itself without moving data to a new location. Thus, pointers to data in the array stay valid
	LHandle m_head, m_tail, m_freeHead;
	size_t m_itemCount = 0;
	
public:
	this() {
		m_items = new DArray!(QueueItem);
	}

	LHandle create(out T* item) {	// Creates an item in "purgatory" (untouchable by anyone who doesn't know its handle)
		LHandle handle;
		
		if (m_freeHead != LHandle.init) {	// Grab from the free list
			handle = m_freeHead;
			m_freeHead = m_items[m_freeHead].next;
			debug --m_freeCount;
		}
		else {	// Expand the buffer and use the new slot
			handle = cast(LHandle)m_items.length;
			m_items.length = cast(uint)handle + 1;
		}
		
		item = &((*m_items(handle)).item);
		
		debug ++m_purgatoryCount;
		debug { (*m_items(handle)).place = ItemPlace.PURGATORY; }
		
		return handle;
	}
	
	void queue(LHandle handle) {	// Moves item from purgatory to the queue
		debug {
			if (handle == LHandle.init || handle >= m_items.length) throw new Exception("Invalid handle");
			if ((*m_items(handle)).place != ItemPlace.PURGATORY) throw new Exception("Item is not in purgatory");
		}
		if (m_head == LHandle.init) {
			m_head = handle;
		}
		if (m_tail != LHandle.init) {
			(*m_items(m_tail)).next = handle;
		}
		(*m_items(handle)).next = LHandle.init;
		(*m_items(handle)).prev = m_tail;
		m_tail = handle;
		
		++m_itemCount;
		debug { (*m_items(handle)).place = ItemPlace.QUEUE; }
		debug --m_purgatoryCount;
	}
	
	LHandle claim(out T* item) {	// Moves the item at the head of the queue to purgatory
		LHandle handle;
		if (m_head == LHandle.init) {	// No items to claim
			handle = LHandle.init;
			return handle;
		}
		
		handle = m_head;
		item = &((*m_items(handle)).item);
		m_head = (*m_items(m_head)).next;
		if (m_head != LHandle.init) (*m_items(m_head)).prev = LHandle.init;
		
		--m_itemCount;
		debug ++m_purgatoryCount;
		debug { (*m_items(handle)).place = ItemPlace.PURGATORY; }
		
		return handle;
	}
	
	void release(LHandle handle) {	// Moves the specified item from purgatory to the free list
		debug {
			if (handle == LHandle.init || handle >= m_items.length) throw new Exception("Invalid handle");
			if ((*m_items(handle)).place != ItemPlace.PURGATORY) throw new Exception("Item is not in purgatory");
		}
		(*m_items(handle)).next = m_freeHead;
		m_freeHead = handle;
		
		debug --m_purgatoryCount;
		debug ++m_freeCount;
		debug { (*m_items(handle)).place = ItemPlace.FREELIST; }
	}
	
	void insertAfter(LHandle position, LHandle handle) {	// assumes that "position" is the handle to an item in the queue and "handle" is in purgatory
		debug {
			if (position == LHandle.init || position >= m_items.length) throw new Exception("Invalid handle");
			if (handle == LHandle.init || handle >= m_items.length) throw new Exception("Invalid handle");
			if ((*m_items(position)).place != ItemPlace.QUEUE) throw new Exception("Item is not in queue");
			if ((*m_items(handle)).place != ItemPlace.PURGATORY) throw new Exception("Item is not in purgatory");
		}
		if (position == m_tail) {	// make sure to update the tail if that's where we are
			m_tail = handle;
		}
		
		LHandle next = (*m_items(position)).next;
		if (next != LHandle.init) (*m_items(next)).prev = handle;
		(*m_items(handle)).next = (*m_items(position)).next;
		(*m_items(handle)).prev = position;
		(*m_items(position)).next = handle;
		
		++m_itemCount;
		debug --m_purgatoryCount;
		debug { (*m_items(handle)).place = ItemPlace.QUEUE; }
	}
	
	void insertBefore(LHandle position, LHandle handle) {	// assumes that "position" is the handle to an item in the queue and "handle" is in purgatory
		debug {
			if (position == LHandle.init || position >= m_items.length) throw new Exception("Invalid handle");
			if (handle == LHandle.init || handle >= m_items.length) throw new Exception("Invalid handle");
			if ((*m_items(position)).place != ItemPlace.QUEUE) throw new Exception("Item is not in queue");
			if ((*m_items(handle)).place != ItemPlace.PURGATORY) throw new Exception("Item is not in purgatory");
		}
		if (position == m_head) {	// make sure it gets updated
			m_head = handle;
		}
		LHandle prev = (*m_items(position)).prev;
		if (prev != LHandle.init) (*m_items(prev)).next = handle;
		(*m_items(handle)).next = position;
		(*m_items(handle)).prev = (*m_items(position)).prev;
		(*m_items(position)).prev = handle;
		
		++m_itemCount;
		debug --m_purgatoryCount;
		debug { (*m_items(handle)).place = ItemPlace.QUEUE; }
	}
	
	void kill(LHandle handle) {	// assumes "handle" to be on the queue. Removes it from the queue and adds to the free list
		debug {
			if (handle == LHandle.init || handle >= m_items.length) throw new Exception("Invalid handle");
			if ((*m_items(handle)).place != ItemPlace.QUEUE) throw new Exception("Item is not in queue");
		}
		
		LHandle prev = (*m_items(handle)).prev;
		if ( prev != LHandle.init ) (*m_items(prev)).next = (*m_items(handle)).next;
		LHandle next = (*m_items(handle)).next;
		if ( next != LHandle.init ) (*m_items(next)).prev = prev;
		
		if (handle == m_head) m_head = next;
		if (handle == m_tail) m_tail = prev;
		
		m_freeHead = handle;
		
		--m_itemCount;
		debug ++m_freeCount;
		debug { (*m_items(handle)).place = ItemPlace.FREELIST; };
	}
	
	T* peek() {	// Looks at the item on the head
		if (m_head == LHandle.init) {	// No items to claim
			return null;
		}
		return &((*m_items(m_head)).item);
	}
	
	T* get(LHandle handle) {
		debug {
			if (handle == LHandle.init || handle >= m_items.length) throw new Exception("Invalid handle");
			if ((*m_items(handle)).place == ItemPlace.FREELIST) throw new Exception("Access of items in the freelist is undefined");
		}
		return &((*m_items(handle)).item);
	}
	
	LHandle head() {
		return m_head;
	}
	
	LHandle tail() {
		return m_tail;
	}
	
	LHandle next(LHandle handle) {
		debug {
			if (handle == LHandle.init || handle >= m_items.length) throw new Exception("Invalid handle");
		}
		return (*m_items(handle)).next;
	}
	
	LHandle prev(LHandle handle) {
		debug {
			if (handle == LHandle.init || handle >= m_items.length) throw new Exception("Invalid handle");
		}
		return (*m_items(handle)).prev;
	}
	
	size_t count() {
		return m_itemCount;
	}
	
	debug {
		size_t freeCount() {
			return m_freeCount;
		}
		
		size_t purgatoryCount() {
			return m_purgatoryCount;
		}
	}
	
	//iterate
	int opApply(int delegate (ref T* value) dg) {
		int result = 0;
		LHandle currHandle = m_head;

		while (currHandle != LHandle.init) {
			T* thing = &((*m_items(currHandle)).item);
			result = dg(thing);
			if (result) break;
			
			currHandle = (*m_items(currHandle)).next;
		}
		return result;
	}
	
	int opApply(int delegate (ref T*, ref LHandle) dg) {
		int result = 0;
		LHandle currHandle = m_head;

		while (currHandle != LHandle.init) {
			T* thing = &((*m_items(currHandle)).item);
			result = dg(thing, currHandle);
			if (result) break;
			
			currHandle = (*m_items(currHandle)).next;
		}
		return result;
	}
	
	int opApplyReverse(int delegate (ref T* value) dg) {
		int result = 0;
		LHandle currHandle = m_tail;

		while (currHandle != LHandle.init) {
			T* thing = &((*m_items(currHandle)).item);
			result = dg(thing);
			if (result) break;
			
			currHandle = (*m_items(currHandle)).prev;
		}
		return result;
	}
	
	int opApplyReverse(int delegate (ref T*, ref LHandle) dg) {
		int result = 0;
		LHandle currHandle = m_tail;

		while (currHandle != LHandle.init) {
			T* thing = &((*m_items(currHandle)).item);
			result = dg(thing, currHandle);
			if (result) break;
			
			currHandle = (*m_items(currHandle)).prev;
		}
		return result;
	}
}
