module aahz.util.Persistent;

import sqlite.dsqlite3;
import tango.io.Stdout;
import tango.core.sync.ReadWriteMutex;
import tango.util.Convert;

abstract class PBase : ReadWriteMutex {
protected:
	sqlite3* m_db = null;
	bool m_connected = false;
	
	void doCommand(char[] query) {	// "query" is assumed to end in a \0 already
		int res;
		sqlite3_stmt* out_stmt;
		
		res = sqlite3_prepare_v2(
			m_db,					/* Database handle */
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
			&& res != SQLITE_OK
		) {
			throw new Exception("Error executing query");
		}
	}
	
	void prepare(sqlite3_stmt** statement, char[] query) {
		int res = sqlite3_prepare_v2(
			m_db,						/* Database handle */
			query.ptr,				/* SQL statement, UTF-8 encoded */
			query.length,			/* Maximum length of zSql in bytes. */
			statement,			/* OUT: Statement handle */
			null					/* OUT: Pointer to unused portion of zSql */
		);
		if (res != SQLITE_OK) throw new Exception("Error preparing statement");
	}
	
public:
	this() {
		super(Policy.PREFER_WRITERS);
	}
}

class PManager : PBase {
private:
	sqlite3_stmt* m_getStatement = null;
	sqlite3_stmt* m_setStatement = null;
	
public:
	void open(char[] folder, char[] table) {
		scope(success) m_connected = true;
		int res;
		char[] path = folder ~ "/" ~ table ~ ".db\0";

		sqlite3_config(SQLITE_CONFIG_SINGLETHREAD);	// We'll handle locking ourselves
		
		res = sqlite3_open(path.ptr, &m_db);
		if (res != SQLITE_OK) throw new Exception("Couldn't open persistence database.");
		scope(failure) sqlite3_close(m_db);
		
		char[] query =
			"CREATE TABLE IF NOT EXISTS "
			~ table ~ " ("
				~ "name BLOB PRIMARY KEY, "
				~ "value BLOB NOT NULL"
			~ ")\0"
		;	// Make sure our table exists
		doCommand(query);
		
		query =
			"SELECT value "
			~ "FROM " ~ table ~ " "
			~ "WHERE name=?\0"
		;
		prepare(&m_getStatement, query);
		scope (failure) sqlite3_finalize(m_getStatement);
		
		query =
			"REPLACE INTO " ~ table ~ " "
			~ "(name, value)"
			~ "VALUES (?, ?)\0"
		;
		prepare(&m_setStatement, query);
	}
	
	void close() {
		if (m_connected) {
			sqlite3_finalize(m_getStatement);
			sqlite3_finalize(m_setStatement);
			sqlite3_close(m_db);
		}
		m_connected = false;
	}
}

class PItem(K, T) {
private:
	PManager m_manager;
	K m_uid;
	T m_data;

public:
	this(PManager manager, K uid, T def = T.init) {
		int res;
		bool found = false;
		
		m_manager = manager;
		m_uid = uid;
		
		if (m_manager.m_connected == false) throw new Exception("Manager not open");
		
		res = sqlite3_bind_blob(
			m_manager.m_getStatement,
			1,
			&m_uid,
			K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_manager.m_getStatement);
			if (res == SQLITE_ROW) {
				found = true;
				T* ptr = cast(T*)sqlite3_column_blob(m_manager.m_getStatement, 0);
				m_data = *ptr;
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
		
		res = sqlite3_reset(m_manager.m_getStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_manager.m_getStatement);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
		
		if (!found) set(def);
	}
	
	T set(T value) {
		int res;
		
		res = sqlite3_bind_blob(
			m_manager.m_setStatement,
			1,
			&m_uid,
			m_uid.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		res = sqlite3_bind_blob(
			m_manager.m_setStatement,
			2,
			&value,
			value.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_manager.m_setStatement);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error writing persistence data");
		}
		
		res = sqlite3_reset(m_manager.m_setStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_manager.m_setStatement);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
		
		m_data = value;
		return m_data;
	}
	
	T get() {
		return m_data;
	}
}

class PItem(K : K[], T) {
private:
	PManager m_manager;
	K[] m_uid;
	T m_data;

public:
	this(PManager manager, K[] uid, T def = T.init) {
		int res;
		bool found = false;
		
		m_manager = manager;
		m_uid = uid.dup;
		
		if (m_manager.m_connected == false) throw new Exception("Manager not open");
		
		res = sqlite3_bind_blob(
			m_manager.m_getStatement,
			1,
			m_uid.ptr,
			m_uid.length * K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_manager.m_getStatement);
			if (res == SQLITE_ROW) {
				found = true;
				T* ptr = cast(T*)sqlite3_column_blob(m_manager.m_getStatement, 0);
				m_data = *ptr;
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
		
		res = sqlite3_reset(m_manager.m_getStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_manager.m_getStatement);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
		
		if (!found) set(def);
	}
	
	T set(T value) {
		int res;
		
		res = sqlite3_bind_blob(
			m_manager.m_setStatement,
			1,
			m_uid.ptr,
			m_uid.length * K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		res = sqlite3_bind_blob(
			m_manager.m_setStatement,
			2,
			&value,
			value.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_manager.m_setStatement);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error writing persistence data");
		}
		
		res = sqlite3_reset(m_manager.m_setStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_manager.m_setStatement);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
		
		m_data = value;
		return m_data;
	}
	
	T get() {
		return m_data;
	}
}

class PItem(K, T : T[]) {
private:
	PManager m_manager;
	K m_uid;
	T[] m_data;
	
	void saveOut(T[] value) {
		int res;
		
		res = sqlite3_bind_blob(
			m_manager.m_setStatement,
			1,
			&m_uid,
			K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		res = sqlite3_bind_blob(
			m_manager.m_setStatement,
			2,
			value.ptr,
			value.length * T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_manager.m_setStatement);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error writing persistence data");
		}
		
		res = sqlite3_reset(m_manager.m_setStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_manager.m_setStatement);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}

public:
	this(PManager manager, K uid, T[] def = []) {
		int res;
		bool found = false;
		
		m_manager = manager;
		m_uid = uid;
		
		if (m_manager.m_connected == false) throw new Exception("Manager not open");
		
		res = sqlite3_bind_blob(
			m_manager.m_getStatement,
			1,
			&m_uid,
			K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_manager.m_getStatement);
			if (res == SQLITE_ROW) {
				found = true;
				int count = sqlite3_column_bytes(m_manager.m_getStatement, 0) / T.sizeof;
				T* ptr = cast(T*)sqlite3_column_blob(m_manager.m_getStatement, 0);
				m_data = ptr[0 .. count].dup;
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
		
		res = sqlite3_reset(m_manager.m_getStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_manager.m_getStatement);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
		
		if (!found) set(def);
	}
			
	T[] get() {
		return m_data;
	}
	
	T[] set(T[] stuff) {
		saveOut(stuff);
		m_data = stuff.dup;
		return m_data;
	}
	
	T opIndex(size_t index) {
		return m_data[index];
	}
	
	void opIndexAssign(T v, size_t i) {
		scope T[] temp = m_data.dup;
		temp[i] = v;
		saveOut(temp);
		
		m_data[i] = v;
	}
	
	T[] opSlice(size_t i, size_t j) {		  // overloads a[i .. j]
		return m_data[i .. j];
	}

	void opSliceAssign(T v) {			  // overloads a[] = v
		scope T[] temp;
		temp.length = m_data.length;
		temp[] = v;
		saveOut(temp);
		
		m_data[] = v;
	}
	
	void opSliceAssign(T v, size_t i, size_t j) { // overloads a[i .. j] = v
		scope T[] temp = m_data.dup;
		temp[i .. j] = v;
		saveOut(temp);
		
		m_data[i .. j] = v;
	}
	
	T[] opCat(T[] stuff) {
		return (m_data ~ stuff);
	}
	
	void opCatAssign(T[] stuff) {
		T[] temp = m_data ~ stuff;
		saveOut(temp);
		
		m_data ~= stuff;
	}
}

class PItem(K : K[], T : T[]) {
private:
	PManager m_manager;
	K[] m_uid;
	T[] m_data;
	
	void saveOut(T[] value) {
		int res;
		
		res = sqlite3_bind_blob(
			m_manager.m_setStatement,
			1,
			m_uid.ptr,
			m_uid.length * K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		res = sqlite3_bind_blob(
			m_manager.m_setStatement,
			2,
			value.ptr,
			value.length * T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_manager.m_setStatement);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error writing persistence data");
		}
		
		res = sqlite3_reset(m_manager.m_setStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_manager.m_setStatement);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}

public:
	this(PManager manager, K[] uid, T[] def = []) {
		int res;
		bool found = false;
		
		m_manager = manager;
		m_uid = uid.dup;
		
		if (m_manager.m_connected == false) throw new Exception("Manager not open");
		
		res = sqlite3_bind_blob(
			m_manager.m_getStatement,
			1,
			m_uid.ptr,
			m_uid.length * K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_manager.m_getStatement);
			if (res == SQLITE_ROW) {
				found = true;
				int count = sqlite3_column_bytes(m_manager.m_getStatement, 0) / T.sizeof;
				T* ptr = cast(T*)sqlite3_column_blob(m_manager.m_getStatement, 0);
				m_data = ptr[0 .. count].dup;
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
		
		res = sqlite3_reset(m_manager.m_getStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_manager.m_getStatement);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
		
		if (!found) set(def);
	}
			
	T[] get() {
		return m_data;
	}
	
	T[] set(T[] stuff) {
		saveOut(stuff);
		m_data = stuff.dup;
		return m_data;
	}
	
	T opIndex(size_t index) {
		return m_data[index];
	}
	
	void opIndexAssign(T v, size_t i) {
		scope T[] temp = m_data.dup;
		temp[i] = v;
		saveOut(temp);
		
		m_data[i] = v;
	}
	
	T[] opSlice(size_t i, size_t j) {		  // overloads a[i .. j]
		return m_data[i .. j];
	}

	void opSliceAssign(T v) {			  // overloads a[] = v
		scope T[] temp;
		temp.length = m_data.length;
		temp[] = v;
		saveOut(temp);
		
		m_data[] = v;
	}
	
	void opSliceAssign(T v, size_t i, size_t j) { // overloads a[i .. j] = v
		scope T[] temp = m_data.dup;
		temp[i .. j] = v;
		saveOut(temp);
		
		m_data[i .. j] = v;
	}
	
	T[] opCat(T[] stuff) {
		return (m_data ~ stuff);
	}
	
	void opCatAssign(T[] stuff) {
		T[] temp = m_data ~ stuff;
		saveOut(temp);
		
		m_data ~= stuff;
	}
}

enum PHolderEnum {
	DEFAULT = 0,
	UNIQUE = 0x1,
	INDEXED = 0x2
}

abstract class PHolderBase : PBase {
protected:
	sqlite3_stmt*[2] m_getStatement = null;
	sqlite3_stmt* m_addStatement = null;
	sqlite3_stmt* m_remStatement = null;
	sqlite3_stmt* m_clearStatement = null;
	sqlite3_stmt*[2] m_delStatement;

public:
	void open(char[] folder, char[] table, PHolderEnum keySettings = PHolderEnum.UNIQUE | PHolderEnum.INDEXED, PHolderEnum valueSettings = PHolderEnum.DEFAULT) {
		scope(success) m_connected = true;
		int res;
		char[] path = folder ~ "/" ~ table ~ ".db\0";

		sqlite3_config(SQLITE_CONFIG_SINGLETHREAD);	// We'll handle locking ourselves
		
		res = sqlite3_open(path.ptr, &m_db);
		if (res != SQLITE_OK) throw new Exception("Couldn't open persistence database.");
		scope(failure) sqlite3_close(m_db);
		
		char[] query =	// Make sure our table exists
			"CREATE TABLE IF NOT EXISTS "
			~ table ~ " ("
				~ "key BLOB NOT NULL"
				~ ((keySettings & PHolderEnum.UNIQUE) == PHolderEnum.UNIQUE ? " UNIQUE ON CONFLICT REPLACE" : "")
				~ ", "
				~ "value BLOB NOT NULL"
				~ ((valueSettings & PHolderEnum.UNIQUE) == PHolderEnum.UNIQUE ? " UNIQUE ON CONFLICT REPLACE" : "")
			~ ")\0"
		;
		doCommand(query);
		
		if ((keySettings & PHolderEnum.INDEXED) == PHolderEnum.INDEXED) {
			query =	// Make sure it's indexed
				"CREATE INDEX IF NOT EXISTS "
				~ table ~ "_index ON " ~ table ~ " ("
					~ "key"
				~ ")\0"
			;
			doCommand(query);
		}
		if ((valueSettings & PHolderEnum.INDEXED) == PHolderEnum.INDEXED) {
			query =	// Make sure it's indexed
				"CREATE INDEX IF NOT EXISTS "
				~ table ~ "_index ON " ~ table ~ " ("
					~ "value"
				~ ")\0"
			;
			doCommand(query);
		}
		
		query =
			"SELECT value "
			~ "FROM " ~ table ~ " "
			~ "WHERE key=?\0"
		;
		prepare(&m_getStatement[0], query);
		scope (failure) sqlite3_finalize(m_getStatement[0]);
		
		query =
			"SELECT key "
			~ "FROM " ~ table ~ " "
			~ "WHERE value=?\0"
		;
		prepare(&m_getStatement[1], query);
		scope (failure) sqlite3_finalize(m_getStatement[1]);
		
		query =
			"INSERT INTO " ~ table ~ " "
			~ "(key, value)"
			~ "VALUES (?, ?)\0"
		;
		prepare(&m_addStatement, query);
		scope (failure) sqlite3_finalize(m_addStatement);
		
		query =
			"DELETE FROM " ~ table ~ " "
			~ "WHERE key=? "
			~ "AND value=?\0"
		;
		prepare(&m_remStatement, query);
		scope (failure) sqlite3_finalize(m_remStatement);
		
		query =
			"DELETE FROM " ~ table ~ " "
			~ "WHERE key=?\0"
		;
		prepare(&m_delStatement[0], query);
		scope (failure) sqlite3_finalize(m_delStatement[0]);
		
		query =
			"DELETE FROM " ~ table ~ " "
			~ "WHERE value=?\0"
		;
		prepare(&m_delStatement[1], query);
		scope (failure) sqlite3_finalize(m_delStatement[1]);
		
		query =
			"DELETE FROM " ~ table
		;
		prepare(&m_clearStatement, query);
	}
	
	void close() {
		if (m_connected) {
			sqlite3_finalize(m_clearStatement);
			sqlite3_finalize(m_delStatement[1]);
			sqlite3_finalize(m_delStatement[0]);
			sqlite3_finalize(m_addStatement);
			sqlite3_finalize(m_remStatement);
			sqlite3_finalize(m_getStatement[1]);
			sqlite3_finalize(m_getStatement[0]);
			sqlite3_close(m_db);
		}
		m_connected = false;
	}
	
	void clear() {
		int res;
		do {
			res = sqlite3_step(m_clearStatement);
		}
		while (res == SQLITE_BUSY);
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error executing query");
		}
		
		res = sqlite3_reset(m_clearStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
	}
}

class PHolder(K, T) : PHolderBase {
public:
	void add(K key, T item) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		
		res = sqlite3_bind_blob(
			m_addStatement,
			1,
			&key,
			K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		res = sqlite3_bind_blob(
			m_addStatement,
			2,
			&item,
			T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_addStatement);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error writing persistence data");
		}
		
		res = sqlite3_reset(m_addStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_addStatement);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}
	
	void remove(K key, T item) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		
		res = sqlite3_bind_blob(
			m_remStatement,
			1,
			&key,
			K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		res = sqlite3_bind_blob(
			m_remStatement,
			2,
			&item,
			T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_remStatement);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error removing persistence data");
		}
		
		res = sqlite3_reset(m_remStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_remStatement);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}
	
	void removeKey(K key) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		
		res = sqlite3_bind_blob(
			m_delStatement[0],
			1,
			&key,
			K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_delStatement[0]);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error removing persistence data");
		}
		
		res = sqlite3_reset(m_delStatement[0]);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_delStatement[0]);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}
	
	void removeValue(T item) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		
		res = sqlite3_bind_blob(
			m_delStatement[1],
			1,
			&item,
			T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_delStatement[1]);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error removing persistence data");
		}
		
		res = sqlite3_reset(m_delStatement[1]);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_delStatement[1]);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}
	
	T[] getValue(K key) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		T[] ret;
		
		res = sqlite3_bind_blob(
			m_getStatement[0],
			1,
			&key,
			K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_getStatement[0]);
			if (res == SQLITE_ROW) {
				T* ptr = cast(T*)sqlite3_column_blob(m_getStatement[0], 0);
				ret ~= *ptr;
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
		
		res = sqlite3_reset(m_getStatement[0]);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_getStatement[0]);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
		
		return ret;
	}
	
	K[] getKey(T value) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		K[] ret;
		
		res = sqlite3_bind_blob(
			m_getStatement[1],
			1,
			&value,
			T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_getStatement[1]);
			if (res == SQLITE_ROW) {
				K* ptr = cast(K*)sqlite3_column_blob(m_getStatement[1], 0);
				ret ~= *ptr;
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
		
		res = sqlite3_reset(m_getStatement[1]);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_getStatement[1]);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
		
		return ret;
	}
}

class PHolder(K : K[], T) : PHolderBase {
public:
	void add(K[] key, T item) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		
		res = sqlite3_bind_blob(
			m_addStatement,
			1,
			key.ptr,
			key.length * K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		res = sqlite3_bind_blob(
			m_addStatement,
			2,
			&item,
			T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_addStatement);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error writing persistence data");
		}
		
		res = sqlite3_reset(m_addStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_addStatement);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}
	
	void remove(K[] key, T item) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		
		res = sqlite3_bind_blob(
			m_remStatement,
			1,
			key.ptr,
			key.length * K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		res = sqlite3_bind_blob(
			m_remStatement,
			2,
			&item,
			T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_remStatement);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error removing persistence data");
		}
		
		res = sqlite3_reset(m_remStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_remStatement);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}
	
	void removeKey(K[] key) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		
		res = sqlite3_bind_blob(
			m_delStatement[0],
			1,
			key.ptr,
			key.length * K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_delStatement[0]);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error removing persistence data");
		}
		
		res = sqlite3_reset(m_delStatement[0]);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_delStatement[0]);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}
	
	void removeValue(T item) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		
		res = sqlite3_bind_blob(
			m_delStatement[1],
			1,
			&item,
			T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_delStatement[1]);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error removing persistence data");
		}
		
		res = sqlite3_reset(m_delStatement[1]);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_delStatement[1]);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}
	
	T[] getValue(K[] key) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		T[] ret;
		
		res = sqlite3_bind_blob(
			m_getStatement[0],
			1,
			key.ptr,
			key.length * K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_getStatement[0]);
			if (res == SQLITE_ROW) {
				T* ptr = cast(T*)sqlite3_column_blob(m_getStatement[0], 0);
				ret ~= *ptr;
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
		
		res = sqlite3_reset(m_getStatement[0]);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_getStatement[0]);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
		
		return ret;
	}
	
	K[][] getKey(T value) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		K[][] ret;
		
		res = sqlite3_bind_blob(
			m_getStatement[1],
			1,
			&value,
			T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_getStatement[1]);
			if (res == SQLITE_ROW) {
				int count = sqlite3_column_bytes(m_getStatement[1], 0) / K.sizeof;
				K* ptr = cast(K*)sqlite3_column_blob(m_getStatement[1], 0);
				ret ~= ptr[0 .. count].dup;
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
		
		res = sqlite3_reset(m_getStatement[1]);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_getStatement[1]);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
		
		return ret;
	}
}

class PHolder(K, T : T[]) : PBase {
public:
	void add(K key, T[] item) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		
		res = sqlite3_bind_blob(
			m_addStatement,
			1,
			&key,
			K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		res = sqlite3_bind_blob(
			m_addStatement,
			2,
			item.ptr,
			item.length * T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_addStatement);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error writing persistence data");
		}
		
		res = sqlite3_reset(m_addStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_addStatement);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}
	
	void remove(K key, T[] item) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		
		res = sqlite3_bind_blob(
			m_remStatement,
			1,
			&key,
			K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		res = sqlite3_bind_blob(
			m_remStatement,
			2,
			item.ptr,
			item.length * T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_remStatement);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error removing persistence data");
		}
		
		res = sqlite3_reset(m_remStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_remStatement);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}
	
	void removeKey(K key) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		
		res = sqlite3_bind_blob(
			m_delStatement[0],
			1,
			&key,
			K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_delStatement[0]);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error removing persistence data");
		}
		
		res = sqlite3_reset(m_delStatement[0]);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_delStatement[0]);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}
	
	void removeValue(T[] item) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		
		res = sqlite3_bind_blob(
			m_delStatement[1],
			1,
			item.ptr,
			item.length * T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_delStatement[1]);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error removing persistence data");
		}
		
		res = sqlite3_reset(m_delStatement[1]);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_delStatement[1]);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}
	
	T[][] getValue(K key) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		T[][] ret;
		
		res = sqlite3_bind_blob(
			m_getStatement[0],
			1,
			&key,
			K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_getStatement[0]);
			if (res == SQLITE_ROW) {
				int count = sqlite3_column_bytes(m_getStatement[0], 0) / T.sizeof;
				T* ptr = cast(T*)sqlite3_column_blob(m_getStatement[0], 0);
				ret ~= ptr[0 .. count].dup;
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
		
		res = sqlite3_reset(m_getStatement[0]);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_getStatement[0]);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
		
		return ret;
	}
	
	K[] getKey(T[] value) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		K[] ret;
		
		res = sqlite3_bind_blob(
			m_getStatement[1],
			1,
			value.ptr,
			value.length * T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_getStatement[1]);
			if (res == SQLITE_ROW) {
				K* ptr = cast(K*)sqlite3_column_blob(m_getStatement[1], 0);
				ret ~= *ptr;
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
		
		res = sqlite3_reset(m_getStatement[1]);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_getStatement[1]);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
		
		return ret;
	}
}

class PHolder(K : K[], T : T[]) : PHolderBase {
public:
	void add(K[] key, T[] item) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		
		res = sqlite3_bind_blob(
			m_addStatement,
			1,
			key.ptr,
			key.length * K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		res = sqlite3_bind_blob(
			m_addStatement,
			2,
			item.ptr,
			item.length * T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_addStatement);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error writing persistence data");
		}
		
		res = sqlite3_reset(m_addStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_addStatement);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}
	
	void remove(K[] key, T[] item) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		
		res = sqlite3_bind_blob(
			m_remStatement,
			1,
			key.ptr,
			key.length * K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		res = sqlite3_bind_blob(
			m_remStatement,
			2,
			item.ptr,
			item.length * T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_remStatement);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error removing persistence data");
		}
		
		res = sqlite3_reset(m_remStatement);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_remStatement);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}
	
	void removeKey(K[] key) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		
		res = sqlite3_bind_blob(
			m_delStatement[0],
			1,
			key.ptr,
			key.length * K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_delStatement[0]);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error removing persistence data");
		}
		
		res = sqlite3_reset(m_delStatement[0]);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_delStatement[0]);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}
	
	void removeValue(T[] item) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		
		res = sqlite3_bind_blob(
			m_delStatement[1],
			1,
			item.ptr,
			item.length * T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_delStatement[1]);
		}
		while (res == SQLITE_BUSY);
		
		if (
			res != SQLITE_DONE
			&& res != SQLITE_OK
		) {
			throw new Exception("Error removing persistence data");
		}
		
		res = sqlite3_reset(m_delStatement[1]);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_delStatement[1]);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
	}
	
	T[][] getValue(K[] key) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		T[][] ret;
		
		res = sqlite3_bind_blob(
			m_getStatement[0],
			1,
			key.ptr,
			key.length * K.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_getStatement[0]);
			if (res == SQLITE_ROW) {
				int count = sqlite3_column_bytes(m_getStatement[0], 0) / T.sizeof;
				T* ptr = cast(T*)sqlite3_column_blob(m_getStatement[0], 0);
				ret ~= ptr[0 .. count].dup;
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
		
		res = sqlite3_reset(m_getStatement[0]);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_getStatement[0]);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
		
		return ret;
	}
	
	K[][] getKey(T[] value) {
		if (!m_connected) throw new Exception("Connection not open");
		int res;
		K[][] ret;
		
		res = sqlite3_bind_blob(
			m_getStatement[1],
			1,
			value.ptr,
			value.length * T.sizeof,
			null
		);
		if (res != SQLITE_OK) throw new Exception("Error binding to statement");
		
		do {
			res = sqlite3_step(m_getStatement[1]);
			if (res == SQLITE_ROW) {
				int count = sqlite3_column_bytes(m_getStatement[1], 0) / K.sizeof;
				K* ptr = cast(K*)sqlite3_column_blob(m_getStatement[1], 0);
				ret ~= ptr[0 .. count].dup;
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
		
		res = sqlite3_reset(m_getStatement[1]);
		if (res != SQLITE_OK) throw new Exception("Could not reset prepared statement");
		
		res = sqlite3_clear_bindings(m_getStatement[1]);
		if (res != SQLITE_OK) throw new Exception("Could not clear bindings");
		
		return ret;
	}
}
