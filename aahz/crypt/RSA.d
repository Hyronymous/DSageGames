module aahz.crypt.RSA;

import aahz.crypt.Crypt;

import tango.math.BigInt;
import tango.io.Stdout;
import dcrypt.crypto.PRNG;

// http://en.wikipedia.org/wiki/Rsa
// http://www.laynetworks.com/rsa%20algorithm.htm
// http://code.google.com/p/rsa/source/browse/#svn/rsa/trunk/source

struct RSAPublicKey {
package:
	BigInt m_n;
	BigInt m_e;

public:
	static RSAPublicKey opCall(BigInt _n, BigInt _e) {
		RSAPublicKey ret;
		ret.m_n = _n;
		ret.m_e = _e;
		return ret;
	}
	
	BigInt n() {
		return m_n;
	}
	
	BigInt e() {
		return m_e;
	}
}

struct RSAPrivateKey {
package:
	BigInt m_n;
	BigInt m_d;
	BigInt m_p;
	BigInt m_q;
	BigInt m_dp;
	BigInt m_dq;
	BigInt m_u;

public:
	static RSAPrivateKey opCall(BigInt _n, BigInt _d, BigInt _p, BigInt _q) {
		RSAPrivateKey ret;
		
		ret.m_n = _n;
		ret.m_d = _d;
		ret.m_p = _p;
		ret.m_q = _q;
		
		ret.m_dp = _p - 1;
		ret.m_dp = _d % ret.m_dp;
		ret.m_dq = _q - 1;
		ret.m_dq = _d % ret.m_dq;
		
		ret.m_u = modInverse(_q, _p);
		
		return ret;
	}
	
	BigInt n() {
		return m_n;
	}
	
	BigInt d() {
		return m_d;
	}
	
	BigInt p() {
		return m_p;
	}
	
	BigInt q() {
		return m_q;
	}
}

class RSA {
private:
	const uint KEY_SIZE = 2048;
	const uint MIN_E = 65537;
	
	RSAPublicKey m_pub;
	RSAPrivateKey m_prv;
	
public:
	this(RSAPublicKey pub, RSAPrivateKey prv) {
		m_pub = pub;
		m_prv = prv;
	}
	
	this(RSAPublicKey pub) {
		m_pub = pub;
	}
	
	bool encryptable(BigInt value) {	// Not all values can be encrypted by RSA
		if (value == 0 || value >= m_pub.n) return false;
		return true;
	}
	
	BigInt encrypt(BigInt data) {
		if (data <= 0 || data > m_pub.n) throw new Exception("Value must be more than 0 and less than pub.n");
		return modPow(data, m_pub.e, m_pub.n);
	}
	
	BigInt decrypt(BigInt data) {
		BigInt ret, p2, q2, k;

		p2 = data % m_prv.m_p;
		p2 = modPow(p2, m_prv.m_dp, m_prv.m_p);
		q2 = data % m_prv.m_q;
		q2 = modPow(q2, m_prv.m_dq, m_prv.m_q);
		
		k = (p2 - q2);
		k *= m_prv.m_u;
		k %= m_prv.m_p;
		
		ret = m_prv.m_q * k;
		ret += q2;
		
		return ret;
	}

	static void generateKey(
		PRNG generator,
		inout RSAPublicKey pub,
		inout RSAPrivateKey prv
	) {
		BigInt temp, p, q, n, e, d, phi;
		uint pbits, qbits;
		pbits = KEY_SIZE / 2;
		qbits = KEY_SIZE - pbits;
				
RETRY:
		p = bigRand(pbits, generator);
		if (p.isEven()) p += 1;	//	primes are always odd
		while ((p % 3) == 0) p += 2;	// Don't let it be divisible by 3 either
		while ( !isPrime(p) ) p += 6;	// Will stay indivisible by both 2 and 3 by adding 6 (makes the code go 6 times faster)

		q = bigRand(qbits, generator);
		if (q.isEven()) q += 1;
		while ((q % 3) == 0) q += 2;
		while ( !isPrime(q) ) q += 6;

		if (q > p) {	// Make sure that q < p
			temp = p;
			p = q;
			q = temp;
		}
		else if (p == q) {
			goto RETRY;
		}
		
		temp = p - q;
		n = p * q;
		if ( temp < (bigSqrt(bigSqrt(n)) * 2) ) {	// Make sure the difference is >= 2n^(1/4)
			goto RETRY;
		}
		
		phi = (p - 1) * (q - 1);
		e = MIN_E;
		while (
			gcd(phi, e) != 1
			|| e < MIN_E
		) {
			e = bigRand(20, generator);
			if (e.isEven()) --e;
		}
		
		if (e >= phi) {
			goto RETRY;
		}

		temp = gcd( (p - 1), (q - 1) );
		temp = phi / temp;
		d = modInverse(e, temp);
		if (d < 0) {	// Must be positive
			goto RETRY;
		}
		
		pub = RSAPublicKey(n, e);
		prv = RSAPrivateKey(n, d, p, q);

		RSA testRSA = new RSA(pub, prv);	// Finally, test that it actually encrypts. If it's not a true prime, this shouldn't work
		BigInt testValue = BigInt("0x12345678_12345678_12345678_12345678");
		BigInt encrypted = testRSA.encrypt(testValue);
		BigInt decrypted = testRSA.decrypt(encrypted);
		if (decrypted != testValue)	goto RETRY;
	}
}
