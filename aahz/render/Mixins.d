module aahz.render.Mixins;

import aahz.math.Vector;
import aahz.math.Euler;
import aahz.math.Matrix;
import aahz.math.Quaternion;

template FScaled() {
	float scale = 1.0;
	
	void setScale(float ratio) {
		this.scale = ratio;
	}
	
	float getScale() {
		return scale;
	}
}

template QSituated() {
	mixin VPositioned;
	mixin QRotated;
	
	Matrix getMatrix() {
		Matrix ret = rotation.getMatrix();
		ret.setTranslation(position);
		return ret;
	}
}

template ESituated() {
	mixin VPositioned;
	mixin ERotated;
	
	Matrix getMatrix() {
		Matrix ret = rotation.getMatrix();
		ret.setTranslation(position);
		return ret;
	}
}

template MSituated() {
	mixin VPositioned;
	mixin MRotated;
	
	Matrix getMatrix() {
		Matrix ret = rotation;
		ret.setTranslation(position);
		return ret;
	}
}

template QTransformed() {
	mixin VPositioned;
	mixin QRotated;
	mixin FScaled;
	
	Matrix getMatrix() {
		Matrix ret;
		ret.setScale(scale);
		ret.setTranslation(position);
		ret >>= rotation.getMatrix();
		return ret;
	}
}

template ETransformed() {
	mixin VPositioned;
	mixin ERotated;
	mixin FScaled;
	
	Matrix getMatrix() {
		Matrix ret;
		ret.setScale(scale);
		ret.setTranslation(position);
		ret >>= rotation.getMatrix();
		return ret;
	}
}

template MTransformed() {
	mixin VPositioned;
	mixin MRotated;
	mixin FScaled;
	
	Matrix getMatrix() {
		Matrix ret;
		ret.setScale(scale);
		ret.setTranslation(position);
		ret >>= rotation;
		return ret;
	}
}
