module aahz.draw.Color;

union Color4f {
	struct {
		float r, g, b, a;
	}
	float[4] data;
	
	void set(float _r, float _g, float _b, float _a = 1.0f) {
		r = _r;
		g = _g;
		b = _b;
		a = _a;
	}
	
	void set(ubyte _r, ubyte _g, ubyte _b, ubyte _a = 0xff) {
		r = cast(float)_r / cast(float)0xff;
		g = cast(float)_g / cast(float)0xff;
		b = cast(float)_b / cast(float)0xff;
		a = cast(float)_a / cast(float)0xff;
	}
	
	void opAssign(Color3f c) {
		r = c.r;
		g = c.g;
		b = c.b;
		a = 1.0f;
	}
	
	void opAssign(Color4ub c) {
		r = cast(float)c.r / cast(float)0xff;
		g = cast(float)c.g / cast(float)0xff;
		b = cast(float)c.b / cast(float)0xff;
		a = cast(float)c.a / cast(float)0xff;
	}
	
	void opAssign(Color3ub c) {
		r = cast(float)c.r / cast(float)0xff;
		g = cast(float)c.g / cast(float)0xff;
		b = cast(float)c.b / cast(float)0xff;
		a = 1.0f;
	}
}

union Color3f {
	struct {
		float r, g, b;
	}
	float[3] data;
	
	void set(float _r, float _g, float _b) {
		r = _r;
		g = _g;
		b = _b;
	}
	
	void set(ubyte _r, ubyte _g, ubyte _b) {
		r = cast(float)_r / cast(float)0xff;
		g = cast(float)_g / cast(float)0xff;
		b = cast(float)_b / cast(float)0xff;
	}
	
	void opAssign(Color4f c) {
		r = c.r;
		g = c.g;
		b = c.b;
	}
	
	void opAssign(Color4ub c) {
		r = cast(float)c.r / cast(float)0xff;
		g = cast(float)c.g / cast(float)0xff;
		b = cast(float)c.b / cast(float)0xff;
	}
	
	void opAssign(Color3ub c) {
		r = cast(float)c.r / cast(float)0xff;
		g = cast(float)c.g / cast(float)0xff;
		b = cast(float)c.b / cast(float)0xff;
	}
}

union Color4ub {
	struct {
		ubyte r, g, b, a;
	}
	ubyte[4] data;
	
	void set(ubyte _r, ubyte _g, ubyte _b, ubyte _a = 0xff) {
		r = _r;
		g = _g;
		b = _b;
		a = _a;
	}
	
	void set(float _r, float _g, float _b, float _a = 1.0f) {
		r = cast(ubyte)(_r * 0xff);
		g = cast(ubyte)(_g * 0xff);
		b = cast(ubyte)(_b * 0xff);
		a = cast(ubyte)(_a * 0xff);
	}
	
	void opAssign(Color3f c) {
		r = cast(ubyte)(c.r * 0xff);
		g = cast(ubyte)(c.g * 0xff);
		b = cast(ubyte)(c.b * 0xff);
		a = cast(ubyte)0xff;
	}
	
	void opAssign(Color4f c) {
		r = cast(ubyte)(c.r * 0xff);
		g = cast(ubyte)(c.g * 0xff);
		b = cast(ubyte)(c.b * 0xff);
		a = cast(ubyte)(c.a * 0xff);
	}
	
	void opAssign(Color3ub c) {
		r = c.r;
		g = c.g;
		b = c.b;
		a = cast(ubyte)0xff;
	}
}

union Color3ub {
	struct {
		ubyte r, g, b;
	}
	ubyte[3] data;
	
	void set(ubyte _r, ubyte _g, ubyte _b) {
		r = _r;
		g = _g;
		b = _b;
	}
	
	void set(float _r, float _g, float _b) {
		r = cast(ubyte)(_r * 0xff);
		g = cast(ubyte)(_g * 0xff);
		b = cast(ubyte)(_b * 0xff);
	}
}
