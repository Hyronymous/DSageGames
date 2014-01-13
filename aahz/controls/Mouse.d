module aahz.controls.Mouse;

class Mouse {
public:
	static int prevX, prevY;
	static int x, y;
	static int diffX, diffY;
	static bool[ ubyte.max ] keyDown;
	static bool[ ubyte.max ] dragging;
}
