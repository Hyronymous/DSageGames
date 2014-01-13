module aahz.math.Math;

import tango.math.Math;

import aahz.math.Vector;
import aahz.math.Matrix;

float toMillimeters(float length) {
	return length * 304.8009f;
}

float toCentimeters(float length) {
	return length * 30.48009f;
}

float toInches(float length) {
	return length * 12.0f;
}

float toFeet(float length) {
	return length;
}

float toMeters(float length) {
	return length * 0.3048009f;
}

float toKilometers(float length) {
	return length * 0.0003048009f;
}

float toMiles(float length) {
	return length * 0.0001893939f;
}

float fromMillimeters(float length) {
	return length / 304.8009f;
}

float fromCentimeters(float length) {
	return length / 30.48009f;
}

float fromInches(float length) {
	return length / 12.0f;
}

float fromFeet(float length) {
	return length;
}

float fromMeters(float length) {
	return length / 0.3048009f;
}

float fromKilometers(float length) {
	return length / 0.0003048009f;
}

float fromMiles(float length) {
	return length / 0.0001893939f;
}

Vector cross(Vector a, Vector b) {
	Vector ret = [
		a.y * b.z - b.y * a.z,
		a.z * b.x - b.z * a.x,
		a.x * b.y - b.x * a.y
	];
	return ret;
}

float dot(Vector a, Vector b) {
	return a.x * b.x + a.y * b.y + a.z * b.z;
}

float distance(Vector a, Vector b) {
	float diff_x = b.x - a.x;
	float diff_y = b.y - a.y;
	float diff_z = b.z - a.z;
	return sqrt(
		diff_x * diff_x
		+ diff_y * diff_y
		+ diff_z * diff_z
	);
}

/**
* Determines the sphere defined by the points a, b, c, and d, and then returns whether p is contained by that sphere.
* 
* @param a One of four points that defines a sphere
* @param b One of four points that defines a sphere
* @param c One of four points that defines a sphere
* @param d One of four points that defines a sphere
* @param p Point to test for containment
* @return true if p is within the bounding sphere, otherwise false
*/
bool contains(Vector a, Vector b, Vector c, Vector d, Vector p) {
	Matrix m;
	
	float temp_b_x = b.x - a.x;	// move the origin to "a"
	float temp_b_y = b.y - a.y;
	float temp_b_z = b.z - a.z;
	
	float temp_c_x = c.x - a.x;
	float temp_c_y = c.y - a.y;
	float temp_c_z = c.z - a.z;
	
	float temp_d_x = d.x - a.x;
	float temp_d_y = d.y - a.y;
	float temp_d_z = d.z - a.z;
	
	float cross_x = temp_b_y * temp_c_z - temp_b_z * temp_c_y;	// find the cross product (the normal)
	float cross_y = temp_b_z * temp_c_x - temp_b_x * temp_c_z;
	float cross_z = temp_b_x * temp_c_y - temp_b_y * temp_c_x;
	
	float distance =	// treat the normal as a plane and test for the distance from the plane to d
		cross_x * temp_d_x
		+ cross_y * temp_d_y
		+ cross_z * temp_d_z
	;
	
	m.m11 = a.x - p.x;
	m.m21 = a.y - p.y;
	m.m31 = a.z - p.z;
	m.m41 =
		m.m11 * m.m11
		+ m.m21 * m.m21
		+ m.m31 * m.m31
	;

	m.m12 = b.x - p.x;
	m.m22 = b.y - p.y;
	m.m32 = b.z - p.z;
	m.m42 =
		m.m12 * m.m12
		+ m.m22 * m.m22
		+ m.m32 * m.m32
	;

	m.m13 = c.x - p.x;
	m.m23 = c.y - p.y;
	m.m33 = c.z - p.z;
	m.m43 =
		m.m13 * m.m13
		+ m.m23 * m.m23
		+ m.m33 * m.m33
	;

	m.m14 = d.x - p.x;
	m.m24 = d.y - p.y;
	m.m34 = d.z - p.z;
	m.m44 =
		m.m14 * m.m14
		+ m.m24 * m.m24
		+ m.m34 * m.m34
	;
	
	if (distance > 0) {
		return m.getDeterminant4() < 0;
	}
	else {
		return m.getDeterminant4() > 0;
	}
}
