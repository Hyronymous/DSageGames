module aahz.render.Shapes;

import tango.math.Math;
import tango.io.Stdout;

import aahz.render.Model;
import aahz.math.Vector;

void createSphere(Model m, uint n) {
	void subdivideSpherical(Vector a, Vector b, Vector c, int left, int width, int n) {	// recurse, subdividing triangles
		if (n == 0) {	// If we've reached the end of a triangle, write it into the vertex array
			m.vertexes[left] = a.x;
			m.vertexes[left + 1] = a.y;
			m.vertexes[left + 2] = a.z;
			m.vertexes[left + 3] = b.x;
			m.vertexes[left + 4] = b.y;
			m.vertexes[left + 5] = b.z;
			m.vertexes[left + 6] = c.x;
			m.vertexes[left + 7] = c.y;
			m.vertexes[left + 8] = c.z;

			m.normals[left] = a.x;
			m.normals[left + 1] = a.y;
			m.normals[left + 2] = a.z;
			m.normals[left + 3] = b.x;
			m.normals[left + 4] = b.y;
			m.normals[left + 5] = b.z;
			m.normals[left + 6] = c.x;
			m.normals[left + 7] = c.y;
			m.normals[left + 8] = c.z;
			
			return;
		}
		
		Vector d = [
			(a.x + b.x) * 0.5f,
			(a.y + b.y) * 0.5f,
			(a.z + b.z) * 0.5f
		];
		d.normalize();
		
		Vector e = [
			(b.x + c.x) * 0.5f,
			(b.y + c.y) * 0.5f,
			(b.z + c.z) * 0.5f
		];
		e.normalize();
		
		Vector f = [
			(a.x + c.x) * 0.5f,
			(a.y + c.y) * 0.5f,
			(a.z + c.z) * 0.5f
		];
		f.normalize();
		
		int new_width = width / 4;
		subdivideSpherical(
			a, d, f,
			left, new_width,
			n - 1
		);
		subdivideSpherical(
			d, e, f,
			left + new_width, new_width,
			n - 1
		);
		subdivideSpherical(
			b, e, d,
			left + new_width + new_width, new_width,
			n - 1
		);
		subdivideSpherical(
			c, f, e,
			left + new_width + new_width + new_width, new_width,
			n - 1
		);
	}
			
	int modulus = n % 3;
	
	if (modulus == 0) {	// Use a tetrahedron as the base
		n /= 3;
		
		m.triangleCount = cast(int)pow(4.0L, n + 1);
		m.triangleCount9 = m.triangleCount * 9;
		m.vertexes.length = m.triangleCount9;
		m.colors.length = m.triangleCount9;
		m.normals.length = m.triangleCount9;
		
		float sqrt_3 = 0.5773502692f;
		Vector PPP = [ sqrt_3, sqrt_3, sqrt_3 ]; // +X, +Y, +Z
		Vector MMP = [ -sqrt_3, -sqrt_3, sqrt_3 ]; // -X, -Y, +Z
		Vector MPM = [ -sqrt_3, sqrt_3, -sqrt_3 ]; // -X, +Y, -Z
		Vector PMM = [ sqrt_3, -sqrt_3, -sqrt_3 ]; // +X, -Y, -Z 
		
		Vector faces[][] = [
			[ PPP, MPM, MMP ],
			[ PPP, MMP, PMM ],
			[ MPM, PMM, MMP ],
			[ PMM, MPM, PPP ] 
		];
		
		int section_width = m.triangleCount9 / 4;
		for (int L = 0; L < 4; L++) {
			subdivideSpherical(
				faces[L][0], faces[L][1], faces[L][2],
				section_width * L, section_width,
				n
			);
		}
	}
	else if (modulus == 1) {	// Use an octahedron as the base
		n /= 3;
		
		m.triangleCount = 8 * cast(int)pow(4.0L, n);
		m.triangleCount9 = m.triangleCount * 9;
		m.vertexes.length = m.triangleCount9;
		m.colors.length = m.triangleCount9;
		m.normals.length = m.triangleCount9;
		
		Vector XPLUS = [1.0f, 0.0f, 0.0f];
		Vector XMIN = [-1.0f, 0.0f, 0.0f];
		Vector YPLUS = [0.0f, 1.0f, 0.0f];
		Vector YMIN = [0.0f, -1.0f, 0.0f];
		Vector ZPLUS = [0.0f, 0.0f, 1.0f];
		Vector ZMIN = [0.0f, 0.0f, -1.0f];
		
		Vector faces[][] = [
			[XPLUS, YPLUS, ZPLUS],
			[YPLUS, XMIN, ZPLUS],
			[XMIN, YMIN, ZPLUS],
			[YMIN, XPLUS, ZPLUS],
			[XPLUS, ZMIN, YPLUS],
			[YPLUS, ZMIN, XMIN],
			[XMIN, ZMIN, YMIN],
			[YMIN, ZMIN, XPLUS],
		];
		
		int section_width = m.triangleCount9 / 8;
		for (int L = 0; L < 8; L++) {
			subdivideSpherical(
				faces[L][0], faces[L][1], faces[L][2],
				section_width * L, section_width,
				n
			);
		}
	}
	else {	// Use an icosahedron as the base
		n /= 3;
		
		m.triangleCount = 20 * cast(int)pow(4.0L, n);
		m.triangleCount9 = m.triangleCount * 9;
		m.vertexes.length = m.triangleCount9;
		m.colors.length = m.triangleCount9;
		m.normals.length = m.triangleCount9;
		
		float tau = 0.8506508084f;
		float one = 0.5257311121f;
		Vector ZA = [tau, one, 0.0f];
		Vector ZB = [-tau, one, 0.0f];
		Vector ZC = [-tau, -one, 0.0f];
		Vector ZD = [tau, -one, 0.0f];
		Vector YA = [one, 0.0f, tau];
		Vector YB = [one, 0.0f, -tau];
		Vector YC = [-one, 0.0f, -tau];
		Vector YD = [-one, 0.0f, tau];
		Vector XA = [0.0f, tau, one];
		Vector XB = [0.0f, -tau, one];
		Vector XC = [0.0f, -tau, -one];
		Vector XD = [0.0f, tau, -one];
		
		Vector[][] faces = [
			[YA, XA, YD],
			[YA, YD, XB],
			[YB, YC, XD],
			[YB, XC, YC],
			[ZA, YA, ZD],
			[ZA, ZD, YB],
			[ZC, YD, ZB],
			[ZC, ZB, YC],
			[XA, ZA, XD],
			[XA, XD, ZB],
			[XB, XC, ZD],
			[XB, ZC, XC],
			[XA, YA, ZA],
			[XD, ZA, YB],
			[YA, XB, ZD],
			[YB, ZD, XC],
			[YD, XA, ZB],
			[YC, ZB, XD],
			[YD, ZC, XB],
			[YC, XC, ZC]
		];
		
		int section_width = m.triangleCount9 / 20;
		for (int L = 0; L < 20; L++) {
			subdivideSpherical(
				faces[L][0], faces[L][1], faces[L][2],
				section_width * L, section_width,
				n
			);
		}
	}
}
