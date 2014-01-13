module aahz.math.Vector;

import tango.math.Math;

import aahz.math.Euler;
import aahz.math.Matrix;
import aahz.math.Quaternion;

union Vector {
	float[3] data;
	struct {
		float x, y, z;
	}
	
	void opAssign(float[3] d) {
		data[] = d[];
	}
	
	void normalize() {
		float mag = x*x + y*y + z*z;
		if (mag != 0.0f) {
			mag = 1.0f / sqrt(mag);
			x *= mag;
			y *= mag;
			z *= mag;
		}
	}
	
	void opAddAssign(Vector v) {
		x += v.x;
		y += v.y;
		z += v.z;
	}
	
	Vector opAdd(Vector v) {
		Vector ret;
		ret.data[] = [
			x + v.x,
			y + v.y,
			z + v.z
		];
		return ret;
	}
	
	void opSubAssign(Vector v) {
		x -= v.x;
		y -= v.y;
		z -= v.z;
	}
	
	Vector opSub(Vector v) {
		Vector ret;
		ret.data[] = [
			x - v.x,
			y - v.y,
			z - v.z
		];
		return ret;
	}
	
	Vector opNeg() {
		Vector ret;
		ret.data[] = [-x, -y, -z];
		return ret;
	}
	
	void opMulAssign(float scale) {
		x *= scale;
		y *= scale;
		z *= scale;
	}
	
	Vector opMul(float scale) {
		Vector ret;
		ret.data[] = [
			x * scale,
			y * scale,
			z * scale
		];
		return ret;
	}
	
	void opMulAssign(Matrix m) {
		float tx = x;
		float ty = y;
		float tz = z;
		
		tx = m.m11*x + m.m12*y + m.m13*z;
		ty = m.m21*x + m.m22*y + m.m23*z;
		tz = m.m31*x + m.m32*y + m.m33*z;
		
		x = tx;
		y = ty;
		z = tz;
	}
	
	Vector opMul(Matrix m) {
		Vector ret;
		ret.data[] = [
			m.m11*x + m.m12*y + m.m13*z,
			m.m21*x + m.m22*y + m.m23*z,
			m.m31*x + m.m32*y + m.m33*z
		];
		return ret;
	}
	
	void opShrAssign(Matrix m) {
		float tx = x;
		float ty = y;
		float tz = z;
		
		tx = m.m11*x + m.m12*y + m.m13*z + m.m14;
		ty = m.m21*x + m.m22*y + m.m23*z + m.m24;
		tz = m.m31*x + m.m32*y + m.m33*z + m.m34;
		
		x = tx;
		y = ty;
		z = tz;
	}
	
	Vector opShr(Matrix m) {
		Vector ret;
		ret.data[] = [
			m.m11*x + m.m12*y + m.m13*z + m.m14,
			m.m21*x + m.m22*y + m.m23*z + m.m24,
			m.m31*x + m.m32*y + m.m33*z + m.m34
		];
		return ret;
	}
	
	void opMulAssign(Quaternion q) {
		opMulAssign(q.getMatrix());
	}
	
	Vector opMul(Quaternion q) {
		return opMul(q.getMatrix());
	}
	
	void opMulAssign(Euler e) {
		opMulAssign(e.getMatrix());
	}
	
	Vector opMul(Euler e) {
		return opMul(e.getMatrix());
	}
}

template VPositioned() {
	Vector position;
	
	void setPosition(float x, float y, float z) {
		position.data[] = [x, y, z];
	}
	
	void setPosition(Vector p) {
		position = p;
	}
	
	Vector getPosition() {
		Vector ret = position;	// make a copy
		return ret;
	}
}
