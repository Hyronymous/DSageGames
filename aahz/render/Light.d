module aahz.render.Light;

import derelict.opengl.gl;

import aahz.render.Interfaces;
import aahz.render.Mixins;
import aahz.math.Vector;
import aahz.math.Euler;
import aahz.math.Matrix;
import aahz.math.Quaternion;
import aahz.draw.Color;

enum LightType {
	AMBIENT,
	DIFFUSE,
	SPECULAR,
	SPOT
}

class Light : IBase {
public:
	LightType type;
	Color4f ambientColor;
	Color4f diffuseColor;
	
	static const int MAX_LIGHTS = GL_MAX_LIGHTS;
	
	mixin QSituated;
	
	this(LightType type = LightType.AMBIENT) {
		this.type = type;
		
		ambientColor.set(0.0f, 0.0f, 0.0f);
		diffuseColor.set(1.0f, 1.0f, 1.0f);
	}
}
