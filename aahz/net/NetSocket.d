module aahz.net.NetSocket;

import tango.core.Exception;
import tango.sys.win32.Macros;
import tango.sys.win32.consts.socket;
import tango.sys.win32.Types;
import tango.io.Stdout;
import tango.math.random.Random;

private typedef int socket_t = ~0;
private const int IOCPARM_MASK =  0x7f;
private const int IOC_IN =        cast(int)0x80000000;
private const int FIONBIO =       cast(int) (IOC_IN | ((int.sizeof & IOCPARM_MASK) << 16) | (102 << 8) | 126);
private const int FD_SETSIZE = 64;

private const int WSADESCRIPTION_LEN = 256;
private const int WSASYS_STATUS_LEN = 128;

private const int WSAEINTR = 10004;
private const int WSAEACCES = 10013;
private const int WSAEFAULT = 10014;
private const int WSAEINVAL = 10022;
private const int WSAEWOULDBLOCK = 10035;
private const int WSAEINPROGRESS = 10036;
private const int WSAENOTSOCK = 10038;
private const int WSAEDESTADDRREQ = 10039;
private const int WSAEMSGSIZE = 10040;
private const int WSAEOPNOTSUPP = 10045;
private const int WSAEAFNOSUPPORT = 10047;
private const int WSAEADDRNOTAVAIL = 10049;
private const int WSAENETDOWN = 10050;
private const int WSAENETUNREACH = 10051;
private const int WSAENETRESET = 10052;
private const int WSAECONNABORTED = 10053;
private const int WSAECONNRESET = 10054;
private const int WSAENOBUFS = 10055;
private const int WSAEISCONN = 10056;
private const int WSAENOTCONN = 10057;
private const int WSAESHUTDOWN = 10058;
private const int WSAETIMEDOUT = 10060;
private const int WSAEHOSTUNREACH = 10065;
private const int WSANOTINITIALISED = 10093;

struct WSADATA {
	WORD wVersion;
	WORD wHighVersion;
	char szDescription[WSADESCRIPTION_LEN+1];
	char szSystemStatus[WSASYS_STATUS_LEN+1];
	ushort iMaxSockets;
	ushort iMaxUdpDg;
	char* lpVendorInfo;
}

struct sockaddr {
        ushort sa_family;
        char[14] sa_data = 0;
}

struct NetAddress {
	version ( freebsd ) {
		ubyte sin_len;
		ubyte sin_family = AF_INET;
	}
	else {
		ushort sin_family = AF_INET;
	}
	ushort sin_port;
	uint sin_addr; //in_addr
	char[8] sin_zero = 0;
	
	void set(char[] addr, int port) {
		char[] local_ip = addr ~ "\0";
		sin_addr = inet_addr( local_ip.ptr );
		sin_port = port;
	}
	
	void set(ulong uid) {
		sin_addr = cast(uint)(uid & 0xffffffffUL);
		sin_port = cast(ushort)((uid & 0xffff_00000000UL) >> 32);
	}
	
	ulong toUID() {
		ulong ret = cast(ulong)sin_addr;
		ret |= (cast(ulong)sin_port) << 32;
		
		return ret;
	}

    hash_t toHash() {
		return cast(hash_t)sin_addr;
	}

    int opEquals(NetAddress nA) {
		return
			nA.sin_addr == sin_addr
			&& nA.sin_port == sin_port
		;
    }

    int opCmp(NetAddress nA) {
		if (sin_addr == nA.sin_addr) return sin_port - nA.sin_port;
		return sin_addr - nA.sin_addr;
    }
}

struct fd_set {
	uint fd_count = 0;
	int[FD_SETSIZE] fd_array;   /* an array of SOCKETs */
	
	void zero() {
		fd_count = 0;
	}

	bool isSet(int fd) {
		for (uint L = 0; L < fd_count; L++) {
			if (fd == fd_array[L]) return true;
		}
		return false;
	}

	void set(int fd) {
		if (fd_count < FD_SETSIZE) {
			fd_array[fd_count] = fd;
			++fd_count;
		}
	}
}

struct timeval {
	int tv_sec; //seconds
	int tv_usec; //microseconds
}

struct hostent
{
	char* h_name;
	char** h_aliases;
	version(Win32)
	{
		short h_addrtype;
		short h_length;
	}
		else version(BsdSockets)
	{
		int h_addrtype;
		int h_length;
	}
	char** h_addr_list;


	char* h_addr()
	{
		return h_addr_list[0];
	}
}

extern  (Windows) {
	alias closesocket close;
	int WSAStartup(WORD wVersionRequested, WSADATA* lpWSAData);
	int WSACleanup();
	socket_t socket(int af, int type, int protocol);
	int ioctlsocket(socket_t s, int cmd, uint* argp);
	uint inet_addr(char* cp);
	int bind(socket_t s, sockaddr* name, int namelen);
	int connect(socket_t s, sockaddr* name, int namelen);
	int listen(socket_t s, int backlog);
	socket_t accept(socket_t s, sockaddr* addr, int* addrlen);
	int closesocket(socket_t s);
	int shutdown(socket_t s, int how);
	int getpeername(socket_t s, sockaddr* name, int* namelen);
	int getsockname(socket_t s, sockaddr* name, int* namelen);
	int send(socket_t s, void* buf, int len, int flags);
	int sendto(socket_t s, void* buf, int len, int flags, sockaddr* to, int tolen);
	int recv(socket_t s, void* buf, int len, int flags);
	int recvfrom(socket_t s, void* buf, int len, int flags, sockaddr* from, int* fromlen);
	int select(int nfds, fd_set* readfds, fd_set* writefds, fd_set* errorfds, timeval* timeout);
	//int __WSAFDIsSet(socket_t s, fd_set* fds);
	int getsockopt(socket_t s, int level, int optname, void* optval, int* optlen);
	int setsockopt(socket_t s, int level, int optname, void* optval, int optlen);
	int gethostname(void* namebuffer, int buflen);
	char* inet_ntoa(uint ina);
	hostent* gethostbyname(char* name);
	hostent* gethostbyaddr(void* addr, int len, int type);
	int WSAGetLastError();
}

struct NetSocket {
static private:
	bool wsaStarted = false;
	socket_t sock;
	timeval timeout;
	
	Object lockIn;
	Object lockOut;
	
	debug (NetDebug) {
		Random rand;
		uint bits;
		uint useCount = 32;
		
		static this() {
			rand = new Random();
		}
	}

static public:
	void open(char[] ip, ushort port, uint tout) {
		if (!wsaStarted) {
			wsaStarted = true;
			WSADATA wsaData;
			WSAStartup(MAKEWORD(1, 1), &wsaData);
			lockIn = new Object();
			lockOut = new Object();
		}
		
		sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
		if (sock < 0) throw new Exception("Could not create socket");
		
		NetAddress local;
		local.set(ip, port);
		if (bind(sock, cast(sockaddr*)&local, local.sizeof) != 0) throw new Exception("Could not bind socket");
		
		timeout.tv_sec = tout / 1000;
		timeout.tv_usec = tout % 1000;
	}
	
	void close() {
		shutdown(sock, SHUT_RDWR);
	}
	
	int read(ubyte[] buffer, out NetAddress address) {
		fd_set r;
		timeval tout = timeout;
		r.set(sock);
		
		int res = select(0, &r, null, null, &tout);
		switch (res) {
		case 1:	// has data
			int fromLen = address.sizeof;
			int amount;
//			synchronized (lockIn) {
				amount = recvfrom(sock, buffer.ptr, buffer.length, 0, cast(sockaddr*)&address, &fromLen);
//			}
			if (amount < 0) {
				switch (WSAGetLastError()) {
				case WSAENETDOWN:
				case WSAEINTR:
				case WSAEINPROGRESS:
				case WSAENETRESET:
				case WSAEMSGSIZE:
				case WSAETIMEDOUT:
				case WSAECONNRESET:
					return 0;
				break;
				case WSANOTINITIALISED:
				case WSAEFAULT:
				case WSAEINVAL:
				case WSAEISCONN:
				case WSAENOTSOCK:
				case WSAEOPNOTSUPP:
				case WSAESHUTDOWN:
				case WSAEWOULDBLOCK:
				default:
					throw new SocketException("Socket exception");
				break;
				}
			}

			return amount;
		break;
		case 0: // no data
			return 0;
		break;
		default:
			switch (WSAGetLastError()) {
			case WSAEFAULT:
			case WSAENETDOWN:
			case WSAEINTR:
			case WSAEINPROGRESS:
				return 0;
			break;
			case WSANOTINITIALISED:
			case WSAEINVAL:
			case WSAENOTSOCK:
			default:
				throw new SocketException("Socket exception");
			break;
			}
		break;
		}
		return -1;
	}
	
	void write(void[] buffer, NetAddress address) {
		int amount;
		
		synchronized (lockOut) {
			debug (NetDebug) {
				if (useCount >= 32) {
					bits = rand.uniform!(uint);
				}
				if ((bits & 0x3) == 0x3) {
					return;
				}
				bits >>= 2;
				useCount += 2;
			}
			
			amount = sendto(sock, buffer.ptr, buffer.length, 0, cast(sockaddr*)&address, address.sizeof);
		}
		if (amount < 0) {
			switch (WSAGetLastError()) {
			case WSAENETDOWN:
			case WSAEINTR:
			case WSAEINPROGRESS:
			case WSAENETRESET:
			case WSAENOBUFS:
			case WSAEWOULDBLOCK:
			case WSAECONNRESET:
			case WSAEADDRNOTAVAIL:
			case WSAEAFNOSUPPORT:
			case WSAENETUNREACH:
			case WSAEHOSTUNREACH:
			case WSAETIMEDOUT:
				return;
			break;
			case WSANOTINITIALISED:
			case WSAEACCES:
			case WSAEINVAL:
			case WSAEFAULT:
			case WSAENOTCONN:
			case WSAENOTSOCK:
			case WSAEOPNOTSUPP:
			case WSAESHUTDOWN:
			case WSAEMSGSIZE:
			case WSAECONNABORTED:
			case WSAEDESTADDRREQ:
			default:
				throw new SocketException("Socket exception");
			break;
			}
		}
	}
}
