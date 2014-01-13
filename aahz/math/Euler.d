module aahz.math.Euler;

import tango.math.Math;
import tango.io.Stdout;

import aahz.math.Matrix;
import aahz.math.Quaternion;

union Euler {
	float[3] data = [0.0f, 0.0f, 0.0f];
	struct {
		float h, p, b;
	}
	
	void opAssign(float[3] f) {
		data[] = f[];
	}
	
	Matrix getMatrix() {
		Matrix ret;
		scope Quaternion heading;
		scope Quaternion pitch;
		scope Quaternion bank;
		
		heading.toRotateY(h);
		pitch.toRotateX(p);
		bank.toRotateZ(b);
		
//		ret = (heading * pitch * bank).getMatrix();
		ret = (bank * pitch * heading).getMatrix();

		return ret;
	}
	
	Quaternion getQuaternion() {
		Quaternion ret;
		scope Quaternion heading;
		scope Quaternion pitch;
		scope Quaternion bank;
		
		heading.toRotateY(h);
		pitch.toRotateX(p);
		bank.toRotateZ(b);
		
//		ret = heading * pitch * bank;
		ret = bank * pitch * heading;

		return ret;
	}
	
	void opAddAssign(Euler e) {
		h += e.h;
		p += e.p;
		b += e.b;
	}
	
	Euler opAdd(Euler e) {
		Euler ret;
		ret.data[] = [
			h + e.h,
			p + e.p,
			b + e.b
		];
		return ret;
	}
	
	void opSubAssign(Euler e) {
		h -= e.h;
		p -= e.p;
		b -= e.b;
	}
	
	Euler opSub(Euler e) {
		Euler ret;
		ret.data[] = [
			h - e.h,
			p - e.p,
			b - e.b
		];
		return ret;
	}
	
	Euler opNeg() {
		Euler ret;
		ret.data[] = [
			h + PI,
			p + PI,
			b + PI
		];
		return ret;
	}
	
	void dump() {
		Stdout.format(
			"{} {} {}\n\n",
			h, p, b
		).flush();
	}
}

template ERotated() {
	Euler rotation;
	
	void setRotation(float heading) {
		rotation.data[] = [heading, 0, 0];
	}
	
	void setRotation(float heading, float pitch) {
		rotation.data[] = [heading, pitch, 0];
	}
	
	void setRotation(float heading, float pitch, float bank) {
		rotation.data[] = [heading, pitch, bank];
	}
	
	void rotate(Euler e) {
		rotation += e;
	}
	
	Matrix getMRotation() {
		return rotation.getMatrix();
	}
	
	Quaternion getQRotation() {
		return rotation.getQuaternion();
	}
}
