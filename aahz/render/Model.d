module aahz.render.Model;

import aahz.render.Interfaces;
import aahz.render.Mixins;
import aahz.math.Vector;
import aahz.math.Euler;
import aahz.math.Matrix;
import aahz.math.Quaternion;

class Model : IBase {
public:
	int triangleCount = 0;
	int triangleCount9 = 0;	// three values per each point in a triangle
	float[] vertexes;
	float[] colors;
	float[] normals;
	
	float[4] specular_level = [1.0f, 1.0f, 1.0f, 1.0f];
	float shininess_level = 50.0f;
	
	mixin QTransformed;
	
	void setColor(float r, float g, float b)
	in {
		assert(colors.length == triangleCount9);	// Colors isn't guaranteed to be set
	}
	body {
		for (int L = 0; L < triangleCount9; L += 9) {
			colors[L] = r;
			colors[L + 1] = g;
			colors[L + 2] = b;
			
			colors[L + 3] = r;
			colors[L + 4] = g;
			colors[L + 5] = b;
			
			colors[L + 6] = r;
			colors[L + 7] = g;
			colors[L + 8] = b;
		}
	}
}
