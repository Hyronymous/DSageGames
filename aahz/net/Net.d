module aahz.net.Net;

import tango.core.ByteSwap;
import tango.core.BitManip;
import tango.core.Exception;
import tango.core.sync.Mutex;
import tango.stdc.string;

import aahz.net.NetPacket;
import aahz.net.NetSocket;

import dcrypt.crypto.prngs.PBKDF2;
import dcrypt.crypto.params.ParametersWithIV;
import dcrypt.crypto.params.SymmetricKey;

/**********\
** PUBLIC **
\**********/
public:

const uint USERNAME_MAX = 30;	// Max length of a username
const uint PASSWORD_MAX = 30;	// Max length of a password
const uint CHANNEL_NAME_MAX = 30;

version (LittleEndian) {
	void efix(T)(inout T a) {}	// Do nothing
	void efix(T)(inout void[] a) {}
}
else version (BigEndian) {
	void efix(T)(inout T a) {
		static if (T.sizeof == 2) {
			a = ((a >> 8) | (a << 8));
		}
		else static if (T.sizeof == 4) {
			a = bswap(a);
		}
		else static if (T.sizeof == 8) {
			ByteSwap.swap64(cast(void*)&a, 8);
		}
		else static if (T.sizeof == 10) {
			ByteSwap.swap80(cast(void*)&a, 10);
		}
	}
	
	void efix(T)(inout void[] a) {
		static if (T.sizeof == 2) {
			ByteSwap.swap16( cast(void*)a.ptr, 2 * a.length );
		}
		else static if (T.sizeof == 4) {
			ByteSwap.swap32( cast(void*)a.ptr, 4 * a.length );
		}
		else static if (T.sizeof == 8) {
			ByteSwap.swap64( cast(void*)a.ptr, 8 * a.length );
		}
		else static if (T.sizeof == 10) {
			ByteSwap.swap80( cast(void*)a.ptr, 10 * a.length );
		}
	}
}

/***********\
** PACKAGE **
\***********/
package:	// Try to keep everything high level. Users shouldn't need to use any of this.
class ConnectionData : Mutex {
private:
	template BitHandler(alias base, alias bits) {
		void shift(int amount) {
			if (amount == -1) {
				base += (16 * 8);
				bits[] = 0;
			}
			else {
				int div = amount >> 3;	// amount / 8
				int mod = amount & 0x7;	// amount % 8
				int minMod = 8 - mod;
				
				int from = div;
				for (int to = 0; to < 16; to++) {
					if (from < 15) {
						bits[ to ] = (bits[ from ] >> mod) | ( bits[ from + 1 ] << minMod);
					}
					else if (from > 15) {
						bits[ to ] = 0;
					}
					else {	// == 15
						bits[ to ] = (bits[ from ] >> mod);
					}
					
					++from;
				}
				base += amount;
			}
		}
		
		void set(int pos) {
			int div = pos >> 3;
			int mod = pos & 0x7;
			
			bits[div] |= 0x1 << mod;
		}
		
		bool test(int pos) {
			int div = pos >> 3;
			int mod = pos & 0x7;
			
			return ((bits[div] & (0x1 << mod)) != 0);
		}
	}

public:
	bool isServer = false;
	
	NetAddress address;

	long lastSeen;
	bool connected = true;	// Unset when connection times out 
	bool loggedIn = false;	// Set once handshake is completed
	uint sequentialProcessed;
	
	uint reliableID;	// Have a different counter for output per connection
	uint sequentialID;
	uint fragmentID;
	
	uint reliableBase;
	uint sequentialBase;
	uint fragmentBase;
	
	ubyte[16] reliableBits;
	ubyte[16] sequentialBits;
	ubyte[128] fragmentBits;
		
	mixin BitHandler!(reliableBase, reliableBits) RELIABLE;
	mixin BitHandler!(sequentialBase, sequentialBits) SEQUENTIAL;
	
	alias RELIABLE.shift shiftReliable;
	alias RELIABLE.set setReliable;
	alias RELIABLE.test testReliable;
	
	alias SEQUENTIAL.shift shiftSequential;
	alias SEQUENTIAL.set setSequential;
	alias SEQUENTIAL.test testSequential;
	
	this(inout NetAddress na) {
		address = na;
	}
	
	void shiftFragment(int amount) {
		memmove(&fragmentBits[0], &fragmentBits[amount], fragmentBits.length - amount);
		fragmentBits[($ - amount)..$] = 0;
		fragmentBase += amount;
	}
	
	void setFragment(uint pos, uint fragmentCount, uint fragment) {
		if (fragmentBits[pos] == 0) fragmentBits[pos] |= fragmentCount << 5;
		fragmentBits[pos] |= 1 << fragment;
	}
	
	bool testFragment(uint pos, uint fragment) {
		return ((fragmentBits[pos] & (1 << fragment)) != 0);
	}
	
	static int firstEmpty(ubyte[16] bitmask) {
		static const ubyte[] lookup = [
			0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 4,
			0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 5,
			0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 4,
			0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 6,
			0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 4,
			0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 5,
			0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 4,
			0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 7,
			0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 4,
			0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 5,
			0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 4,
			0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 6,
			0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 4,
			0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 5,
			0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 4,
			0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0, 8
		];
		
		for (int L = 0; L < 16; L++) {
			if ( lookup[ bitmask[L] ] != 8 ) {
				return ((L << 3) + lookup[ bitmask[L] ]);
			}
		}
		return -1;
	}
	
	static int bitCount5(ubyte bitmask) {	// counts only the lowest 5 bits
		static const ubyte[] lookup = [
			0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
			1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
			0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
			1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
			0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
			1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
			0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
			1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
			0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
			1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
			0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
			1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
			0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
			1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5,
			0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
			1, 2, 2, 3, 2, 3, 3, 4, 2, 3, 3, 4, 3, 4, 4, 5
		];
		return cast(int)lookup[bitmask];
	}
}

class ClientData : ConnectionData {
public:
	char[] username;
	ParametersWithIV params;
	
	this(inout NetAddress na, ubyte[] encryptionKey) {
		super(na);
		isServer = false;
		
		ubyte[] iv = new ubyte[ PACKET_ENCRYPTION_BLOCK ];
		PBKDF2 prng = new PBKDF2(cast(char[])encryptionKey, "fnord", 3);
		prng.read(iv);
		
		params = new ParametersWithIV(new SymmetricKey(encryptionKey), iv);
	}
}

class ClientDisconnect : Exception {
	this( char[] msg ) {
		super( msg );
	}
}

class ConnectionLost : Exception {
	this( char[] msg ) {
		super( msg );
	}
}

class OperationCancelled : Exception {
	this( char[] msg ) {
		super( msg );
	}
}

class AuthorizationFail : Exception {
	this(char[] msg) {
		super(msg);
	}
}

class TimedOut : Exception {
	this( char[] msg ) {
		super( msg );
	}
}

class ChannelDropped : Exception {
	this( char[] msg ) {
		super( msg );
	}
}

class BadPacket : Exception {
	this( char[] msg ) {
		super( msg );
	}
}

class TimingOut : Exception {
	this( char[] msg ) {
		super( msg );
	}
}

class WrongServer : Exception {
	this( char[] msg ) {
		super( msg );
	}
}

class NoSuchServer : Exception {
	this( char[] msg ) {
		super( msg );
	}
}

enum NetException : uint {
	BAD_PACKET,
	WRONG_SERVER,
	AUTHORIZATION_FAIL
}

void toException(uint exceptionCode) {
	switch (exceptionCode) {
	case NetException.BAD_PACKET:
		throw new BadPacket("Bad packet");
	break;
	case NetException.WRONG_SERVER:
		throw new WrongServer("Wrong server");
	break;
	case NetException.AUTHORIZATION_FAIL:
		throw new AuthorizationFail("Authorization failed");
	break;
	default:
		throw new Exception("Unknown exception");
	break;
	}
}
