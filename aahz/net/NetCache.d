module aahz.net.NetCache;

public import aahz.util.Queue;
public import aahz.net.NetSocket;
public import aahz.net.NetThread;

public import sqlite.dsqlite3;

public import tango.stdc.string;
public import tango.util.Convert;
import tango.io.Stdout;

package:

template NetCache() {	// Done as a mixin to break up files
static private:
	enum CacheID {
		IN = 0, OUT = 1,
		COUNT = 2
	}
	struct QueueItem {
		ulong addressID;
		uint packetID;
	}
	
	bool m_connected = false;
	Object[2] m_lock;
	ulong m_prevUpdate = 0;

	sqlite3*[2] m_db;	// Keep two separate files so we aren't blocking ourself half the time
	sqlite3_stmt*[2] m_insert;
	sqlite3_stmt*[2] m_update;
	sqlite3_stmt*[2] m_removeConn;
	sqlite3_stmt* m_selectSequential;
	sqlite3_stmt* m_selectFragments;
	sqlite3_stmt* m_selectOutput;
	sqlite3_stmt* m_selectOutputFragment;
	
	Queue!(QueueItem) m_queue;
	
	void doCommand(uint io, char[] query) {	// "query" is assumed to end in a \0 already
		int res;
		sqlite3_stmt* out_stmt;
		
		res = sqlite3_prepare_v2(
			m_db[io],				/* Database handle */
			query.ptr,				/* SQL statement, UTF-8 encoded */
			query.length,			/* Maximum length of zSql in bytes. */
			&out_stmt,				/* OUT: Statement handle */
			null					/* OUT: Pointer to unused portion of zSql */
		);
		if (res != SQLITE_OK) throw new Exception("Error preparing statement");

		do {
			res = sqlite3_step(out_stmt);
		}
		while (res == SQLITE_BUSY);
		sqlite3_finalize(out_stmt);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_ROW
			&& res != SQLITE_OK
		) {
			throw new Exception("Error executing query");
		}
	}
	
	void prepare(uint io, sqlite3_stmt** statement, char[] query) {
		int res = sqlite3_prepare_v2(
			m_db[io],			/* Database handle */
			query.ptr,			/* SQL statement, UTF-8 encoded */
			query.length,		/* Maximum length of zSql in bytes. */
			statement,			/* OUT: Statement handle */
			null				/* OUT: Pointer to unused portion of zSql */
		);
		if (res != SQLITE_OK) throw new Exception("Error preparing statement");
	}
	
	template OutputStuff(SendType sendType) {
		bool getOutput(uint packetID, inout NetAddress address, inout NetPacket packet) {
			bool found = false;
			int userDataLength = 0;
		
			efix!(uint)(packetID);	// Data in output cache is already fixed. Have to match it
			
			synchronized (m_lock[CacheID.OUT]) {
				int res = sqlite3_bind_blob(
					m_selectOutput,
					1,
					&packetID,
					packetID.sizeof,
					null
				);
				if (res != SQLITE_OK) throw new Exception("Error binding to statement");

				ulong addressID = address.toUID();
				sqlite3_bind_blob(
					m_selectOutput,
					2,
					&addressID,
					addressID.sizeof,
					null
				);
				
				SendType st = sendType;
				sqlite3_bind_blob(
					m_selectOutput,
					3,
					&st,
					st.sizeof,
					null
				);
				
				int isFragment = 0;
				sqlite3_bind_int(
					m_selectOutput,
					4,
					isFragment
				);
				
				do {
					res = sqlite3_step(m_selectOutput);
					if (res == SQLITE_ROW) {
						found = true;	// We have received a row of data
						
						NetCommand* ncptr = cast(NetCommand*)sqlite3_column_blob(m_selectOutput, 0);	// command
						packet.command = *ncptr;
						
						bool* bptr = cast(bool*)sqlite3_column_blob(m_selectOutput, 1);	// encrypted
						packet.encrypted = *bptr;
						
						uint* uiptr = cast(uint*)sqlite3_column_blob(m_selectOutput, 2);	// secondary
						packet.queryID = *uiptr;

						userDataLength = sqlite3_column_bytes(m_selectOutput, 3);
						ubyte* ubptr = cast(ubyte*)sqlite3_column_blob(m_selectOutput, 3);	// userData
						memmove(&packet.userData[0], ubptr, userDataLength);
					}
				}
				while (
					res == SQLITE_BUSY
					|| res == SQLITE_ROW
				);
				if (
					res != SQLITE_DONE
					&& res != SQLITE_OK
				) {
					throw new Exception("Error reading persistence data");
				}
				
				res = sqlite3_reset(m_selectOutput);
				if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
				
				res = sqlite3_clear_bindings(m_selectOutput);
				if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
			}
			
			if (found) {
				packet.packetSize = userDataLength + NetPacket.headerData.length;
				
				packet.packetID = packetID;
				packet.sendType = sendType;
				packet.resend = true;
				
				return true;
			}
			return false;
		}
	}
	
static protected:
	void open(char[] folder) {
		scope(success) m_connected = true;
		int res;
		char[][] path = [
			folder ~ "/NetCacheIn.db\0",
			folder ~ "/NetCacheOut.db\0"
		];
		
		m_lock[CacheID.IN] = new Object();
		m_lock[CacheID.OUT] = new Object();
		m_queue = new Queue!(QueueItem);
		
		sqlite3_config(SQLITE_CONFIG_SINGLETHREAD);	// We'll handle locking ourselves

		for (uint L = 0; L < CacheID.COUNT; L++) {
			char[] query;
			
			res = sqlite3_open(path[L].ptr, &m_db[L]);
			if (res != SQLITE_OK) throw new Exception("Couldn't open database. (Probably either could not get access permission or file is corrupted)");
			scope(failure) sqlite3_close(m_db[L]);
			
			// Speed optimizations
			doCommand(L, "PRAGMA locking_mode=EXCLUSIVE\0");	// We are the only ones using the file, so no need to lock/unlock the file for each operation
			doCommand(L, "PRAGMA synchronous=OFF\0");	// We're not trying to create persistent data so it's alright if it can become corrupted if we crash
			
			// Set up table and queries
			query =
				"CREATE TABLE IF NOT EXISTS "
				"cache_table ("
					~ "inTime INTEGER NOT NULL, "	// time inserted into DB
					~ "isFragment INTEGER NOT NULL, "	// boolean
					~ "address BLOB NOT NULL, "
					~ "command BLOB NOT NULL, "
					~ "sendType BLOB NOT NULL, "
					~ "encrypted BLOB NOT NULL, "
					~ "packetID BLOB NOT NULL, "
					~ "secondary BLOB NOT NULL, "		//  for fragment or queryID
					~ "userData BLOB NOT NULL"
				~ ")\0"
			;	// Make sure our table exists
			doCommand(L, query);
			
			query =
				"CREATE INDEX IF NOT EXISTS time_index "
				~ "ON cache_table (inTime)\0"
			;
			doCommand(L, query);
			
			query =
				"CREATE INDEX IF NOT EXISTS address_index "
				~ "ON cache_table (address)\0"
			;
			doCommand(L, query);
			
			query =
				"CREATE INDEX IF NOT EXISTS packet_index "
				~ "ON cache_table (packetID)\0"
			;
			doCommand(L, query);
			
			query = "DELETE FROM cache_table\0";	// Clear it in case there's still data remaining (e.g. we crashed the last time we ran)
			doCommand(L, query);
			
			query =
				"INSERT INTO cache_table "
				~ "(inTime, isFragment, address, command, sendType, encrypted, packetID, secondary, userData)"
				~ "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)\0"
			;
			prepare(L, &m_insert[L], query);
			scope (failure) sqlite3_finalize(m_insert[L]);
			
			query =
				"DELETE FROM cache_table "
				~ "WHERE inTime<?\0"
			;
			prepare(L, &m_update[L], query);
			scope (failure) sqlite3_finalize(m_update[L]);
			
			query =
				"DELETE FROM cache_table "
				~ "WHERE address=?\0"
			;
			prepare(L, &m_removeConn[L], query);
			scope (failure) sqlite3_finalize(m_removeConn[L]);
			
			if (L == CacheID.IN) {
				query = 
					"SELECT command, encrypted, secondary, userData "
					~ "FROM cache_table "
					~ "WHERE packetID=? AND address=? AND isFragment=0 AND sendType=" ~ to!(char[])(SendType.SEQUENTIAL)
					~ "\0"
				;
				prepare(L, &m_selectSequential, query);
				scope (failure) sqlite3_finalize(m_selectSequential);
				
				query =
					"SELECT secondary, userData "
					~ "FROM cache_table "
					~ "WHERE packetID=? AND address=? AND isFragment=1"
					~ "\0"
				;
				prepare(L, &m_selectFragments, query);
				scope (failure) sqlite3_finalize(m_selectFragments);
			}
			else {	// CacheID.OUT
				query = 
					"SELECT command, encrypted, secondary, userData "
					~ "FROM cache_table "
					~ "WHERE packetID=? AND address=? AND sendType =? AND isFragment=?"
					~ "\0"
				;
				prepare(L, &m_selectOutput, query);
				scope (failure) sqlite3_finalize(m_selectOutput);
				
				query = 
					"SELECT command, encrypted, userData "
					~ "FROM cache_table "
					~ "WHERE packetID=? AND address=? AND sendType =? AND isFragment=? AND secondary=?"
					~ "\0"
				;
				prepare(L, &m_selectOutputFragment, query);
				scope (failure) sqlite3_finalize(m_selectOutputFragment);
			}
		}
	}
	
	void close() {
		if (m_connected) {
			for (uint L = 0; L < CacheID.COUNT; L++) {	// Erase all data in tables
				doCommand(L, "DELETE FROM cache_table");
			}
			
			sqlite3_finalize(m_insert[CacheID.IN]);
			sqlite3_finalize(m_insert[CacheID.OUT]);
			sqlite3_finalize(m_update[CacheID.IN]);
			sqlite3_finalize(m_update[CacheID.OUT]);
			sqlite3_finalize(m_removeConn[CacheID.IN]);
			sqlite3_finalize(m_removeConn[CacheID.OUT]);
			sqlite3_finalize(m_selectSequential);
			sqlite3_finalize(m_selectFragments);
			sqlite3_finalize(m_selectOutput);
			sqlite3_finalize(m_selectOutputFragment);
			
			sqlite3_close(m_db[CacheID.IN]);
			sqlite3_close(m_db[CacheID.OUT]);
			
			m_queue.empty();
		}
		m_connected = false;
	}
	
	void update(ulong time) {
		if ((time - m_prevUpdate) >= 2_000) {	// If it's been more than 2 seconds since our last update, clear out any data older than 10 seconds
			m_prevUpdate = time;
			ulong cleanTime = time - 10_000;	// Ten seconds ago

			synchronized (m_lock[CacheID.IN]) {
				int res = sqlite3_bind_int64(
					m_update[CacheID.IN],
					1,
					cleanTime
				);
				if (res != SQLITE_OK) throw new Exception("Error binding to statement");

				do {
					res = sqlite3_step(m_update[CacheID.IN]);
				}
				while (
					res == SQLITE_BUSY
				);
				if (
					res != SQLITE_DONE
					&& res != SQLITE_OK
				) {
					throw new Exception("Error reading persistence data");
				}
				
				res = sqlite3_reset(m_update[CacheID.IN]);
				if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
				
				res = sqlite3_clear_bindings(m_update[CacheID.IN]);
				if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
			}
			synchronized (m_lock[CacheID.OUT]) {
				int res = sqlite3_bind_int64(
					m_update[CacheID.OUT],
					1,
					cleanTime
				);
				if (res != SQLITE_OK) throw new Exception("Error binding to statement");

				do {
					res = sqlite3_step(m_update[CacheID.OUT]);
				}
				while (
					res == SQLITE_BUSY
				);
				if (
					res != SQLITE_DONE
					&& res != SQLITE_OK
				) {
					throw new Exception("Error reading persistence data");
				}
				
				res = sqlite3_reset(m_update[CacheID.OUT]);
				if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
				
				res = sqlite3_clear_bindings(m_update[CacheID.OUT]);
				if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
			}
		}
	}
	
	void finalizeSequential(inout NetAddress address) {	// Upper layer has finished processing a sequential packet
		NetThread t = cast(NetThread)NetThread.getThis();
		if (t.conn is null) throw new Exception("Incoming sequential packet wasn't locked");
		
		++t.conn.sequentialProcessed;
		uint offset = t.conn.sequentialProcessed - t.conn.sequentialBase + 1;
		if (offset >= (t.conn.sequentialBits.length * 8)) {	// Check that we haven't lost data
			throw new ClientDisconnect("Sequential data lost");
		}
		
		if (t.conn.testSequential(offset)) {
			QueueItem qI;
			qI.addressID = address.toUID();
			qI.packetID = t.conn.sequentialProcessed + 1;
			synchronized (m_queue) {
				m_queue.add(qI);
			}
		}
	}
	
	bool getCachedInput(inout NetPacketX packet, inout NetAddress address) {	// Check if there is a packet ready to be processed (will always be a sequential packet)
		bool found = false;
		QueueItem qI;
		
		synchronized (m_queue) {
			if (m_queue.count() > 0) {
				qI = m_queue.take();
				found = true;
			}
		}
		if (found) {
			found = false;	// Some chance that the data has been deleted from the DB

			synchronized (m_lock[CacheID.IN]) {
				int res = sqlite3_bind_blob(
					m_selectSequential,
					1,
					&qI.packetID,
					qI.packetID.sizeof,
					null
				);
				if (res != SQLITE_OK) throw new Exception("Error binding to statement");

				sqlite3_bind_blob(
					m_selectSequential,
					2,
					&qI.addressID,
					qI.addressID.sizeof,
					null
				);
				
				do {
					res = sqlite3_step(m_selectSequential);
					if (res == SQLITE_ROW) {
						found = true;	// We have received a row of data
						
						NetCommand* ncptr = cast(NetCommand*)sqlite3_column_blob(m_selectSequential, 0);	// command
						packet.command = *ncptr;
						
						bool* bptr = cast(bool*)sqlite3_column_blob(m_selectSequential, 1);	// encrypted
						packet.encrypted = *bptr;
						
						uint* uiptr = cast(uint*)sqlite3_column_blob(m_selectSequential, 2);	// secondary
						packet.queryID = *uiptr;
						
						int length = sqlite3_column_bytes(m_selectOutput, 3);
						ubyte* ubptr = cast(ubyte*)sqlite3_column_blob(m_selectSequential, 3);	// userData
						memmove(&packet.userData[0], ubptr, length);
					}
				}
				while (
					res == SQLITE_BUSY
					|| res == SQLITE_ROW
				);
				if (
					res != SQLITE_DONE
					&& res != SQLITE_OK
				) {
					throw new Exception("Error reading persistence data");
				}
				
				res = sqlite3_reset(m_selectSequential);
				if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
				
				res = sqlite3_clear_bindings(m_selectSequential);
				if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
			}
			
			if (found) {
				address.set( qI.addressID );
				packet.packetID = qI.packetID;
				packet.sendType = SendType.SEQUENTIAL;
				
				return true;
			}
		}
		return false;
	}
	
	mixin OutputStuff!(SendType.RELIABLE) OSR;
	mixin OutputStuff!(SendType.SEQUENTIAL) OSS;
	alias OSR.getOutput getReliableOutput;
	alias OSS.getOutput getSequentialOutput;
	
	bool getFragmentOutput(uint packetID, ushort fragment, inout NetAddress address, inout NetPacket packet) {
		bool found = false;
		int userDataLength;
		
		efix!(uint)(packetID);	// Data in output cache is already fixed. Have to match it
		efix!(ushort)(fragment);
		
		synchronized (m_lock[CacheID.OUT]) {
			int res = sqlite3_bind_blob(
				m_selectOutputFragment,
				1,
				&packetID,
				packetID.sizeof,
				null
			);
			if (res != SQLITE_OK) throw new Exception("Error binding to statement");

			ulong addressID = address.toUID();
			sqlite3_bind_blob(
				m_selectOutputFragment,
				2,
				&addressID,
				addressID.sizeof,
				null
			);

			SendType st = SendType.RELIABLE;
			sqlite3_bind_blob(
				m_selectOutputFragment,
				3,
				&st,
				st.sizeof,
				null
			);
			
			int isFragment = 1;
			sqlite3_bind_int(
				m_selectOutputFragment,
				4,
				isFragment
			);
			
			sqlite3_bind_blob(
				m_selectOutputFragment,
				5,
				&fragment,
				fragment.sizeof,
				null
			);
			
			do {
				res = sqlite3_step(m_selectOutputFragment);
				if (res == SQLITE_ROW) {
					found = true;	// We have received a row of data
					
					NetCommand* ncptr = cast(NetCommand*)sqlite3_column_blob(m_selectOutputFragment, 0);	// command
					packet.command = *ncptr;
					
					bool* bptr = cast(bool*)sqlite3_column_blob(m_selectOutputFragment, 1);	// encrypted
					packet.encrypted = *bptr;
					
					userDataLength = sqlite3_column_bytes(m_selectOutput, 2);
					ubyte* ubptr = cast(ubyte*)sqlite3_column_blob(m_selectOutputFragment, 2);	// userData
					memmove(&packet.userData[0], ubptr, userDataLength);
				}
			}
			while (
				res == SQLITE_BUSY
				|| res == SQLITE_ROW
			);
			if (
				res != SQLITE_DONE
				&& res != SQLITE_OK
			) {
				throw new Exception("Error reading persistence data");
			}
			
			res = sqlite3_reset(m_selectOutputFragment);
			if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
			
			res = sqlite3_clear_bindings(m_selectOutputFragment);
			if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
		}
		
		if (found) {
			packet.packetSize = userDataLength + NetPacket.headerData.length;
			
			packet.packetID = packetID;
			packet.fragment = fragment;
			packet.sendType = SendType.RELIABLE;
			packet.resend = true;
			
			return true;
		}
		return false;
	}

	bool received(ulong time, inout NetAddress address, inout NetPacketX packet) {	// Check if the full packet has been received, otherwise insert into cache
		NetThread t = cast(NetThread)NetThread.getThis();
		if (t.conn is null) throw new Exception("Incoming reliable/sequential packet wasn't locked");
		
		switch (packet.sendType) {
		case SendType.RELIABLE:
			if (	// Fragmented
				(packet.command & NetCommand.TYPE_MASK) == NetCommand.NORMAL
				&& packet.fragmentAll != 0
			) {
				if (packet.fragmentCount > PACKETS_PER_MULTI_MAX || packet.fragment >= PACKETS_PER_MULTI_MAX) return false;	// Bad packet. Drop it
				
				uint offset = packet.packetID - t.conn.fragmentBase;
				if (offset >= t.conn.fragmentBits.length) {	// Exceeded bit buffer
					int pos = offset - t.conn.fragmentBits.length + 1;	// Try to place the new packet at the very end of the buffer so that we preserve as much information as we can
					if (pos >= t.conn.fragmentBits.length) {	// We've missed an entire buffer's worth of packets, so dump all info
						t.conn.fragmentBase += pos;
						t.conn.fragmentBits[] = 0;
					}
					else {	// Can be shifted
						t.conn.shiftFragment(pos);
					}
					offset = packet.packetID - t.conn.reliableBase;
				}

				if (t.conn.testFragment(offset, packet.fragment)) return false;	// We already have the fragment. Drop the new one
				t.conn.setFragment(offset, packet.fragmentCount, packet.fragment);
				
				if (t.conn.bitCount5(t.conn.fragmentBits[offset]) == packet.fragmentCount) {	// All fragments filled
					memmove(&packet.userData[ packet.fragment * PacketMax.SINGLE ], &packet.userData[0], packet.packetSize - packet.headerData.sizeof);
					packet.fragmentAll = 0;	// Clear since we'll have a full packet now

					synchronized (m_lock[CacheID.IN]) {
						int res = sqlite3_bind_blob(
							m_selectFragments,
							1,
							&packet.packetID,
							packet.packetID.sizeof,
							null
						);
						if (res != SQLITE_OK) throw new Exception("Error binding to statement");
						
						ulong addressID = address.toUID();
						sqlite3_bind_blob(
							m_selectFragments,
							2,
							&addressID,
							addressID.sizeof,
							null
						);
						
						do {
							res = sqlite3_step(m_selectFragments);
							if (res == SQLITE_ROW) {
								ushort* usptr = cast(ushort*)sqlite3_column_blob(m_selectFragments, 0);	// secondary (fragment)
								ushort fragment = *usptr;

								int length = sqlite3_column_bytes(m_selectFragments, 1);
								ubyte* ubptr = cast(ubyte*)sqlite3_column_blob(m_selectFragments, 1);	// userData
								memmove(&packet.userData[ fragment * PacketMax.SINGLE ], ubptr, length);
							}
						}
						while (
							res == SQLITE_BUSY
							|| res == SQLITE_ROW
						);
						if (
							res != SQLITE_DONE
							&& res != SQLITE_OK
						) {
							throw new Exception("Error reading persistence data");
						}
						
						res = sqlite3_reset(m_selectFragments);
						if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
						
						res = sqlite3_clear_bindings(m_selectFragments);
						if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
					}
					
					return true;	// Upper level can use the packet now that it has all been filled in
				}
				else {	// As yet unfilled. Stick it in the cache
					int res;
					int isFragment = 1;
					ulong compactAddress = address.toUID();
					
					synchronized (m_lock[CacheID.IN]) {
						sqlite3_bind_int64(
							m_insert[CacheID.IN],
							1,
							time
						);
						if (res != SQLITE_OK) throw new Exception("Error binding to statement");	// If this doesn't error, assume everything will work fine for the rest of the binds (for the sake of speed)
						
						sqlite3_bind_int(
							m_insert[CacheID.IN],
							2,
							isFragment
						);
						sqlite3_bind_blob(
							m_insert[CacheID.IN],
							3,
							&compactAddress,
							compactAddress.sizeof,
							null
						);
						sqlite3_bind_blob(
							m_insert[CacheID.IN],
							4,
							&packet.command,
							packet.command.sizeof,
							null
						);
						sqlite3_bind_blob(
							m_insert[CacheID.IN],
							5,
							&packet.sendType,
							packet.sendType.sizeof,
							null
						);
						sqlite3_bind_blob(
							m_insert[CacheID.IN],
							6,
							&packet.encrypted,
							packet.encrypted.sizeof,
							null
						);
						sqlite3_bind_blob(
							m_insert[CacheID.IN],
							7,
							&packet.packetID,
							packet.packetID.sizeof,
							null
						);
						sqlite3_bind_blob(
							m_insert[CacheID.IN],
							8,
							&packet.fragment,
							packet.fragment.sizeof,
							null
						);
						sqlite3_bind_blob(
							m_insert[CacheID.IN],
							9,
							&packet.userData[0],
							packet.packetSize - packet.headerData.sizeof,
							null
						);
						
						do {
							res = sqlite3_step(m_insert[CacheID.IN]);
						}
						while (res == SQLITE_BUSY);
						
						if (
							res != SQLITE_DONE
							&& res != SQLITE_OK
						) {
							throw new Exception("Error writing persistence data");
						}
						
						res = sqlite3_reset(m_insert[CacheID.IN]);
						if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
						
						res = sqlite3_clear_bindings(m_insert[CacheID.IN]);
						if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
					}
					
					return false;
				}
			}
			else {	// Non-fragmented
				uint offset = packet.packetID - t.conn.reliableBase;
				if (offset >= (t.conn.reliableBits.length * 8)) {	// Exceeded bit buffer
					int pos = offset - (t.conn.reliableBits.length * 8) + 1;	// Try to place the new packet at the very end of the buffer so that we preserve as much information as we can
					if (pos >= (t.conn.reliableBits.length * 8)) {	// We've missed an entire buffer's worth of packets, so dump all info
						t.conn.reliableBase += pos;
						t.conn.reliableBits[] = 0;
					}
					else {	// Can be shifted
						t.conn.shiftReliable(pos);
					}
					offset = packet.packetID - t.conn.reliableBase;
				}
				
				if (t.conn.testReliable(offset)) return false;	// We've already received/processed this packet. Drop it 
				t.conn.setReliable(offset);	// Mark as received
				return true;	// We can use the packet as is
			}
		break;
		case SendType.SEQUENTIAL:
			int firstEmpty;
			uint offset = packet.packetID - t.conn.sequentialBase;
			if (offset > 1000) {	// We appear to have lost track so DC the client
				 throw new ClientDisconnect("Sequential data lost");
			}
			else if (offset >= (t.conn.sequentialBits.length * 8)) {	// Exceeded bit buffer
				firstEmpty = ConnectionData.firstEmpty(t.conn.sequentialBits);
				if (firstEmpty == 0) return false;	// If the bottom bit is unset (the packet hasn't been received) we can't shift the buffer forward to mark the new packet as received, so just drop the packet
				t.conn.shiftSequential(firstEmpty);	// Shift so that the first empty slot is at the bottom of the buffer
				
				offset = packet.packetID - t.conn.sequentialBase;
				if (offset >= (t.conn.sequentialBits.length * 8)) return false;	// Still can't fit the packet in so drop it
				firstEmpty = 0;
			}
			else {
				firstEmpty = ConnectionData.firstEmpty(t.conn.sequentialBits);
			}
			
			if (t.conn.testSequential(offset)) return false;	// We've already received/processed this packet. Drop it 
			t.conn.setSequential(offset);
			if (
				firstEmpty == offset	// If it's the lowest item, there's a good chance that it's the next sequential item to be processed
				&& ((t.conn.sequentialProcessed + 1) == (t.conn.sequentialBase + offset))	// Verify that it is
			) {
				return true;	// Tell the server to process it right now. No need to insert it into the cache
			}
			else {	// Save it for later
				int res;
				int isFragment = 0;
				ulong compactAddress = address.toUID();
				
				synchronized (m_lock[CacheID.IN]) {
					res = sqlite3_bind_int64(
						m_insert[CacheID.IN],
						1,
						time
					);
					if (res != SQLITE_OK) throw new Exception("Error binding to statement");	// If this doesn't error, assume everything will work fine for the rest of the binds (for the sake of speed)
					
					res = sqlite3_bind_int(
						m_insert[CacheID.IN],
						2,
						isFragment
					);
					sqlite3_bind_blob(
						m_insert[CacheID.IN],
						3,
						&compactAddress,
						compactAddress.sizeof,
						null
					);
					sqlite3_bind_blob(
						m_insert[CacheID.IN],
						4,
						&packet.command,
						packet.command.sizeof,
						null
					);
					sqlite3_bind_blob(
						m_insert[CacheID.IN],
						5,
						&packet.sendType,
						packet.sendType.sizeof,
						null
					);
					sqlite3_bind_blob(
						m_insert[CacheID.IN],
						6,
						&packet.encrypted,
						packet.encrypted.sizeof,
						null
					);
					sqlite3_bind_blob(
						m_insert[CacheID.IN],
						7,
						&packet.packetID,
						packet.packetID.sizeof,
						null
					);
					sqlite3_bind_blob(
						m_insert[CacheID.IN],
						8,
						&packet.queryID,
						packet.queryID.sizeof,
						null
					);
					sqlite3_bind_blob(
						m_insert[CacheID.IN],
						9,
						&packet.userData[0],
						packet.packetSize - packet.headerData.sizeof,
						null
					);
					
					do {
						res = sqlite3_step(m_insert[CacheID.IN]);
					}
					while (res == SQLITE_BUSY);
					
					if (
						res != SQLITE_DONE
						&& res != SQLITE_OK
					) {
						throw new Exception("Error writing persistence data");
					}
					
					res = sqlite3_reset(m_insert[CacheID.IN]);
					if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
					
					res = sqlite3_clear_bindings(m_insert[CacheID.IN]);
					if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
				}
				
				return false;
			}
		break;
		default:
		break;
		}
		
		return false;
	}
	
	void sent(ulong time, inout NetAddress address, inout NetPacket packet) {
		int res;
		int isFragment = 0;		
		ulong compactAddress = address.toUID();
					
		if (	// Fragmented
			(packet.command & NetCommand.TYPE_MASK) == NetCommand.NORMAL
			&& packet.fragmentAll != 0
		) {
			isFragment = 1;
		}
		
		synchronized (m_lock[CacheID.OUT]) {
			res = sqlite3_bind_int64(
				m_insert[CacheID.OUT],
				1,
				time
			);
			if (res != SQLITE_OK) throw new Exception("Error binding to statement");	// If this doesn't error, assume everything will work fine for the rest of the binds (for the sake of speed)
			
			res = sqlite3_bind_int(
				m_insert[CacheID.OUT],
				2,
				isFragment
			);
			sqlite3_bind_blob(
				m_insert[CacheID.OUT],
				3,
				&compactAddress,
				compactAddress.sizeof,
				null
			);
			sqlite3_bind_blob(
				m_insert[CacheID.OUT],
				4,
				&packet.command,
				packet.command.sizeof,
				null
			);
			sqlite3_bind_blob(
				m_insert[CacheID.OUT],
				5,
				&packet.sendType,
				packet.sendType.sizeof,
				null
			);
			sqlite3_bind_blob(
				m_insert[CacheID.OUT],
				6,
				&packet.encrypted,
				packet.encrypted.sizeof,
				null
			);
			sqlite3_bind_blob(
				m_insert[CacheID.OUT],
				7,
				&packet.packetID,
				packet.packetID.sizeof,
				null
			);
			sqlite3_bind_blob(
				m_insert[CacheID.OUT],
				8,
				&packet.queryID,
				packet.queryID.sizeof,
				null
			);
			sqlite3_bind_blob(
				m_insert[CacheID.OUT],
				9,
				&packet.userData[0],
				packet.packetSize - packet.headerData.sizeof,
				null
			);
			
			do {
				res = sqlite3_step(m_insert[CacheID.OUT]);
			}
			while (res == SQLITE_BUSY);
			
			if (
				res != SQLITE_DONE
				&& res != SQLITE_OK
			) {
				throw new Exception("Error writing persistence data");
			}
			
			res = sqlite3_reset(m_insert[CacheID.OUT]);
			if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
			
			res = sqlite3_clear_bindings(m_insert[CacheID.OUT]);
			if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
		}
	}
	
	void removeConnection(inout NetAddress address) {
		for (uint L = 0; L < CacheID.COUNT; L++) {
			synchronized (m_lock[L]) {
				ulong addressID = address.toUID();
				int res = sqlite3_bind_blob(
					m_removeConn[L],
					1,
					&addressID,
					addressID.sizeof,
					null
				);
				if (res != SQLITE_OK) throw new Exception("Error binding to statement");

				
				do {
					res = sqlite3_step(m_removeConn[L]);
				}
				while (
					res == SQLITE_BUSY
					|| res == SQLITE_ROW
				);
				if (
					res != SQLITE_DONE
					&& res != SQLITE_OK
				) {
					throw new Exception("Error reading persistence data");
				}
				
				res = sqlite3_reset(m_removeConn[L]);
				if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
				
				res = sqlite3_clear_bindings(m_removeConn[L]);
				if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
			}
		}
	}
}
