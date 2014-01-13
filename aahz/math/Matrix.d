module aahz.math.Matrix;

import tango.math.Math;
import tango.io.Stdout;

import aahz.math.Euler;
import aahz.math.Quaternion;
import aahz.math.Vector;

union Matrix {
	float[16] data = [
		1.0f, 0.0f, 0.0f, 0.0f,
		0.0f, 1.0f, 0.0f, 0.0f,
		0.0f, 0.0f, 1.0f, 0.0f,
		0.0f, 0.0f, 0.0f, 1.0f
	];
	struct {
		float
			m11, m21, m31, m41,
			m12, m22, m32, m42,
			m13, m23, m33, m43,
			m14, m24, m34, m44
		;
	}
	struct {	// Depending on how you like to order them
		float
			n00, n10, n20, n30,
			n01, n11, n21, n31,
			n02, n12, n22, n32,
			n03, n13, n23, n33
		;
	}
	struct {	// Depending on how you like to order them
		float
			o11, o12, o13, o14,
			o21, o22, o23, o24,
			o31, o32, o33, o34,
			o41, o42, o43, o44
		;
	}
	struct {	// Depending on how you like to order them
		float
			p00, p01, p02, p03,
			p10, p11, p12, p13,
			p20, p21, p22, p23,
			p30, p31, p32, p33
		;
	}
	
	void opAssign(float[16] f) {
		data[] = f[];
	}
	
	Quaternion getQuaternion() {
		Quaternion ret;
		float trace = p00 + p11 + p22 + 1.0f;
		if( trace > 0.0f ) {
			float s = 0.5f / sqrt(trace);
			ret.w = 0.25f / s;
			ret.x = ( p21 - p12 ) * s;
			ret.y = ( p02 - p20 ) * s;
			ret.z = ( p10 - p01 ) * s;
		}
		else {
			if ( p00 > p11 && p00 > p22 ) {
				float s = 2.0f * sqrt( 1.0f + p00 - p11 - p22);
				float oneS = 1.0f / s;
				ret.w = (p21 - p12 ) * oneS;
				ret.x = 0.25f * s;
				ret.y = (p01 + p10 ) * oneS;
				ret.z = (p02 + p20 ) * oneS;
			} else if (p11 > p22) {
				float s = 2.0f * sqrt( 1.0f + p11 - p00 - p22);
				float oneS = 1.0f / s;
				ret.w = (p02 - p20 ) * oneS;
				ret.x = (p01 + p10 ) * oneS;
				ret.y = 0.25f * s;
				ret.z = (p12 + p21 ) * oneS;
			} else {
				float s = 2.0f * sqrt( 1.0f + p22 - p00 - p11 );
				float oneS = 1.0f / s;
				ret.w = (p10 - p01 ) * oneS;
				ret.x = (p02 + p20 ) * oneS;
				ret.y = (p12 + p21 ) * oneS;
				ret.z = 0.25f * s;
			}
		}
		return ret;
	}
	
	void opUShrAssign(Matrix m) {
		float a = m11;
		float b = m21;
		float c = m31;
		float d = m41;
		m11 = a*m.m11 + b*m.m12 + c*m.m13 + d*m.m14;
		m21 = a*m.m21 + b*m.m22 + c*m.m23 + d*m.m24;
		m31 = a*m.m31 + b*m.m32 + c*m.m33 + d*m.m34;
		m41 = a*m.m41 + b*m.m42 + c*m.m43 + d*m.m44;

		a = m12;
		b = m22;
		c = m32;
		d = m42;
		m12 = a*m.m11 + b*m.m12 + c*m.m13 + d*m.m14;
		m22 = a*m.m21 + b*m.m22 + c*m.m23 + d*m.m24;
		m32 = a*m.m31 + b*m.m32 + c*m.m33 + d*m.m34;
		m42 = a*m.m41 + b*m.m42 + c*m.m43 + d*m.m44;

		a = m13;
		b = m23;
		c = m33;
		d = m43;
		m13 = a*m.m11 + b*m.m12 + c*m.m13 + d*m.m14;
		m23 = a*m.m21 + b*m.m22 + c*m.m23 + d*m.m24;
		m33 = a*m.m31 + b*m.m32 + c*m.m33 + d*m.m34;
		m43 = a*m.m41 + b*m.m42 + c*m.m43 + d*m.m44;
		
		a = m14;
		b = m24;
		c = m34;
		d = m44;
		m14 = a*m.m11 + b*m.m12 + c*m.m13 + d*m.m14;
		m24 = a*m.m21 + b*m.m22 + c*m.m23 + d*m.m24;
		m34 = a*m.m31 + b*m.m32 + c*m.m33 + d*m.m34;
		m44 = a*m.m41 + b*m.m42 + c*m.m43 + d*m.m44;
	}
	
	Matrix opUShr(Matrix m) {
		Matrix ret;
		
		ret.m11 = m11*m.m11 + m21*m.m12 + m31*m.m13 + m41*m.m14;
		ret.m21 = m11*m.m21 + m21*m.m22 + m31*m.m23 + m41*m.m24;
		ret.m31 = m11*m.m31 + m21*m.m32 + m31*m.m33 + m41*m.m34;
		ret.m41 = m11*m.m41 + m21*m.m42 + m31*m.m43 + m41*m.m44;

		ret.m12 = m12*m.m11 + m22*m.m12 + m32*m.m13 + m42*m.m14;
		ret.m22 = m12*m.m21 + m22*m.m22 + m32*m.m23 + m42*m.m24;
		ret.m32 = m12*m.m31 + m22*m.m32 + m32*m.m33 + m42*m.m34;
		ret.m42 = m12*m.m41 + m22*m.m42 + m32*m.m43 + m42*m.m44;

		ret.m13 = m13*m.m11 + m23*m.m12 + m33*m.m13 + m43*m.m14;
		ret.m23 = m13*m.m21 + m23*m.m22 + m33*m.m23 + m43*m.m24;
		ret.m33 = m13*m.m31 + m23*m.m32 + m33*m.m33 + m43*m.m34;
		ret.m43 = m13*m.m41 + m23*m.m42 + m33*m.m43 + m43*m.m44;
		
		ret.m14 = m14*m.m11 + m24*m.m12 + m34*m.m13 + m44*m.m14;
		ret.m24 = m14*m.m21 + m24*m.m22 + m34*m.m23 + m44*m.m24;
		ret.m34 = m14*m.m31 + m24*m.m32 + m34*m.m33 + m44*m.m34;
		ret.m44 = m14*m.m41 + m24*m.m42 + m34*m.m43 + m44*m.m44;
		
		return ret;
	}
	
	void opShrAssign(Matrix m) {
		float t11 = m11;
		float t21 = m21;
		float t31 = m31;

		float t12 = m12;
		float t22 = m22;
		float t32 = m32;

		float t13 = m13;
		float t23 = m23;
		float t33 = m33;

		float t14 = m14;
		float t24 = m24;
		float t34 = m34;
		
		m11 = t11*m.m11 + t21*m.m12 + t31*m.m13;
		m21 = t11*m.m21 + t21*m.m22 + t31*m.m23;
		m31 = t11*m.m31 + t21*m.m32 + t31*m.m33;

		m12 = t12*m.m11 + t22*m.m12 + t32*m.m13;
		m22 = t12*m.m21 + t22*m.m22 + t32*m.m23;
		m32 = t12*m.m31 + t22*m.m32 + t32*m.m33;

		m13 = t13*m.m11 + t23*m.m12 + t33*m.m13;
		m23 = t13*m.m21 + t23*m.m22 + t33*m.m23;
		m33 = t13*m.m31 + t23*m.m32 + t33*m.m33;

		m14 = t14*m.m11 + t24*m.m12 + t34*m.m13;
		m24 = t14*m.m21 + t24*m.m22 + t34*m.m23;
		m34 = t14*m.m31 + t24*m.m32 + t34*m.m33;
	}

	Matrix opShr(Matrix m) {
		Matrix ret;
		
		ret.m11 = m11*m.m11 + m21*m.m12 + m31*m.m13;
		ret.m21 = m11*m.m21 + m21*m.m22 + m31*m.m23;
		ret.m31 = m11*m.m31 + m21*m.m32 + m31*m.m33;

		ret.m12 = m12*m.m11 + m22*m.m12 + m32*m.m13;
		ret.m22 = m12*m.m21 + m22*m.m22 + m32*m.m23;
		ret.m32 = m12*m.m31 + m22*m.m32 + m32*m.m33;

		ret.m13 = m13*m.m11 + m23*m.m12 + m33*m.m13;
		ret.m23 = m13*m.m21 + m23*m.m22 + m33*m.m23;
		ret.m33 = m13*m.m31 + m23*m.m32 + m33*m.m33;

		ret.m14 = m14*m.m11 + m24*m.m12 + m34*m.m13;
		ret.m24 = m14*m.m21 + m24*m.m22 + m34*m.m23;
		ret.m34 = m14*m.m31 + m24*m.m32 + m34*m.m33;
		
		return ret;
	}

	void opMulAssign(Matrix m) {
		float a = m11;
		float b = m21;
		float c = m31;
		
		m11 = m.m11*a + m.m12*b + m.m13*c;
		m21 = m.m21*a + m.m22*b + m.m23*c;
		m31 = m.m31*a + m.m32*b + m.m33*c;
		
		a = m12;
		b = m22;
		c = m32;
		m12 = m.m11*a + m.m12*b + m.m13*c;
		m22 = m.m21*a + m.m22*b + m.m23*c;
		m32 = m.m31*a + m.m32*b + m.m33*c;
		
		a = m13;
		b = m23;
		c = m33;
		m13 = m.m11*a + m.m12*b + m.m13*c;
		m23 = m.m21*a + m.m22*b + m.m23*c;
		m33 = m.m31*a + m.m32*b + m.m33*c;
	}
	
	Matrix opMul(Matrix m) {
		Matrix ret;

		ret.m11 = m.m11*m11 + m.m12*m21 + m.m13*m31;
		ret.m21 = m.m21*m11 + m.m22*m21 + m.m23*m31;
		ret.m31 = m.m31*m11 + m.m32*m21 + m.m33*m31;
		
		ret.m12 = m.m11*m12 + m.m12*m22 + m.m13*m32;
		ret.m22 = m.m21*m12 + m.m22*m22 + m.m23*m32;
		ret.m32 = m.m31*m12 + m.m32*m22 + m.m33*m32;
		
		ret.m13 = m.m11*m13 + m.m12*m23 + m.m13*m33;
		ret.m23 = m.m21*m13 + m.m22*m23 + m.m23*m33;
		ret.m33 = m.m31*m13 + m.m32*m23 + m.m33*m33;
		
		return ret;
	}
	
	void opMulAssign(Quaternion q) {
		opMulAssign(q.getMatrix());
	}

	Matrix opMul(Quaternion q) {
		return opMul(q.getMatrix());
	}
	
	void opMulAssign(Euler e) {
		opMulAssign(e.getMatrix());
	}

	Matrix opMul(Euler e) {
		return opMul(e.getMatrix());
	}
	
	float getDeterminant4() {
		float im = m13 * m14;
		float jn = m23 * m24;
		float ko = m33 * m34;
		float lp = m43 * m44;

		float ijmn1 = (m13 + m23) * (-m14 + m24);
		float jkno1 = (m23 + m33) * (-m24 + m34);
		float klop1 = (m33 + m43) * (-m34 + m44);
		float ilmp1 = (m13 + m43) * (-m14 + m44);
		float jlnp1 = (m23 + m43) * (-m24 + m44);
		float ikmo1 = (m13 + m33) * (-m14 + m34);

		float ijmn2 = ijmn1 + im - jn;
		float jkno2 = jkno1 + jn - ko;
		float klop2 = klop1 + ko - lp;
		float ilmp2 = ilmp1 + im - lp;
		float jlnp2 = jlnp1 + jn - lp;
		float ikmo2 = ikmo1 + im - ko;
		
		return 
			m11 * (	// a
				m22 * klop2	// f
				- m32 * jlnp2	// g
				+ m42 * jkno2	// h
			)
			- m21 * (	// b
				m12 * klop2	// e
				- m32 * ilmp2	// g
				+ m42 * ikmo2	// h
			)
			+ m31 * (	// c
				m12 * jlnp2	// e
				- m22 * ilmp2	// f
				+ m42 * ijmn2	// h
			)
			- m41 * (	// d
				m12 * jkno2	// e
				- m22 * ikmo2	// f
				+ m32 * ijmn2	// g
			)
		;
	}
	
	float getDeterminant3() {
		return
			m11 * (	// a * (ei - fh)
				m22 * m33
				- m32 * m23
			)
			- m21 * (	// b * (di - fg)
				m12 * m33
				- m32 * m13
			)
			+ m31 * (	// c * (dh - eg)
				m12 * m23
				- m22 * m13
			)
		;
	}
	
	Matrix getInverse() {
		Matrix ret;
		
		float det = getDeterminant3();
		assert(abs(det) > 0.000001f);
		
		float oneOverDet = 1.0f / det;
		
		ret.o11 = (o22*o33 - o23*o32) * oneOverDet;
		ret.o12 = (o13*o32 - o12*o33) * oneOverDet;
		ret.o13 = (o12*o23 - o13*o22) * oneOverDet;

		ret.o21 = (o23*o31 - o21*o33) * oneOverDet;
		ret.o22 = (o11*o33 - o13*o31) * oneOverDet;
		ret.o23 = (o13*o21 - o11*o23) * oneOverDet;

		ret.o31 = (o21*o32 - o22*o31) * oneOverDet;
		ret.o32 = (o12*o31 - o11*o32) * oneOverDet;
		ret.o33 = (o11*o22 - o12*o21) * oneOverDet;

		ret.o41 = -(o41*ret.o11 + o42*ret.o21 + o43*ret.o31);
		ret.o42 = -(o41*ret.o12 + o42*ret.o22 + o43*ret.o32);
		ret.o43 = -(o41*ret.o13 + o42*ret.o23 + o43*ret.o33);

		return ret;
	}
	
	void setTranslation(Vector v) {
		m14 = v.x;
		m24 = v.y;
		m34 = v.z;
	}
	
	void setScale(float scale) {
		m11 = scale;
		m22 = scale;
		m33 = scale;
	}
	
	void toIdentity() {
		data[] = [
			1.0f, 0.0f, 0.0f, 0.0f,
			0.0f, 1.0f, 0.0f, 0.0f,
			0.0f, 0.0f, 1.0f, 0.0f,
			0.0f, 0.0f, 0.0f, 1.0f
		];
	}
	
	void transpose() {
		float t;
		
		t = m21; m21 = m12; m12 = t;
		t = m31; m31 = m13; m13 = t;
		t = m41; m41 = m14; m14 = t;
		t = m32; m32 = m23; m23 = t;
		t = m42; m42 = m24; m24 = t;
		t = m43; m43 = m34; m34 = t;
	}
	
	void dump() {
		Stdout.format(
			"{} {} {} {}\n{} {} {} {}\n{} {} {} {}\n{} {} {} {}\n\n",
			m11, m21, m31, m41,
			m12, m22, m32, m42,
			m13, m23, m33, m43,
			m14, m24, m34, m44
		).flush();
	}
}

template MRotated() {
	Matrix rotation;
	
	void setRotation(float heading) {
		Euler e;
		e.data[] = [heading, 0.0, 0.0];
		rotation = e.getMatrix();
	}
	
	void setRotation(float heading, float pitch) {
		Euler e;
		e.data[] = [heading, pitch, 0.0];
		rotation = e.getMatrix();
	}
	
	void setRotation(float heading, float pitch, float bank) {
		Euler e;
		e.data[] = [heading, pitch, bank];
		rotation = e.getMatrix();
	}
	
	void rotate(Euler e) {
		rotation *= e;
	}
	
	Matrix getMRotation() {
		Matrix ret = rotation;	// make a copy
		return ret;
	}
	
	Quaternion getQRotation() {
		return rotation.getQuaternion();
	}
}
