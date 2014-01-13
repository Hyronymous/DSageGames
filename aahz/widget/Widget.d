module aahz.widget.Widget;

import tango.util.container.LinkedList;
import tango.util.Convert;
import tango.io.Stdout;

import aahz.widget.WindowManager;
import aahz.widget.PositionBox;
import aahz.widget.Area;
import aahz.widget.Event;

abstract class Widget : PositionBox {
protected:
	float[] layoutHeights;
	float[][] layoutWidths;
	bool m_visible = true;
	
	Area m_drawBox;
	Area m_clipBox;

	int[] getHeights() {
		int[] ret = new int[ layoutHeights.length ];
		int absTotal = 0;
		float pTotal = 0;
		
		for (uint L = 0; L < layoutHeights.length; L++) {
			if (layoutHeights[L] > 0.100f) {	// pixel value
				absTotal += layoutHeights[L];
			}
			else {	// percentile
				pTotal += layoutHeights[L];
			}
		}
		
		for (uint L = 0; L < layoutHeights.length; L++) {
			if (layoutHeights[L] > 0.100f) {	// pixel value
				ret[L] = to!(int)(layoutHeights[L]);
			}
			else {	// percentile
				ret[L] = to!(int)(
					cast(float)m_drawBox.height
					* (layoutHeights[L] / pTotal)
					- absTotal
				);
			}
		}
		
		return ret;
	}
	
	int[] getWidths(uint row) {
		int[] ret = new int[ layoutWidths[row].length ];
		int absTotal = 0;
		float pTotal = 0;
		
		for (uint L = 0; L < layoutWidths[row].length; L++) {
			if (layoutWidths[row][L] > 0.100f) {	// pixel value
				absTotal += layoutWidths[row][L];
			}
			else {	// percentile
				pTotal += layoutWidths[row][L];
			}
		}
		
		for (uint L = 0; L < layoutWidths[row].length; L++) {
			if (layoutWidths[row][L] > 0.100f) {	// pixel value
				ret[L] = to!(int)(layoutWidths[row][L]);
			}
			else {	// percentile
				ret[L] = to!(int)(
					cast(float)m_drawBox.width
					* (layoutWidths[row][L] / pTotal)
					- absTotal
				);
			}
		}
		
		return ret;
	}
	
public:
	LinkedList!(Widget)[][] children;
	Widget parent = null;
	
	bool visible(bool yn) {
		m_visible = yn;
		return yn;
	}
	
	bool visible() {
		return m_visible;
	}
	
	void reskin() {
		for (uint L = 0; L < children.length; L++) for (uint L2 = 0; L2 < children[L].length; L2++) {
			foreach (w; children[L][L2]) {
				w.reskin();
			}
		}
	}
	
	Area drawBox() {
		return m_drawBox;
	}
	
	Area clipBox() {
		return m_clipBox;
	}
	
	final void add(size_t column, size_t row, Widget child) {
		child.parent = this;
		children[row][column].append(child);
	}
	
	void remove(size_t column, size_t row, Widget child) {
		child.parent = null;
		children[row][column].remove(child);
	}
	
	void setLayout(float[] heights, float[][] widths) {	// clears old layout and removes all children	// Should be overloaded by anyone who doesn't want it optional
		if (heights.length != widths.length) throw new Exception("Mismatched row counts");
		
		for (uint L = 0; L < layoutWidths.length; L++) {	// Clear the old
			layoutWidths[L].length = 0;
			children[L].length = 0;
		}
		layoutWidths.length = heights.length;
		children.length = heights.length;
		
		layoutHeights = heights.dup;
		for (uint L = 0; L < widths.length; L++) {
			layoutWidths[L] = widths[L].dup;
			
			children[L].length = widths[L].length;
			for (uint L2 = 0; L2 < children[L].length; L2++) {
				children[L][L2] = new LinkedList!(Widget);
			}
		}
	}
	
	void updateLayout(float[] heights, float[][] widths) {	// Resizes rows and columns, but does not change the number of rows or columns and leaves children were they are
		if (heights.length != widths.length) throw new Exception("Mismatched row counts");
		if (heights.length != layoutHeights.length) throw new Exception("Cannot change row or column counts via updateLayout()");
		for (uint L = 0; L < layoutWidths.length; L++) {
			if (layoutWidths[L].length != widths[L].length) throw new Exception("Cannot change row or column counts via updateLayout()");
		}
		
		for (uint L = 0; L < widths.length; L++) {
			layoutHeights[L] = heights[L];
			
			for (uint L2 = 0; L2 < widths[L].length; L2++) {
				layoutWidths[L][L2] = widths[L][L2];
			}
		}
	}
	
	void updatePosition(Area pBox, Area pClip) {
		Area cell, cellClip;
		
		toArea(pBox, m_drawBox);	// Get my draw area relative to my parent
		m_clipBox.set(m_drawBox);	// Copy into clip area
		m_clipBox.overlap(pClip);	// shrink clip area to fit in parent's
		if (m_clipBox.isZero()) return;	// Nothing to draw

		int[] heights = getHeights();
		
		cell.bottom = m_drawBox.bottom + m_drawBox.height;
		for (uint L = 0; L < heights.length; L++) {
			int[] widths = getWidths(L);
			cell.left = m_drawBox.left;
			cell.bottom -= heights[L];
			cell.height = heights[L];
			
			for (uint L2 = 0; L2 < widths.length; L2++) {
				cell.width = widths[L2];
				
				cellClip.set(cell);
				cellClip.overlap(m_clipBox);
				if (!cellClip.isZero()) {
					foreach (w; children[L][L2]) {
						w.updatePosition(cell, cellClip);
					}
				}
				
				cell.left += widths[L2];
			}
		}
	}
	
	void update() {
		for (uint L = 0; L < children.length; L++) {
			for (uint L2 = 0; L2 < children[L].length; L2++) {
				foreach (w; children[L][L2]) {
					w.update();
				}
			}
		}
	}
	
	void paint() {
		for (uint L = 0; L < children.length; L++) {
			for (uint L2 = 0; L2 < children[L].length; L2++) {
				foreach (w; children[L][L2]) {
					if (
						w.visible
						&& m_clipBox.width > 0
						&& m_clipBox.height > 0
					) {
						w.paint();
					}
				}
			}
		}
	}
	
	void event(Event e) {}
}
