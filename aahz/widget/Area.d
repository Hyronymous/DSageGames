module aahz.widget.Area;

import tango.io.Stdout;

struct Area {
	int left, bottom, width, height;
	
	void set(Area b) {
		left = b.left;
		bottom = b.bottom;
		width = b.width;
		height = b.height;
	}
	
	void overlap(Area b) {
		if (left < b.left) {
			if ((left + width) <= b.left) {	// -- |    |
				zero();
				return;
			}
			else if ((left + width) <= (b.left + b.width)) {	// --|--   |
				width -= b.left - left;
				left = b.left;
			}
			else {	// --|---|--
				width = b.width;
				left = b.left;
			}
		}
		else {
			if (left >= (b.left + b.width)) {	// |    | --
				zero();
				return;
			}
			else if ((left + width) > (b.left + b.width)) {	// |  --|--
				width = (b.left + b.width) - left;
			}
			// else, do nothing | -- |
		}
		
		if (bottom < b.bottom) {
			if ((bottom + height) <= b.bottom) {	// -- |    |
				zero();
				return;
			}
			else if ((bottom + height) <= (b.bottom + b.height)) {	// --|--   |
				height -= b.bottom - bottom;
				bottom = b.bottom;
			}
			else {	// --|---|--
				height = b.height;
				bottom = b.bottom;
			}
		}
		else {
			if (bottom >= (b.bottom + b.height)) {	// |    | --
				zero();
				return;
			}
			else if ((bottom + height) > (b.bottom + b.height)) {	// |  --|--
				height = (b.bottom + b.height) - bottom;
			}
			// else, do nothing | -- |
		}
	}
	
	void zero() {
		bottom = left = width = height = 0;
	}
	
	bool isZero() {
		return width == 0 || height == 0;
	}
}
