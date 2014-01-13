module aahz.net.NetPacket;

import aahz.net.Net;
import dcrypt.crypto.ciphers.AES;
import tango.io.Stdout;

package:
const ubyte NET_VERSION = 0x00;
version (LittleEndian) {
	const uint AAHZ_MAGIC = 0x5A_6E_AA_42;
}
else version (BigEndian) {
	const uint AAHZ_MAGIC = 0x42_AA_6E_5A;
}
else {
	static assert(0);
}

const uint PACKETS_PER_MULTI_MAX = 5;
const uint PACKET_MAX = 512;
const uint PACKET_HEADER_SIZE = 16;
const uint PACKET_ENCRYPTION_BLOCK = 16;
const uint PACKET_SINGLE_MAX = PACKET_MAX - PACKET_HEADER_SIZE;
const uint PACKET_MULTI_MAX = (PACKET_MAX * PACKETS_PER_MULTI_MAX) - (PACKET_HEADER_SIZE * PACKETS_PER_MULTI_MAX);

enum PacketMax : uint {
	SINGLE = PACKET_SINGLE_MAX,
	MULTI = PACKET_MULTI_MAX
}

enum NetCommand : ubyte {	// Values should not change, for purposes of backwards compatibility. Add new types at the end, always
	S2S = 0x80,	// server-to-server command
	P2S = 0x00,	// peer-to-server or server-to-peer (can always be inferred by whether we're looking at the incoming or outgoing data queue)
	DESTINATION_MASK = S2S | P2S,
	
	NORMAL = 0x00,
	QUERY = 0x40,
	REPLY = 0x20,
	INTERNAL = 0x60,	// Packets to be handled in the lower level of networking -- Always unreliable
	TYPE_MASK = NORMAL | QUERY | REPLY | INTERNAL,
	
	PACKET_STATUS			= 0x00 | INTERNAL,	// uint reliableBase, uint sequentialBase, uint fragmentBase, ubyte[] reliableBits, ubyte[] sequentialBits, ubyte[] fragmentBits

	S2S_SERVER_CONNECT		= 0x00 | S2S | NORMAL,
	S2S_SERVER_CREATED		= 0x01 | S2S | NORMAL,
	S2S_SERVER_DISCONNECT	= 0x02 | S2S | NORMAL,
	S2S_CHANNEL_LIST		= 0x03 | S2S | NORMAL,	// char[][] channelNames
	S2S_USER_LOGIN			= 0x04 | S2S | NORMAL,	// char[] username
	S2S_USER_LOGOUT			= 0x05 | S2S | NORMAL,	// char[] username
	S2S_CHANNEL_CREATED		= 0x06 | S2S | NORMAL,	// char[] channelName
	S2S_CHANNEL_DROPPED		= 0x07 | S2S | NORMAL,	// char[] channelName
	
	P2S_SERVER_STATUS		= 0x00 | P2S | NORMAL,	// int connectionCount	// Only has an argument as a response from the server
	P2S_CLIENT_DISCONNECT	= 0x03 | P2S | NORMAL,
	P2S_MESSAGE_CHANNEL		= 0x06 | P2S | NORMAL,	// char[] channelName<, channel specific...>
	P2S_CHANNEL_DROPPED		= 0x07 | P2S | NORMAL,	// char[] channelName
	
	P2S_R_EXCEPTION			= 0x00 | P2S | REPLY,	// uint exceptionCode
	P2S_Q_CONNECT			= 0x01 | P2S | QUERY,	// ubyte[] encryptionKey
	P2S_R_CONNECT			= 0x01 | P2S | REPLY,
	P2S_Q_LOGIN				= 0x02 | P2S | QUERY,	// char[] username, char[] password
	P2S_R_LOGIN				= 0x02 | P2S | REPLY,
	P2S_Q_CHANNEL_LOCATION	= 0x04 | P2S | QUERY,	// char[] channelName
	P2S_R_CHANNEL_LOCATION	= 0x04 | P2S | REPLY,	// bool exists<, uint serverID>
	P2S_Q_JOIN_CHANNEL		= 0x05 | P2S | QUERY,	// char[] channelType, char[] channelName, char[] password
	P2S_R_JOIN_CHANNEL		= 0x05 | P2S | REPLY
}

const SendType[ubyte.max] DEFAULT_SEND_TYPE = [];
static this() {
	DEFAULT_SEND_TYPE[NetCommand.PACKET_STATUS]				= SendType.UNRELIABLE;
	
	DEFAULT_SEND_TYPE[NetCommand.S2S_SERVER_CONNECT]		= SendType.UNRELIABLE;
	DEFAULT_SEND_TYPE[NetCommand.S2S_SERVER_DISCONNECT]		= SendType.UNRELIABLE;
	DEFAULT_SEND_TYPE[NetCommand.S2S_CHANNEL_LIST]			= SendType.SEQUENTIAL;
	DEFAULT_SEND_TYPE[NetCommand.S2S_USER_LOGIN]			= SendType.SEQUENTIAL;
	DEFAULT_SEND_TYPE[NetCommand.S2S_USER_LOGOUT]			= SendType.SEQUENTIAL;
	DEFAULT_SEND_TYPE[NetCommand.S2S_CHANNEL_CREATED]		= SendType.SEQUENTIAL;
	DEFAULT_SEND_TYPE[NetCommand.S2S_CHANNEL_DROPPED]		= SendType.SEQUENTIAL;

	DEFAULT_SEND_TYPE[NetCommand.P2S_SERVER_STATUS]			= SendType.UNRELIABLE;
	DEFAULT_SEND_TYPE[NetCommand.P2S_CLIENT_DISCONNECT]		= SendType.UNRELIABLE;
	DEFAULT_SEND_TYPE[NetCommand.P2S_MESSAGE_CHANNEL]		= SendType.RELIABLE;
	DEFAULT_SEND_TYPE[NetCommand.P2S_CHANNEL_DROPPED]		= SendType.RELIABLE;

	DEFAULT_SEND_TYPE[NetCommand.P2S_Q_CONNECT]				= SendType.UNRELIABLE;
	DEFAULT_SEND_TYPE[NetCommand.P2S_R_CONNECT]				= SendType.UNRELIABLE;
	DEFAULT_SEND_TYPE[NetCommand.P2S_Q_LOGIN]				= SendType.RELIABLE;
	DEFAULT_SEND_TYPE[NetCommand.P2S_R_LOGIN]				= SendType.RELIABLE;
	DEFAULT_SEND_TYPE[NetCommand.P2S_Q_CHANNEL_LOCATION]	= SendType.RELIABLE;
	DEFAULT_SEND_TYPE[NetCommand.P2S_R_CHANNEL_LOCATION]	= SendType.RELIABLE;
	DEFAULT_SEND_TYPE[NetCommand.P2S_Q_JOIN_CHANNEL]		= SendType.RELIABLE;
	DEFAULT_SEND_TYPE[NetCommand.P2S_R_JOIN_CHANNEL]		= SendType.RELIABLE;
}

public:
enum SendType : ubyte {
	RELIABLE,	// The default default
	UNRELIABLE,
	SEQUENTIAL,
	DEFAULT
}

private:
template PacketBase(PacketMax pM) {
package:
	ubyte* m_ptr;
	size_t packetSize;	// Amount of data in NetPacket.packetData
	bool resend = false;
	union {	// Entire packet
		struct {
			union {
				struct {
					uint magic = AAHZ_MAGIC;
					ubyte nVersion = NET_VERSION;
					NetCommand command;
					SendType sendType;
					bool encrypted;
					uint packetID;
					union {
						struct {
							ushort fragment;
							ushort fragmentCount;
						}
						uint fragmentAll;
						uint queryID;
					}
				}
				ubyte[
					uint.sizeof
					+ ubyte.sizeof
					+ NetCommand.sizeof
					+ SendType.sizeof
					+ bool.sizeof
					+ uint.sizeof
					+ uint.sizeof
				] headerData;
			}
			ubyte[pM] userData;	// Always leave the last byte empty unless encrypting. When we encrypt data, it pads the output out to be a multiple of 16 bytes. But, if the input data is (for example) 16 bytes, the output is 32. It adds a full 16 bytes. By making sure that the last 16 byte chunk of the packet only has 15 bytes which can be written, we don't overflow the buffer
		}
		ubyte[headerData.sizeof + pM] packetData;
	}
	
public:
	size_t maxData() {
		return cast(size_t)(pM - 1);
	}

	void clear() {
		packetSize = headerData.sizeof;
		m_ptr = &userData[0];
	}

	void unwind() {
		m_ptr = &userData[0];
	}
	
	size_t position() {
		return (m_ptr - &userData[0]);
	}
}

template PacketRW(T) {
public:
	static size_t measure(T a) {
		return T.sizeof;
	}
	
	static size_t measure(T[] a) {
		return (ushort.sizeof + (a.length * T.sizeof));
	}
	
	static size_t measure(T[][] a) {
		size_t ret = ushort.sizeof;
		foreach (i; a) {
			ret += ushort.sizeof + (i.length * T.sizeof);
		}
		return ret;
	}
	
	void write(T a) {
		ubyte* max = &userData[0] + userData.sizeof - 1;
		if ((m_ptr + T.sizeof) > max) throw new Exception("Buffer overrun");
		
		efix!(T)(a);
		
		ubyte* ptr = cast(ubyte*)&a;
		m_ptr[0 .. T.sizeof] = ptr[0 .. T.sizeof];
		m_ptr += T.sizeof;
		
		packetSize = m_ptr - &packetData[0];
	}
	
	void write(T[] a) {
		ubyte* max = &userData[0] + userData.sizeof - 1;
		ushort len = a.length * T.sizeof;
		if ((m_ptr + len + ushort.sizeof) > max) throw new Exception("Buffer overrun");
		
		ushort outLen = len;	// Make copy to convert to the right endianess
		efix!(ushort)( outLen );
		ubyte* ptr = cast(ubyte*)&outLen;
		m_ptr[0 .. ushort.sizeof] = ptr[0 .. ushort.sizeof];
		m_ptr += ushort.sizeof;
		
		ptr = cast(ubyte*)a.ptr;
		m_ptr[0 .. len] = ptr[0 .. len];
		void[] slice = m_ptr[0 .. len];
		efix!(T)( slice );
		m_ptr += len;
		
		packetSize = m_ptr - &packetData[0];
	}
	
	void write(T[][] a) {
		ubyte* max = &userData[0] + userData.sizeof - 1;
		ushort arrCount = a.length;
		if ((m_ptr + ushort.sizeof) > max) throw new Exception("Buffer overrun");
		
		efix!(ushort)(arrCount);
		ubyte* ptr = cast(ubyte*)&arrCount;
		m_ptr[0 .. ushort.sizeof] = ptr[0 .. ushort.sizeof];
		m_ptr += ushort.sizeof;
		
		foreach (i; a) {
			ushort len = i.length * T.sizeof;
			if ((m_ptr + len + ushort.sizeof) > max) throw new Exception("Buffer overrun");
			
			ushort outLen = len;	// Make copy to convert to the right endianess
			efix!(ushort)( outLen );
			ptr = cast(ubyte*)&outLen;
			m_ptr[0 .. ushort.sizeof] = ptr[0 .. ushort.sizeof];
			m_ptr += ushort.sizeof;
			
			ptr = cast(ubyte*)i.ptr;
			m_ptr[0 .. len] = ptr[0 .. len];
			void[] slice = m_ptr[0 .. len];
			efix!(T)( slice );
			m_ptr += len;
		}
		packetSize = m_ptr - &packetData[0];
	}
	
	void read(out T a) {
		ubyte* max = &userData[0] + packetSize - headerData.length;
		if ((m_ptr + T.sizeof) > max) throw new Exception("Buffer overrun");
		
		ubyte* ptr = cast(ubyte*)&a;
		ptr[0 .. T.sizeof] = m_ptr[0 .. T.sizeof];
		efix!(T)(a);
		m_ptr += T.sizeof;
	}
	
	void read(out T[] a) {
		ubyte* max = &userData[0] + packetSize - headerData.length;
		if ((m_ptr + ushort.sizeof) > max) throw new Exception("Buffer overrun");
		
		ushort len;
		ubyte* ptr = cast(ubyte*)&len;
		ptr[0 .. ushort.sizeof] = m_ptr[0 .. ushort.sizeof];
		efix!(ushort)(len);
		m_ptr += ushort.sizeof;
		if ((m_ptr + len) > max) throw new Exception("Buffer overrun");
		
		a.length = (len / T.sizeof);
		ptr = cast(ubyte*)a.ptr;
		ptr[0 .. len] = m_ptr[0 .. len];
		void[] slice = a;
		efix!(T)( slice );
		m_ptr += len;
	}
	
	void read(out T[][] a) {
		ubyte* max = &userData[0] + packetSize - headerData.length;
		if ((m_ptr + ushort.sizeof) > max) throw new Exception("Buffer overrun");
		
		ushort arrCount;
		ubyte* ptr = cast(ubyte*)&arrCount;
		ptr[0 .. T.sizeof] = m_ptr[0 .. T.sizeof];
		efix!(ushort)(arrCount);
		m_ptr += ushort.sizeof;
		
		a.length = arrCount;
		for (ushort L = 0; L < arrCount; L++) {
			if ((m_ptr + ushort.sizeof) > max) throw new Exception("Buffer overrun");
		
			ushort len;
			ptr = cast(ubyte*)&len;
			ptr[0 .. ushort.sizeof] = m_ptr[0 .. ushort.sizeof];
			efix!(ushort)(len);
			m_ptr += ushort.sizeof;
			if ((m_ptr + len) > max) throw new Exception("Buffer overrun");
			
			a[L].length = (len / T.sizeof);
			ptr = cast(ubyte*)a[L].ptr;
			ptr[0 .. len] = m_ptr[0 .. len];
			void[] slice = a[L];
			efix!(T)( slice );
			m_ptr += len;
		}
	}
}

public:
struct NetPacket {	// Pre-fragmentation version of a packet
	mixin PacketBase!(PacketMax.SINGLE);

public:
	mixin PacketRW!(bool) BOOL;
	mixin PacketRW!(byte) BYTE;
	mixin PacketRW!(ubyte) UBYTE;
	mixin PacketRW!(short) SHORT;
	mixin PacketRW!(ushort) USHORT;
	mixin PacketRW!(int) INT;
	mixin PacketRW!(uint) UINT;
	mixin PacketRW!(long) LONG;
	mixin PacketRW!(ulong) ULONG;
	mixin PacketRW!(float) FLOAT;
	mixin PacketRW!(double) DOUBLE;
	mixin PacketRW!(char) CHAR;
	
	alias BOOL.measure measure;
	alias BYTE.measure measure;
	alias UBYTE.measure measure;
	alias SHORT.measure measure;
	alias USHORT.measure measure;
	alias INT.measure measure;
	alias UINT.measure measure;
	alias LONG.measure measure;
	alias ULONG.measure measure;
	alias FLOAT.measure measure;
	alias DOUBLE.measure measure;
	alias CHAR.measure measure;
	
	alias BOOL.write write;
	alias BYTE.write write;
	alias UBYTE.write write;
	alias SHORT.write write;
	alias USHORT.write write;
	alias INT.write write;
	alias UINT.write write;
	alias LONG.write write;
	alias ULONG.write write;
	alias FLOAT.write write;
	alias DOUBLE.write write;
	alias CHAR.write write;
	
	alias BOOL.read read;
	alias BYTE.read read;
	alias UBYTE.read read;
	alias SHORT.read read;
	alias USHORT.read read;
	alias INT.read read;
	alias UINT.read read;
	alias LONG.read read;
	alias ULONG.read read;
	alias FLOAT.read read;
	alias DOUBLE.read read;
	alias CHAR.read read;
}

struct NetPacketX {	// Pre-fragmentation version of a packet
	mixin PacketBase!(PacketMax.MULTI);

public:
	NetPacket opCast() {
		if ((packetSize - headerData.sizeof) > PacketMax.SINGLE) throw new Exception("Buffer exceeded");
		
		NetPacket ret;
		ret.packetSize = packetSize;
		ret.packetData[0 .. packetSize] = packetData[0 .. packetSize];
		
		return ret;
	}
	
	mixin PacketRW!(bool) BOOL;
	mixin PacketRW!(byte) BYTE;
	mixin PacketRW!(ubyte) UBYTE;
	mixin PacketRW!(short) SHORT;
	mixin PacketRW!(ushort) USHORT;
	mixin PacketRW!(int) INT;
	mixin PacketRW!(uint) UINT;
	mixin PacketRW!(long) LONG;
	mixin PacketRW!(ulong) ULONG;
	mixin PacketRW!(float) FLOAT;
	mixin PacketRW!(double) DOUBLE;
	mixin PacketRW!(char) CHAR;
	
	alias BOOL.measure measure;
	alias BYTE.measure measure;
	alias UBYTE.measure measure;
	alias SHORT.measure measure;
	alias USHORT.measure measure;
	alias INT.measure measure;
	alias UINT.measure measure;
	alias LONG.measure measure;
	alias ULONG.measure measure;
	alias FLOAT.measure measure;
	alias DOUBLE.measure measure;
	alias CHAR.measure measure;
	
	alias BOOL.write write;
	alias BYTE.write write;
	alias UBYTE.write write;
	alias SHORT.write write;
	alias USHORT.write write;
	alias INT.write write;
	alias UINT.write write;
	alias LONG.write write;
	alias ULONG.write write;
	alias FLOAT.write write;
	alias DOUBLE.write write;
	alias CHAR.write write;
	
	alias BOOL.read read;
	alias BYTE.read read;
	alias UBYTE.read read;
	alias SHORT.read read;
	alias USHORT.read read;
	alias INT.read read;
	alias UINT.read read;
	alias LONG.read read;
	alias ULONG.read read;
	alias FLOAT.read read;
	alias DOUBLE.read read;
	alias CHAR.read read;
}
