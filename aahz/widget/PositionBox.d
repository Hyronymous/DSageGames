module aahz.widget.PositionBox;

import tango.util.Convert;
import tango.text.Util;
import tango.text.Text;
import tango.io.Stdout;
import aahz.widget.Area;

enum Alignment {
	LEFT,
	RIGHT,
	TOP,
	BOTTOM,
	HCENTER,
	VCENTER
}

enum Comparator {
	ABSOLUTE,
	RELATIVE,
	ADDITIVE
}

enum Side {
	LEFT = 0,
	RIGHT = 1,
	TOP = 2,
	BOTTOM = 3
}

class PositionBox {
private:
	struct Offset {
		Alignment anchor;
		Comparator comp;
		float amount;
		
		void set(Comparator c, Alignment a, float f) {
			if (c == Comparator.ADDITIVE) throw new Exception("Offsets may not be additive.");
			
			comp = c;
			anchor = a;
			amount = f;
		}
		
		void add(float bound, float value) {
			switch (comp) {
			case Comparator.ABSOLUTE:
				amount += value;
			break;
			case Comparator.RELATIVE:
				amount += value / bound;
			break;
			}
		}
		
		float get(float p_x, float p_width, float my_width) {	// Could be width or height, but these names are easier to think about abstractly
			switch (comp) {
			case Comparator.ABSOLUTE:
				switch (anchor) {
				case Alignment.BOTTOM:
				case Alignment.LEFT:
					return p_x + amount;
				break;
				case Alignment.VCENTER:
				case Alignment.HCENTER:
					return p_x + ((p_width - my_width) / 2.0f) + amount;
				break;
				case Alignment.TOP:
				case Alignment.RIGHT:
					return p_x + p_width - my_width + amount;
				break;
				}
			break;
			case Comparator.RELATIVE:
				switch (anchor) {
				case Alignment.BOTTOM:
				case Alignment.LEFT:
					return p_x + (amount * p_width);
				break;
				case Alignment.VCENTER:
				case Alignment.HCENTER:
					return p_x + ((p_width - my_width) / 2.0f) + (amount * p_width);
				break;
				case Alignment.TOP:
				case Alignment.RIGHT:
					return p_x + p_width - my_width + (amount * p_width);
				break;
				}
			break;
			}
		}
	}

	struct Distance {
		Comparator comp;
		float amount;
		
		void set(Comparator c, float f) {
			comp = c;
			amount = f;
		}
		
		float abs(float bound) {
			switch (comp) {
			case Comparator.ABSOLUTE:
				return (amount);
			break;
			case Comparator.ADDITIVE:
				return (bound + amount);
			break;
			case Comparator.RELATIVE:
				return (amount * bound);
			break;
			}
		}
		
		void add(float bound, float value) {
			switch (comp) {
			case Comparator.ABSOLUTE:
			case Comparator.ADDITIVE:
				amount += value;
			break;
			case Comparator.RELATIVE:
				amount += value / bound;
			break;
			}
		}
	}
	
	Offset m_h, m_v;
	Distance m_width, m_height;
	Distance m_minWidth, m_maxWidth, m_minHeight, m_maxHeight;
	
	float adjustH = 0.0f, adjustV = 0.0f;
	float[4] adjustSide;
	
	float doAdjustSide(Side s, Area a) {
		bool h = true;
		float adjust;
		float ret;
		
		switch (s) {
		case Side.LEFT:
			adjust = -adjustSide[s];	// positive values shrink it
		break;
		case Side.RIGHT:
			adjust = adjustSide[s];	// positive values expand it
		break;
		case Side.TOP:
			h = false;
			adjust = adjustSide[s];	// positive values expand it
		break;
		case Side.BOTTOM:
			h = false;
			adjust = -adjustSide[s];	// positive values shrink it
		break;
		}
		ret = adjust;	// assume that we'll be able to adjust by 100%
		
		if (h) {	// modify width
			float absWidth = m_width.abs(a.width);
			float absMinWidth = m_minWidth.abs(a.width);
			float absMaxWidth = m_maxWidth.abs(a.width);
			
			if ((absWidth + adjust) < absMinWidth) {	// Too much! (adjust will be negative)
				ret = absWidth - absMinWidth;	// grab the difference
				m_width.add(a.width, ret);	// change it to exactly the difference
			}
			else if ((absWidth + adjust) > absMaxWidth) {	// Too much! (adjust will be positive)
				ret = absMaxWidth - absWidth;	// grab the difference
				m_width.add(a.width, ret);	// change it to exactly the difference
			}
			else {	// fits
				m_width.add(a.width, adjust);
			}
		}
		else {	// modify height
			float absHeight = m_height.abs(a.height);
			float absMinHeight = m_minHeight.abs(a.height);
			float absMaxHeight = m_maxHeight.abs(a.height);
			
			if ((absHeight + adjust) < absMinHeight) {	// Too much! (adjust will be negative)
				ret = absMinHeight - absHeight;	// grab the difference
				m_height.add(a.height, ret);	// change it to exactly the difference
			}
			else if ((absHeight + adjust) > absMaxHeight) {	// Too much! (adjust will be positive)
				ret = absMaxHeight - absHeight;	// grab the difference
				m_height.add(a.height, ret);	// change it to exactly the difference
			}
			else {	// fits
				m_height.add(a.height, adjust);
			}
		}
		
		return ret;
	}
	
public:
	this() {
		m_h.set(Comparator.ABSOLUTE, Alignment.LEFT, 0.0f);
		m_v.set(Comparator.ABSOLUTE, Alignment.BOTTOM, 0.0f);
		m_width.set(Comparator.ABSOLUTE, 1.0f);
		m_height.set(Comparator.ABSOLUTE, 1.0f);
		
		m_minWidth.set(Comparator.ABSOLUTE, 1.0f);
		m_maxWidth.set(Comparator.ABSOLUTE, 50_000.0f);
		m_minHeight.set(Comparator.ABSOLUTE, 1.0f);
		m_maxHeight.set(Comparator.ABSOLUTE, 50_000.0f);
		
		adjustSide[] = 0.0f;
	}
	
	void toArea(Area bounds, out Area ret) {
		scope (exit) {
			adjustH = 0;
			adjustV = 0;
			adjustSide[] = 0;
		}
		float adjusted;
		
		// do width adjusts
		if (adjustSide[Side.LEFT] != 0) {
			adjusted = doAdjustSide(Side.LEFT, bounds);	// attempts to modify width/height while respecting min/max values. Returns the amount that the side actually changed
			switch (m_h.anchor) {
			case Alignment.LEFT:
				adjustH -= adjusted;
			break;
			case Alignment.HCENTER:
				adjustH -= (adjusted / 2.0f);
			break;
			case Alignment.RIGHT:
			break;
			}
		}
		if (adjustSide[Side.RIGHT] != 0) {
			adjusted = doAdjustSide(Side.RIGHT, bounds);
			switch (m_h.anchor) {
			case Alignment.LEFT:
			break;
			case Alignment.HCENTER:
				adjustH += (adjusted / 2.0f);
			break;
			case Alignment.RIGHT:
				adjustH += adjusted;
			break;
			}
		}
		if (adjustSide[Side.BOTTOM] != 0) {
			adjusted = doAdjustSide(Side.BOTTOM, bounds);
			switch (m_v.anchor) {
			case Alignment.BOTTOM:
				adjustV -= adjusted;
			break;
			case Alignment.VCENTER:
				adjustV -= (adjusted / 2.0f);
			break;
			case Alignment.TOP:
			break;
			}
		}
		if (adjustSide[Side.TOP] != 0) {
			adjusted = doAdjustSide(Side.TOP, bounds);
			switch (m_v.anchor) {
			case Alignment.BOTTOM:
			break;
			case Alignment.VCENTER:
				adjustV += (adjusted / 2.0f);
			break;
			case Alignment.TOP:
				adjustV += adjusted;
			break;
			}
		}
		
		// grab the width/height, modifying to fit into min/max. Can be over due to other issues than because of size adjustment
		
		float absWidth = m_width.abs(bounds.width);
		float absMinWidth = m_minWidth.abs(bounds.width);
		float absMaxWidth = m_maxWidth.abs(bounds.width);
		
		float absHeight = m_height.abs(bounds.height);
		float absMinHeight = m_minHeight.abs(bounds.height);
		float absMaxHeight = m_maxHeight.abs(bounds.height);
		
		if (absWidth < absMinWidth) ret.width = to!(int)(absMinWidth);
		else if (absWidth > absMaxWidth) ret.width = to!(int)(absMaxWidth);
		else ret.width = to!(int)(absWidth);
		
		if (absHeight < absMinHeight) ret.height = to!(int)(absMinHeight);
		else if (absHeight > absMaxHeight) ret.height = to!(int)(absMaxHeight);
		else ret.height = to!(int)(absHeight);
		
		// Grab the h and v, modifying by adjusts
		
		m_h.add(cast(float)bounds.width, adjustH);
		m_v.add(cast(float)bounds.height, adjustV);
		
		ret.left = to!(int)(
			m_h.get(cast(float)bounds.left, cast(float)bounds.width, cast(float)ret.width)
		);
		ret.bottom = to!(int)(
			m_v.get(cast(float)bounds.bottom, cast(float)bounds.height, cast(float)ret.height)
		);
	}

	static void parseH(char[] text, out Comparator comp, out Alignment hAlign, out float h) {
		char[][] data = split!(char)(text, ":");
		if (data.length != 2) throw new Exception("Invalid data");
		
		auto left = new Text!(char)("left");
		auto center = new Text!(char)("center");
		auto right = new Text!(char)("right");

		if (left.equals(data[0])) {
			if (data[1][$-1] == '%') {
				data[1].length = data[1].length - 1;

				comp = Comparator.RELATIVE;
				hAlign = Alignment.LEFT;
				h = to!(float)(data[1]) / 100.0f;
			}
			else {
				comp = Comparator.ABSOLUTE;
				hAlign = Alignment.LEFT;
				h = to!(float)(data[1]);
			}
		}
		else if (center.equals(data[0])) {
			if (data[1][$-1] == '%') {
				data[1].length = data[1].length - 1;

				comp = Comparator.RELATIVE;
				hAlign = Alignment.HCENTER;
				h = to!(float)(data[1]) / 100.0f;
			}
			else {
				comp = Comparator.ABSOLUTE;
				hAlign = Alignment.HCENTER;
				h = to!(float)(data[1]);
			}
		}
		else if (right.equals(data[0])) {
			if (data[1][$-1] == '%') {
				data[1].length = data[1].length - 1;

				comp = Comparator.RELATIVE;
				hAlign = Alignment.RIGHT;
				h = to!(float)(data[1]) / 100.0f;
			}
			else {
				comp = Comparator.ABSOLUTE;
				hAlign = Alignment.RIGHT;
				h = to!(float)(data[1]);
			}
		}
		else {
			throw new Exception("Invalid data");
		}
	}
	
	static void parseV(char[] text, out Comparator comp, out Alignment vAlign, out float v) {
		char[][] data = split!(char)(text, ":");
		if (data.length != 2) throw new Exception("Invalid data");
		
		auto bottom = new Text!(char)("bottom");
		auto center = new Text!(char)("center");
		auto top = new Text!(char)("top");
		
		if (bottom.equals(data[0])) {
			if (data[1][$-1] == '%') {
				data[1].length = data[1].length - 1;

				comp = Comparator.RELATIVE;
				vAlign = Alignment.BOTTOM;
				v = to!(float)(data[1]) / 100.0f;
			}
			else {
				comp = Comparator.ABSOLUTE;
				vAlign = Alignment.BOTTOM;
				v = to!(float)(data[1]);
			}
		}
		else if (center.equals(data[0])) {
			if (data[1][$-1] == '%') {
				data[1].length = data[1].length - 1;

				comp = Comparator.RELATIVE;
				vAlign = Alignment.VCENTER;
				v = to!(float)(data[1]) / 100.0f;
			}
			else {
				comp = Comparator.ABSOLUTE;
				vAlign = Alignment.VCENTER;
				v = to!(float)(data[1]);
			}
		}
		else if (top.equals(data[0])) {
			if (data[1][$-1] == '%') {
				data[1].length = data[1].length - 1;

				comp = Comparator.RELATIVE;
				vAlign = Alignment.TOP;
				v = to!(float)(data[1]) / 100.0f;
			}
			else {
				comp = Comparator.ABSOLUTE;
				vAlign = Alignment.TOP;
				v = to!(float)(data[1]);
			}
		}
		else {
			throw new Exception("Invalid data");
		}
	}
	
	static void parseWidth(char[] text, out Comparator comp, out float f) {
		char[] temp = text.dup;
		if (temp[$-1] == '%') {
			temp.length = temp.length - 1;
			comp = Comparator.RELATIVE;
			f = to!(float)(temp) / 100.0f;
		}
		else if (temp[0] == '+' || temp[0] == '-') {
			comp = Comparator.ADDITIVE;
			f = to!(float)(temp);
		}
		else {
			comp = Comparator.ABSOLUTE;
			f = to!(float)(temp);
		}
	}
	
	static void parseHeight(char[] text, out Comparator comp, out float f) {
		char[] temp = text.dup;
		if (temp[$-1] == '%') {
			temp.length = temp.length - 1;
			comp = Comparator.RELATIVE;
			f = to!(float)(temp) / 100.0f;
		}
		else if (temp[0] == '+' || temp[0] == '-') {
			comp = Comparator.ADDITIVE;
			f = to!(float)(temp);
		}
		else {
			comp = Comparator.ABSOLUTE;
			f = to!(float)(temp);
		}
	}

	void setH(char[] text) {
		Comparator comp;
		Alignment hAlign;
		float f;
		
		parseH(text, comp, hAlign, f);
		setH(comp, hAlign, f);
	}

	void setV(char[] text) {
		Comparator comp;
		Alignment vAlign;
		float f;
		
		parseV(text, comp, vAlign, f);
		setV(comp, vAlign, f);
	}
	
	void setWidth(char[] text) {
		Comparator comp;
		float f;
		
		parseWidth(text, comp, f);
		setWidth(comp, f);
	}
	
	void setMinWidth(char[] text) {
		Comparator comp;
		float f;
		
		parseWidth(text, comp, f);
		setMinWidth(comp, f);
	}
	
	void setMaxWidth(char[] text) {
		Comparator comp;
		float f;
		
		parseWidth(text, comp, f);
		setMaxWidth(comp, f);
	}
	
	void setHeight(char[] text) {
		Comparator comp;
		float f;
		
		parseHeight(text, comp, f);
		setHeight(comp, f);
	}
	
	void setMinHeight(char[] text) {
		Comparator comp;
		float f;
		
		parseHeight(text, comp, f);
		setMinHeight(comp, f);
	}
	
	void setMaxHeight(char[] text) {
		Comparator comp;
		float f;
		
		parseHeight(text, comp, f);
		setMaxHeight(comp, f);
	}

	void setH(Comparator comp, Alignment a, float value) {
		m_h.set(comp, a, value);
	}
	
	void setV(Comparator comp, Alignment a, float value) {
		m_v.set(comp, a, value);
	}
	
	void setWidth(Comparator comp, float value) {
		if (value == 0.0f) throw new Exception("Width cannot be 0");
		else if (value < 0 && comp != Comparator.ADDITIVE) throw new Exception("Width cannot be negative unless ADDITIVE");
		
		m_width.set(comp, value);
	}
	
	void setMinWidth(Comparator comp, float value) {
		if (value == 0.0f) throw new Exception("Width cannot be 0");
		else if (value < 0 && comp != Comparator.ADDITIVE) throw new Exception("Width cannot be negative unless ADDITIVE");
		
		m_minWidth.set(comp, value);
	}
	
	void setMaxWidth(Comparator comp, float value) {
		if (value == 0.0f) throw new Exception("Width cannot be 0");
		else if (value < 0 && comp != Comparator.ADDITIVE) throw new Exception("Width cannot be negative unless ADDITIVE");
		
		m_maxWidth.set(comp, value);
	}
	
	void setHeight(Comparator comp, float value) {
		if (value == 0.0f) throw new Exception("Height cannot be 0");
		else if (value < 0 && comp != Comparator.ADDITIVE) throw new Exception("Height cannot be negative unless ADDITIVE");
		
		m_height.set(comp, value);
	}
	
	void setMinHeight(Comparator comp, float value) {
		if (value == 0.0f) throw new Exception("Height cannot be 0");
		else if (value < 0 && comp != Comparator.ADDITIVE) throw new Exception("Height cannot be negative unless ADDITIVE");
		
		m_minHeight.set(comp, value);
	}
	
	void setMaxHeight(Comparator comp, float value) {
		if (value == 0.0f) throw new Exception("Height cannot be 0");
		else if (value < 0 && comp != Comparator.ADDITIVE) throw new Exception("Height cannot be negative unless ADDITIVE");
		
		m_maxHeight.set(comp, value);
	}

	void situate(char[] h, char[] v, char[] width, char[] height) {
		setH(h);
		setV(v);
		setWidth(width);
		setHeight(height);
	}
	
	void situate(
		Comparator hC, Alignment hA, float h,
		Comparator vC, Alignment vA, float v,
		Comparator widthC, float width,
		Comparator heightC, float height
	) {
		setH(hC, hA, h);
		setV(vC, vA, v);
		setWidth(widthC, width);
		setHeight(heightC, height);
	}
	
	void move(int diffX, int diffY) {
		adjustH += diffX;
		adjustV += diffY;
	}
	
	void dragSide(Side side, int amount) {	// positive = up/right, negative = down/left
		adjustSide[side] += amount;
	}
}
