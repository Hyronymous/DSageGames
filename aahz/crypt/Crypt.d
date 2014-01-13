module aahz.crypt.Crypt;

import tango.math.BigInt;
import tango.math.random.Random;
import tango.stdc.math;
import tango.io.Stdout;

import dcrypt.crypto.PRNG;

// Miller-Rabin code based on http://en.literateprograms.org/Miller-Rabin_primality_test_%28C%2C_GMP%29
// Other code from:
// http://www.laynetworks.com/rsa%20algorithm.htm
// http://code.google.com/p/rsa/source/browse/#svn/rsa/trunk/source

public {
	BigInt fromBytes(ubyte[] a) {
		BigInt ret;
		
		for (int L = (a.length - 1); L >= 0; L--) {
			ret <<= 8;
			ret += a[L];
		}
		return ret;
	}
	
	ubyte[] toBytes(BigInt a) {
		if (a < 0) throw new Exception("Value must be positive");
		
		ubyte[] ret;
		while (a != 0) {
			ret.length = ret.length + 1;
			BigInt temp = a >> 8;
			temp <<= 8;
			BigInt temp2 = a - temp;
			ret[$-1] = temp2.toInt();
			
			a >>= 8;
		}
		
		return ret;
	}
	
	uint[] toArray(BigInt a) {
		if (a < 0) throw new Exception("Value must be positive");
		
		uint length = a.uintLength();
		uint[] ret = new uint[ length ];
		BigInt cpy = a;
		BigInt cpy2 = a;
		
		cpy2 >>= 32;
		cpy2 <<= 32;
		cpy -= cpy2;
		for (uint L = 0; L < length; L++) {
			ret[L] = cast(uint)cpy.toLong();
			cpy += cpy2;
			cpy2 >>= 64;
			cpy2 <<= 32;
			cpy >>= 32;
			cpy -= cpy2;
		}
		return ret;
	}
	
	BigInt fromArray(uint[] a) {
		BigInt ret;
		for (int L = (a.length - 1); L >= 0; L--) {
			ret <<= 32;
			ret += a[L];
		}
		return ret;
	}
	
	BigInt gcd(BigInt a, BigInt b) {
		if (b == 0)
			return a;
		else
			return gcd(b, a % b);
	}
	
	BigInt modPow(BigInt base, BigInt exp, BigInt mod) {
		BigInt ret = 1;
		
		BigInt lexp = exp;
		while (lexp > 0) {
			if (!lexp.isEven()) {
				ret = (ret * base) % mod;
			}
			lexp >>= 1;
			base = (base * base) % mod;
		}
		
		return ret;
	}
	
	BigInt modInverse(BigInt a, BigInt n) {
		BigInt g0, g1, v0, v1, div, mod, aux;

		g0 = n;
		g1 = a;
		v1 = 1;

		while (g1 != 0) {
			div = g0 / g1;
			mod = g0 % g1;
			aux = div * v1;
			aux = v0 - aux;
			v0 = v1;
			v1 = aux;
			g0 = g1;
			g1 = mod;
		}

		if (v0 < 0) {
			return v0 + n;
		}
		else {
			return v0;
		}
	}
	
	BigInt bigSqrt(BigInt n) {
		BigInt x = n >> 1;
		BigInt prev = -1;
		
		while (true) {
			x = (x + (n / x)) >> 1;
			if (
				prev != -1
				&& x == prev
			) {
				break;
			}
			prev = x;
		}
		return x;
	}
	
	BigInt bigRand(BigInt n, PRNG generator = null) {
		if (n < 0) throw new Exception("Parameter must be positive");
		BigInt ret;
		
		if (generator is null) {
			Random r = new Random();
			
			ret = r.uniform!(uint);
			while (ret < n) {
				ret <<= 32;
				ret += r.uniform!(uint);
			}
			ret %= n;
		}
		else {
			if (!generator.initialized) throw new Exception("Generator has not been initialized");
			
			ubyte[1] buffer;
			generator.read(buffer);
			ret = buffer[0];
			while (ret < n) {
				generator.read(buffer);
				ret <<= 8;
				ret += buffer[0];
			}
			ret %= n;
		}
		
		return ret;
	}
	
	BigInt bigRand(uint bits, PRNG generator = null) {
		BigInt ret;
		
		if (generator is null) {
			Random r = new Random();
			
			uint count = bits / 32;
			for (uint L = 0; L < count; L++) {
				if (L != 0) ret <<= 32;
				ret += r.uniform!(uint);
			}
			uint remainder = bits % 32;
			if (remainder > 0) {
				ret <<= remainder;
				ret += r.uniform!(uint) >> (32 - remainder);
			}
		}
		else {
			if (!generator.initialized) throw new Exception("Generator has not been initialized");
			
			uint count = bits / 8;
			ubyte[] buffer = new ubyte[ count + 1 ];
			generator.read(buffer);
			
			for (uint L = 0; L < count; L++) {
				if (L != 0) ret <<= 8;
				ret += buffer[L];
			}
			uint remainder = bits % 8;
			if (remainder > 0) {
				ret <<= remainder;
				ret += buffer[$-1] >> (8 - remainder);
			}
		}
		
		return ret;
	}
	
	bool isPrime(BigInt n) {
		if (n < 2) return false;
		else if (
			n == 2
			|| n == 3
			|| n == 5
			|| n == 7
		) return true;
		else if (
			n.isEven()
			|| (n % 3) == 0
			|| (n % 5) == 0
			|| (n % 7) == 0
		) return false;
		
		BigInt a;
		for (int repeat = 0; repeat < 20; repeat++) {
			do {
				a = bigRand(n);
			} while (a == 0);
			if (!miller_rabin_pass(a, n)) {
				return false;
			}
		}
		return true;
	}
}

private {
	bool miller_rabin_pass(BigInt a, BigInt n) {
		int i, s;
		BigInt a_to_power, d, n_minus_one;

		n_minus_one = n - 1;
		
		s = 0;
		d = n_minus_one;
		while (d.isEven()) {
			d >>= 1;
			s++;
		}
		
		a_to_power = modPow(a, d, n);
		if (a_to_power == 1)  {
			return true;
		}
		for(i = 0; i < (s-1); i++) {
			if (a_to_power == n_minus_one) {
				return true;
			}
			a_to_power = (a_to_power * a_to_power) % n;
		}
		if (a_to_power == n_minus_one) {
			return true;
		}
		return false;
	}
}
