module aahz.widget.Button;

import aahz.widget.Widget;
import aahz.widget.Event;
import aahz.widget.Viewport;
import aahz.widget.PositionBox;
import aahz.widget.Area;
import aahz.widget.Skin;
import aahz.widget.WindowManager;
import aahz.draw.Graphics;
import aahz.draw.Image;
import aahz.draw.Font;
import aahz.util.String;

class Button : Widget {
private:
	enum Parts {
		LEFT = 0,
		MIDDLE = 1,
		RIGHT = 2,
		LEFT_HOVER = 3,
		MIDDLE_HOVER = 4,
		RIGHT_HOVER = 5,
		LEFT_PRESSED = 6,
		MIDDLE_PRESSED = 7,
		RIGHT_PRESSED = 8,
		
		COUNT = 9
	}

	bool entered = false;
	bool clicking = false;
	Image img;
	Image[Parts.COUNT] parts;
	int middleWidth;
	String m_text;
	
	void skinStuff() {
		parts[Parts.LEFT] = Skin.images[ Skin.button[ SkinButtonEnums.NORMAL ][ SkinButtonEnums.LEFT ] ];
		parts[Parts.MIDDLE] = Skin.images[ Skin.button[ SkinButtonEnums.NORMAL ][ SkinButtonEnums.MIDDLE ] ];
		parts[Parts.RIGHT] = Skin.images[ Skin.button[ SkinButtonEnums.NORMAL ][ SkinButtonEnums.RIGHT ] ];
		parts[Parts.LEFT_HOVER] = Skin.images[ Skin.button[ SkinButtonEnums.HOVER ][ SkinButtonEnums.LEFT ] ];
		parts[Parts.MIDDLE_HOVER] = Skin.images[ Skin.button[ SkinButtonEnums.HOVER ][ SkinButtonEnums.MIDDLE ] ];
		parts[Parts.RIGHT_HOVER] = Skin.images[ Skin.button[ SkinButtonEnums.HOVER ][ SkinButtonEnums.RIGHT ] ];
		parts[Parts.LEFT_PRESSED] = Skin.images[ Skin.button[ SkinButtonEnums.PRESSED ][ SkinButtonEnums.LEFT ] ];
		parts[Parts.MIDDLE_PRESSED] = Skin.images[ Skin.button[ SkinButtonEnums.PRESSED ][ SkinButtonEnums.MIDDLE ] ];
		parts[Parts.RIGHT_PRESSED] = Skin.images[ Skin.button[ SkinButtonEnums.PRESSED ][ SkinButtonEnums.RIGHT ] ];
		
		setMinHeight(Comparator.ABSOLUTE, parts[Parts.MIDDLE].height);
	}
	
	void sizeToText() {
		img = Skin.buttonFont.getText(m_text);
		int minWidth = cast(int)(1.5f * img.width);
		if (
			minWidth
			< (img.width + 4 + parts[Parts.LEFT].width + parts[Parts.RIGHT].width)	// Make sure it fits in just the middle
		) {
			minWidth = (img.width + 4 + parts[Parts.LEFT].width + parts[Parts.RIGHT].width);
		}
		middleWidth = minWidth - (parts[Parts.LEFT].width + parts[Parts.RIGHT].width);
		
		setMinWidth(Comparator.ABSOLUTE, minWidth);
	}

public:
	this(String text) {
		if (!Skin.loaded) throw new Exception("Buttons require that a skin be loaded");
		m_text = new String(text);
		
		skinStuff();
		sizeToText();
		
		WindowManager.listenCursor(this);
	}
	
	~this() {
		WindowManager.unlistenCursor(this);
	}

	void event(Event e) {
		switch (e.type) {
		case EventType.CURSOR_ENTER:
			entered = true;
		break;
		case EventType.CURSOR_LEAVE:
			entered = false;
			clicking = false;
		break;
		case EventType.CURSOR_DOWN:
			if (e.key == Key.MOUSE_LEFT) {
				clicking = true;
			}
		break;
		case EventType.CURSOR_UP:
			if (e.key == Key.MOUSE_LEFT) {
				if (clicking) {
					onClick();
				}
				clicking = false;
			}
		break;
		}
	}
	
	void paint() {
		scope Graphics g = new Graphics(m_drawBox);
		Viewport.do2D(m_clipBox);
		
		Area mClip;
		mClip.left = m_drawBox.left + parts[Parts.LEFT].width;
		mClip.bottom = m_drawBox.bottom;
		mClip.width = middleWidth;
		mClip.height = m_drawBox.height;
		mClip.overlap(m_clipBox);
		
		int drawX = parts[Parts.LEFT].width;
		int drawCount = middleWidth / parts[Parts.MIDDLE].width;
		if ((middleWidth % parts[Parts.MIDDLE].width) != 0) ++drawCount;
		
		if (clicking) {
			g.drawImage( parts[Parts.LEFT_PRESSED], 0, 0 );
			g.drawImage( parts[Parts.RIGHT_PRESSED], m_drawBox.width - parts[Parts.RIGHT].width, 0 );

			Viewport.setClip(mClip);
			for (int L = 0; L < drawCount; L++) {
				g.drawImage( parts[Parts.MIDDLE_PRESSED], drawX, 0 );
				drawX += parts[Parts.MIDDLE].width;
			}
		}
		else if (entered) {
			g.drawImage( parts[Parts.LEFT_HOVER], 0, 0 );
			g.drawImage( parts[Parts.RIGHT_HOVER], m_drawBox.width - parts[Parts.RIGHT].width, 0 );

			Viewport.setClip(mClip);
			for (int L = 0; L < drawCount; L++) {
				g.drawImage( parts[Parts.MIDDLE_HOVER], drawX, 0 );
				drawX += parts[Parts.MIDDLE].width;
			}
		}
		else {
			g.drawImage( parts[Parts.LEFT], 0, 0 );
			g.drawImage( parts[Parts.RIGHT], m_drawBox.width - parts[Parts.RIGHT].width, 0 );

			Viewport.setClip(mClip);
			for (int L = 0; L < drawCount; L++) {
				g.drawImage( parts[Parts.MIDDLE], drawX, 0 );
				drawX += parts[Parts.MIDDLE].width;
			}
		}
		
		Viewport.setClip(m_clipBox);
		g.drawImage( img, (m_drawBox.width - img.width) / 2, Skin.buttonV );
	}
	
	void setText(String text) {
		m_text = new String(text);
		sizeToText();
	}
	
	void reskin() {
		skinStuff();
		sizeToText();
	}
	
	void onClick() {}
	
	final void add() {}	// disable
}
