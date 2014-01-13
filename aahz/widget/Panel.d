module aahz.widget.Panel;

import tango.io.Stdout;

import aahz.widget.Viewport;
import aahz.widget.Widget;
import aahz.widget.Event;
import aahz.draw.Graphics;
import aahz.draw.Color;

class Panel : Widget {
private:
	Color4ub m_color;
	
public:
	this() {
		m_color.set(cast(ubyte)0xff, cast(ubyte)0xff, cast(ubyte)0xff, cast(ubyte)0xff);	// white
	}

	void setColor(ubyte r, ubyte g, ubyte b, ubyte a = 0xff) {
		m_color.set(r, g, b, a);
	}

	void paint() {
		if (m_color.a != 0) {	// No need to draw a transparent square
			scope Graphics g = new Graphics(m_drawBox);
			Viewport.do2D(m_clipBox);
			
			g.setColor(m_color);
			g.fillSquare(0, 0, m_drawBox.width, m_drawBox.height);
		}
		
		super.paint();
	}
}
