module aahz.math.Quaternion;

import tango.math.Math;
import tango.io.Stdout;

import aahz.math.Matrix;
import aahz.math.Euler;

union Quaternion {
	float[4] data = [1.0f, 0.0f, 0.0f, 0.0f];
	struct {
		float w, x, y, z;
	}
	
	Matrix getMatrix() {
		Matrix ret;
		
		float x2 = x * x;
		float y2 = y * y;
		float z2 = z * z;
		float wx = w * x;
		float yz = y * z;
		
		float t1 = x * z;
		float t2 = w * y;
		float pt3 = (x + w) * (z + y);
		float nt3 = (x + w) * (-z + y);
		
		ret.m11 = 1.0f - ((y2 + z2) + (y2 + z2));
		ret.m21 = (pt3 - t2 - t1) + (pt3 - t2 - t1);
		ret.m31 = (t1 - t2) + (t1 - t2);

		ret.m12 = (nt3 + t1 - t2) + (nt3 + t1 - t2);
		ret.m22 = 1.0f - ((x2 + z2) + (x2 + z2));
		ret.m32 = (yz + wx) + (yz + wx);

		ret.m13 = (t1 + t2) + (t1 + t2);
		ret.m23 = (yz - wx) + (yz - wx);
		ret.m33 = 1.0f - ((x2 + y2) + (x2 + y2));
		
		return ret;
	}
	
	void opMulAssign(Quaternion q) {
		float A, B, C, D, E, F, G, H;

		A = (w + x)*(q.w + q.x);
		B = (z - y)*(q.y - q.z);
		C = (w - x)*(q.y + q.z); 
		D = (y + z)*(q.w - q.x);
		E = (x + z)*(q.x + q.y);
		F = (x - z)*(q.x - q.y);
		G = (w + y)*(q.w - q.z);
		H = (w - y)*(q.w + q.z);

		w = B + (-E - F + G + H)/2.0f;
		x = A - (E + F + G + H)/2.0f; 
		y = C + (E - F + G - H)/2.0f; 
		z = D + (E - F - G + H)/2.0f;
	}
	
	Quaternion opMul(Quaternion q) {
		Quaternion ret;
		float A, B, C, D, E, F, G, H;

		A = (w + x)*(q.w + q.x);
		B = (z - y)*(q.y - q.z);
		C = (w - x)*(q.y + q.z); 
		D = (y + z)*(q.w - q.x);
		E = (x + z)*(q.x + q.y);
		F = (x - z)*(q.x - q.y);
		G = (w + y)*(q.w - q.z);
		H = (w - y)*(q.w + q.z);

		ret.w = B + (-E - F + G + H) /2.0f;
		ret.x = A - (E + F + G + H)/2.0f;
		ret.y = C + (E - F + G - H)/2.0f;
		ret.z = D + (E - F - G + H)/2.0f;
		
		return ret;
	}
	
	void opMulAssign(Euler e) {
		opMulAssign(e.getQuaternion());
	}
	
	Quaternion opMul(Euler e) {
		return opMul(e.getQuaternion());
	}
	
	void opMulAssign(Matrix m) {
		opMulAssign(m.getQuaternion());
	}
	
	Quaternion opMul(Matrix m) {
		return opMul(m.getQuaternion());
	}
	
	void toRotateX(float theta) {
		float thetaOver2 = theta * 0.5f;
		
		w = cos(thetaOver2);
		x = sin(thetaOver2);
		y = 0.0f;
		z = 0.0f;
	}
	
	void toRotateY(float theta) {
		float thetaOver2 = theta * 0.5f;
		
		w = cos(thetaOver2);
		x = 0.0f;
		y = sin(thetaOver2);
		z = 0.0f;
	}
	
	void toRotateZ(float theta) {
		float thetaOver2 = theta * 0.5f;
		
		w = cos(thetaOver2);
		x = 0.0f;
		y = 0.0f;
		z = sin(thetaOver2);
	}
		
	Quaternion getConjugate() {
		Quaternion ret;
		ret.data[] = [w, -x, -y, -z];
		return ret;
	}
	
	Quaternion slerp(Quaternion q, float t) {
		Quaternion ret;
		float to1[4];
		float omega, cosom, sinom, scale0, scale1;

		// calc cosine
		cosom =
			x * q.x
			+ y * q.y
			+ z * q.z
			+ w * q.w
		;

		// adjust signs (if necessary)
		if (cosom <0.0f) {
			cosom = -cosom;
			to1[0] = -q.x;
			to1[1] = -q.y;
			to1[2] = -q.z;
			to1[3] = -q.w;
		}
		else {
			to1[0] = q.x;
			to1[1] = q.y;
			to1[2] = q.z;
			to1[3] = q.w;
		}

		// calculate coefficients
		if ( (1.0f - cosom) > 0.9999f ) {
			// standard case (slerp)
			omega = acos(cosom);
			sinom = sin(omega);
			scale0 = sin((1.0f - t) * omega) / sinom;
			scale1 = sin(t * omega) / sinom;
		}
		else {        
			// "from" and "to" quaternions are very close 
			//  ... so we can do a linear interpolation
			scale0 = 1.0f - t;
			scale1 = t;
		}
		
		// calculate final values
		ret.data[] = [
			scale0 * w + scale1 * to1[3],
			scale0 * x + scale1 * to1[0],
			scale0 * y + scale1 * to1[1],
			scale0 * z + scale1 * to1[2]
		];
		return ret;
	}
	
	void dump() {
		Stdout.format(
			"{} {} {} {}\n\n",
			w, x, y, z
		).flush();
	}
}

template QRotated() {
	Quaternion rotation;
	
	void setRotation(float heading) {
		rotation.toRotateY(heading);
	}
	
	void setRotation(float heading, float pitch) {
		Euler e;
		e.data[] = [heading, pitch, 0];
		rotation *= e;
	}
	
	void setRotation(float heading, float pitch, float bank) {
		Euler e;
		e.data[] = [heading, pitch, bank];
		rotation *= e;
	}
	
	void rotate(Euler e) {
		rotation *= e;
	}
	
	Matrix getMRotation() {
		return rotation.getMatrix();
	}
	
	Quaternion getQRotation() {
		Quaternion ret = rotation;	// make a copy
		return ret;
	}
}
