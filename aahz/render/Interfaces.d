module aahz.render.Interfaces;

import aahz.math.Matrix;
import aahz.math.Quaternion;
import aahz.math.Vector;
import aahz.math.Euler;

interface IBase {
	Matrix getMatrix();
}

interface IPositionable : IBase {
	void setPosition(float x, float y, float z);
	void setPosition(Vector p);
	Vector getPosition();
}

interface IRotatable : IBase {
	void setRotation(float heading);
	void setRotation(float heading, float pitch);
	void setRotation(float heading, float pitch, float bank);
	
	void rotate(Euler e);
	
	Matrix getMRotation();
	Quaternion getQRotation();
}

interface IScalable : IBase {
	void setScale(float ratio);
	float getScale();
}

interface ISituatable : IPositionable, IRotatable {}
interface ITransformable : IPositionable, IRotatable, IScalable {}
