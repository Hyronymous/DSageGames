module aahz.widget.Window;

import aahz.widget.Widget;
import aahz.widget.WindowManager;
import aahz.widget.Skin;
import aahz.widget.Viewport;
import aahz.widget.Area;
import aahz.widget.Event;
import aahz.widget.PositionBox;
import aahz.widget.Cursor;
import aahz.draw.Graphics;
import aahz.draw.Image;
import aahz.draw.Font;
import aahz.util.String;

import tango.io.Stdout;
import tango.util.Convert;

enum WindowStyle {	// Used by Skin. Do not change without checking use
	NONE = 0,
	RESIZE = 0x1,
	CLOSE = 0x2,
	MINIMIZE = 0x4,
	LOCK = 0x8,
	STYLE_COUNT = 0x10
}

class Window : Widget {
private:
	enum WinImgs {
		TOP_LEFT = 0,
		TOP = 1,
		TOP_RIGHT = 2,
		LEFT = 3,
		RIGHT = 4,
		BOTTOM_LEFT = 5,
		BOTTOM = 6,
		BOTTOM_RIGHT = 7,
		COUNT = 8
	}

	WindowStyle style = WindowStyle.NONE;
	WindowStyle drawStyle = WindowStyle.NONE;	// Locking a window changes the way it should be drawn from what its capable of
	Image[WinImgs.COUNT] images;
	Font titleFont;

	Resizer[4] resizers;
	TitleBar tBar = null;
	CloseButton cButton = null;
	MinimizeButton mButton = null;
	LockButton lButton = null;
	bool locked = false;
	
	class CloseButton : Widget {
	private:
		enum CImgs {
			NORMAL = 0,
			HOVER = 1,
			PRESSED = 2,
			COUNT = 3
		}
		bool clicking = false;
		bool entered = false;
		Image[CImgs.COUNT] images;
		
		void skinStuff() {
			images[CImgs.NORMAL] = Skin.images[ Skin.window[style][SkinWindowEnums.CLOSE][SkinWindowEnums.NORMAL] ];
			images[CImgs.PRESSED] = Skin.images[ Skin.window[style][SkinWindowEnums.CLOSE][SkinWindowEnums.PRESSED] ];
			images[CImgs.HOVER] = Skin.images[ Skin.window[style][SkinWindowEnums.CLOSE][SkinWindowEnums.HOVER] ];
			
			situate(
				Skin.window[style][SkinWindowEnums.CLOSE][SkinWindowEnums.H],
				Skin.window[style][SkinWindowEnums.CLOSE][SkinWindowEnums.V],
				to!(char[])(images[CImgs.NORMAL].width),
				to!(char[])(images[CImgs.NORMAL].height)
			);
		}
		
	public:
		this() {
			skinStuff();
			WindowManager.listenCursor(this);
		}
		
		~this() {
			WindowManager.unlistenCursor(this);
		}
		
		void paint() {
			scope Graphics g = new Graphics(m_drawBox);
			Viewport.do2D(m_clipBox);
			
			if (clicking) {
				g.drawImage(images[CImgs.PRESSED], 0, 0);
			}
			else if (entered) {
				g.drawImage(images[CImgs.HOVER], 0, 0);
			}
			else {
				g.drawImage(images[CImgs.NORMAL], 0, 0);
			}
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
					if (clicking) parent.visible = false;
					clicking = false;
				}
			break;
			}
		}
		
		void reskin() {
			skinStuff();
		}
	}
	
	class MinimizeButton : Widget {
	private:
		enum MImgs {
			NORMAL = 0,
			HOVER = 1,
			PRESSED = 2,
			COUNT = 3
		}
		bool clicking = false;
		bool entered = false;
		Image[MImgs.COUNT] images;
		
		void skinStuff() {
			images[MImgs.NORMAL] = Skin.images[ Skin.window[style][SkinWindowEnums.MINIMIZE][SkinWindowEnums.NORMAL] ];
			images[MImgs.PRESSED] = Skin.images[ Skin.window[style][SkinWindowEnums.MINIMIZE][SkinWindowEnums.PRESSED] ];
			images[MImgs.HOVER] = Skin.images[ Skin.window[style][SkinWindowEnums.MINIMIZE][SkinWindowEnums.HOVER] ];
			
			situate(
				Skin.window[style][SkinWindowEnums.MINIMIZE][SkinWindowEnums.H],
				Skin.window[style][SkinWindowEnums.MINIMIZE][SkinWindowEnums.V],
				to!(char[])(images[MImgs.NORMAL].width),
				to!(char[])(images[MImgs.NORMAL].height)
			);
		}
		
	public:
		this() {
			skinStuff();
			WindowManager.listenCursor(this);
		}
		
		~this() {
			WindowManager.unlistenCursor(this);
		}
		
		void paint() {
			scope Graphics g = new Graphics(m_drawBox);
			Viewport.do2D(m_clipBox);
			
			if (clicking) {
				g.drawImage(images[MImgs.PRESSED], 0, 0);
			}
			else if (entered) {
				g.drawImage(images[MImgs.HOVER], 0, 0);
			}
			else {
				g.drawImage(images[MImgs.NORMAL], 0, 0);
			}
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
					if (clicking) parent.visible = false;
					clicking = false;
				}
			break;
			}
		}
		
		void reskin() {
			skinStuff();
		}
	}
	
	class LockButton : Widget {
	private:
		enum LImgs {
			UNLOCKED = 0,
			UNLOCKED_HOVER = 1,
			UNLOCKED_PRESSED = 2,
			LOCKED = 3,
			LOCKED_HOVER = 4,
			LOCKED_PRESSED = 5,
			COUNT = 6
		}
		bool clicking = false;
		bool entered = false;
		Image[LImgs.COUNT] images;
		
		void skinStuff() {
			images[LImgs.UNLOCKED] = Skin.images[ Skin.window[style][SkinWindowEnums.LOCK][SkinWindowEnums.UNLOCKED] ];
			images[LImgs.UNLOCKED_PRESSED] = Skin.images[ Skin.window[style][SkinWindowEnums.LOCK][SkinWindowEnums.UNLOCKED_PRESSED] ];
			images[LImgs.UNLOCKED_HOVER] = Skin.images[ Skin.window[style][SkinWindowEnums.LOCK][SkinWindowEnums.UNLOCKED_HOVER] ];
			images[LImgs.LOCKED] = Skin.images[ Skin.window[style][SkinWindowEnums.LOCK][SkinWindowEnums.LOCKED] ];
			images[LImgs.LOCKED_PRESSED] = Skin.images[ Skin.window[style][SkinWindowEnums.LOCK][SkinWindowEnums.LOCKED_PRESSED] ];
			images[LImgs.LOCKED_HOVER] = Skin.images[ Skin.window[style][SkinWindowEnums.LOCK][SkinWindowEnums.LOCKED_HOVER] ];
			
			situate(
				Skin.window[style][SkinWindowEnums.LOCK][SkinWindowEnums.H],
				Skin.window[style][SkinWindowEnums.LOCK][SkinWindowEnums.V],
				to!(char[])(images[LImgs.UNLOCKED].width),
				to!(char[])(images[LImgs.UNLOCKED].height)
			);
		}
		
	public:
		this() {
			skinStuff();
			WindowManager.listenCursor(this);
		}
		
		~this() {
			WindowManager.unlistenCursor(this);
		}
		
		void paint() {
			scope Graphics g = new Graphics(m_drawBox);
			Viewport.do2D(m_clipBox);
			
			if (locked) {
				if (clicking) {
					g.drawImage(images[LImgs.LOCKED_PRESSED], 0, 0);
				}
				else if (entered) {
					g.drawImage(images[LImgs.LOCKED_HOVER], 0, 0);
				}
				else {
					g.drawImage(images[LImgs.LOCKED], 0, 0);
				}
			}
			else {
				if (clicking) {
					g.drawImage(images[LImgs.UNLOCKED_PRESSED], 0, 0);
				}
				else if (entered) {
					g.drawImage(images[LImgs.UNLOCKED_HOVER], 0, 0);
				}
				else {
					g.drawImage(images[LImgs.UNLOCKED], 0, 0);
				}
			}
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
						if (locked) {
							unlock();	// calls outer class
						}
						else {
							lock();	// calls outer class
						}
					}
					clicking = false;
				}
			break;
			}
		}
		
		void reskin() {
			skinStuff();
		}
	}
	
	class TitleBar : Widget {
	private:
		Image titleImage;
		String m_title;
		
		void skinStuff() {
			situate(
				Skin.window[drawStyle][SkinWindowEnums.TITLE][SkinWindowEnums.H],
				Skin.window[drawStyle][SkinWindowEnums.TITLE][SkinWindowEnums.V],
				Skin.window[drawStyle][SkinWindowEnums.TITLE][SkinWindowEnums.WIDTH],
				Skin.window[drawStyle][SkinWindowEnums.TITLE][SkinWindowEnums.HEIGHT]
			);
		}
		
		void titleStuff() {
			titleImage = Skin.windowTitle.getText(m_title);
		}
		
	public:
		this(String title) {
			m_title = new String(title);
			skinStuff();
			titleStuff();
			
			WindowManager.listenCursor(this);
			WindowManager.listenMove1(this);
			WindowManager.listenKey(this, Key.MOUSE_LEFT);
		}
		
		~this() {
			WindowManager.unlistenCursor(this);
			WindowManager.unlistenMove1(this);
			WindowManager.unlistenKey(this, Key.MOUSE_LEFT);
		}

		void paint() {
			scope Graphics g = new Graphics(m_drawBox);
			Viewport.do2D(m_clipBox);
			
			g.drawImage(titleImage, Skin.windowTitleLeft, Skin.windowTitleBottom);
		}

		bool moving = false;
		void event(Event e) {
			switch (e.type) {
			case EventType.CURSOR_DOWN:
				if (e.key == Key.MOUSE_LEFT && !locked) moving = true;
			break;
			case EventType.KEY_UP:
			case EventType.CURSOR_UP:
				if (e.key == Key.MOUSE_LEFT) {
					moving = false;
				}
			break;
			case EventType.MOVE1:
				if (moving && !locked) {
					this.outer.move(e.diffX, e.diffY);
				}
			break;
			default:
			break;
			}
		}
		
		void retitle(String title) {
			m_title = new String(title);
			titleStuff();
		}
		
		void reskin() {
			skinStuff();
			titleStuff();
		}
	}
		
	class Resizer : Widget {
	private:
		Side type;
		
		void skinStuff() {
			switch (type) {
			case Side.TOP:
				situate(
					Skin.window[style][SkinWindowEnums.TITLE][SkinWindowEnums.H],		// h
					"top:0",															// v
					Skin.window[style][SkinWindowEnums.TITLE][SkinWindowEnums.WIDTH],	// width
					Skin.windowResize													// height
				);
			break;
			case Side.LEFT:
				situate(
					"left:0",			// h
					"bottom:0",			// v
					Skin.windowResize,	// width
					"100%"				// height
				);
			break;
			case Side.RIGHT:
				situate(
					"right:0",			// h
					"bottom:0",			// v
					Skin.windowResize,	// width
					"100%"				// height
				);
			break;
			case Side.BOTTOM:
				situate(
					"left:0",			// h
					"bottom:0",			// v
					"100%",				// width
					Skin.windowResize	// height
				);
			break;
			}
		}
		
	public:
		this(Side rType) {
			type = rType;
			skinStuff();
			
			WindowManager.listenCursor(this);
			WindowManager.listenMove1(this);
			WindowManager.listenKey(this, Key.MOUSE_LEFT);
		}
		
		bool moving = false;
		bool entered = false;
		void event(Event e) {
			switch (e.type) {
			case EventType.CURSOR_ENTER:
				entered = true;
				if (type == Side.LEFT || type == Side.RIGHT) {
					Cursor.setStyle(CursorStyle.LEFT_RIGHT);
				}
				else {
					Cursor.setStyle(CursorStyle.UP_DOWN);
				}
			break;
			case EventType.CURSOR_LEAVE:
				entered = false;
				if (!moving) {
					Cursor.setStyle(CursorStyle.NORMAL);
				}
			break;
			case EventType.CURSOR_DOWN:
				if (e.key == Key.MOUSE_LEFT && !locked) moving = true;
			break;
			case EventType.KEY_UP:
			case EventType.CURSOR_UP:
				if (e.key == Key.MOUSE_LEFT) {
					if (entered == false) Cursor.setStyle(CursorStyle.NORMAL);
					moving = false;
				}
			break;
			case EventType.MOVE1:
				if (moving && !locked) {
					switch (type) {
					case Side.LEFT:
					case Side.RIGHT:
						this.outer.dragSide(type, e.diffX);
					break;
					case Side.BOTTOM:
					case Side.TOP:
						this.outer.dragSide(type, e.diffY);
					break;
					}
				}
			break;
			default:
			break;
			}
		}
		
		void reskin() {
			skinStuff();
		}
	}
	
public:
	this(String title, WindowStyle style = (WindowStyle.RESIZE | WindowStyle.LOCK)) {
		if (!Skin.loaded) throw new Exception("Windows require that a skin be loaded");
		
		this.style = style;
		this.drawStyle = style;
		
		WindowManager.listenCursor(this);
		
		setMinWidth(Skin.windowMinWidth);
		setMinHeight(Skin.windowMinHeight);
		
		images[WinImgs.TOP_LEFT]		= Skin.images[ Skin.window[style][SkinWindowEnums.TOP_LEFT][SkinWindowEnums.IMAGE] ];
		images[WinImgs.TOP]				= Skin.images[ Skin.window[style][SkinWindowEnums.TOP][SkinWindowEnums.IMAGE] ];
		images[WinImgs.TOP_RIGHT]		= Skin.images[ Skin.window[style][SkinWindowEnums.TOP_RIGHT][SkinWindowEnums.IMAGE] ];
		images[WinImgs.LEFT]			= Skin.images[ Skin.window[style][SkinWindowEnums.LEFT][SkinWindowEnums.IMAGE] ];
		images[WinImgs.RIGHT]			= Skin.images[ Skin.window[style][SkinWindowEnums.RIGHT][SkinWindowEnums.IMAGE] ];
		images[WinImgs.BOTTOM_LEFT]		= Skin.images[ Skin.window[style][SkinWindowEnums.BOTTOM_LEFT][SkinWindowEnums.IMAGE] ];
		images[WinImgs.BOTTOM]			= Skin.images[ Skin.window[style][SkinWindowEnums.BOTTOM][SkinWindowEnums.IMAGE] ];
		images[WinImgs.BOTTOM_RIGHT]	= Skin.images[ Skin.window[style][SkinWindowEnums.BOTTOM_RIGHT][SkinWindowEnums.IMAGE] ];
		
		setLayout(
			[
				cast(float)images[WinImgs.TOP].height,
				0.100f,
				cast(float)images[WinImgs.BOTTOM].height
			],
			[
				[0.100f],
				[
					cast(float)images[WinImgs.LEFT].width,
					0.100f,
					cast(float)images[WinImgs.RIGHT].width
				],
				[0.100f]
			]
		);
		
		if ((style & WindowStyle.RESIZE) == WindowStyle.RESIZE) {
			resizers[0] = new Resizer(Side.TOP);
			resizers[1] = new Resizer(Side.LEFT);
			resizers[2] = new Resizer(Side.RIGHT);
			resizers[3] = new Resizer(Side.BOTTOM);
			super.add(0, 0, resizers[0]);
			super.add(0, 1, resizers[1]);
			super.add(2, 1, resizers[2]);
			super.add(0, 2, resizers[3]);
		}
		if ((style & WindowStyle.CLOSE) == WindowStyle.CLOSE) {
			cButton = new CloseButton();
			super.add(0, 0, cButton);
		}
		if ((style & WindowStyle.MINIMIZE) == WindowStyle.MINIMIZE) {
			mButton = new MinimizeButton();
			super.add(0, 0, mButton);
		}
		if ((style & WindowStyle.LOCK) == WindowStyle.LOCK) {
			lButton = new LockButton();
			super.add(0, 0, lButton);
		}
		tBar = new TitleBar(title);
		super.add(0, 0, tBar);
	}
	
	~this() {
		WindowManager.unlistenCursor(this);
	}
	
	void lock() {
		if ((style & WindowStyle.LOCK) == WindowStyle.LOCK) {
			locked = true;
			drawStyle = WindowStyle.LOCK;
			
			if ((style & WindowStyle.CLOSE) == WindowStyle.CLOSE) cButton.visible = false;
			if ((style & WindowStyle.MINIMIZE) == WindowStyle.MINIMIZE) mButton.visible = false;
			if ((style & WindowStyle.RESIZE) == WindowStyle.RESIZE) {
				resizers[0].visible = false;
				resizers[1].visible = false;
				resizers[2].visible = false;
				resizers[3].visible = false;
			}
			
			images[WinImgs.TOP_LEFT]		= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.TOP_LEFT][SkinWindowEnums.IMAGE] ];
			images[WinImgs.TOP]				= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.TOP][SkinWindowEnums.IMAGE] ];
			images[WinImgs.TOP_RIGHT]		= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.TOP_RIGHT][SkinWindowEnums.IMAGE] ];
			images[WinImgs.LEFT]			= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.LEFT][SkinWindowEnums.IMAGE] ];
			images[WinImgs.RIGHT]			= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.RIGHT][SkinWindowEnums.IMAGE] ];
			images[WinImgs.BOTTOM_LEFT]		= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.BOTTOM_LEFT][SkinWindowEnums.IMAGE] ];
			images[WinImgs.BOTTOM]			= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.BOTTOM][SkinWindowEnums.IMAGE] ];
			images[WinImgs.BOTTOM_RIGHT]	= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.BOTTOM_RIGHT][SkinWindowEnums.IMAGE] ];
			
			updateLayout(
				[
					cast(float)images[WinImgs.TOP].height,
					0.100f,
					cast(float)images[WinImgs.BOTTOM].height
				],
				[
					[0.100f],
					[
						cast(float)images[WinImgs.LEFT].width,
						0.100f,
						cast(float)images[WinImgs.RIGHT].width
					],
					[0.100f]
				]
			);
			
			tBar.reskin();
		}
	}
	
	void unlock() {
		if ((style & WindowStyle.LOCK) == WindowStyle.LOCK) {
			locked = false;
			drawStyle = style;
			
			if ((style & WindowStyle.CLOSE) == WindowStyle.CLOSE) cButton.visible = true;
			if ((style & WindowStyle.MINIMIZE) == WindowStyle.MINIMIZE) mButton.visible = true;
			if ((style & WindowStyle.RESIZE) == WindowStyle.RESIZE) {
				resizers[0].visible = true;
				resizers[1].visible = true;
				resizers[2].visible = true;
				resizers[3].visible = true;
			}			
			images[WinImgs.TOP_LEFT]		= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.TOP_LEFT][SkinWindowEnums.IMAGE] ];
			images[WinImgs.TOP]				= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.TOP][SkinWindowEnums.IMAGE] ];
			images[WinImgs.TOP_RIGHT]		= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.TOP_RIGHT][SkinWindowEnums.IMAGE] ];
			images[WinImgs.LEFT]			= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.LEFT][SkinWindowEnums.IMAGE] ];
			images[WinImgs.RIGHT]			= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.RIGHT][SkinWindowEnums.IMAGE] ];
			images[WinImgs.BOTTOM_LEFT]		= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.BOTTOM_LEFT][SkinWindowEnums.IMAGE] ];
			images[WinImgs.BOTTOM]			= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.BOTTOM][SkinWindowEnums.IMAGE] ];
			images[WinImgs.BOTTOM_RIGHT]	= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.BOTTOM_RIGHT][SkinWindowEnums.IMAGE] ];

			updateLayout(
				[
					cast(float)images[WinImgs.TOP].height,
					0.100f,
					cast(float)images[WinImgs.BOTTOM].height
				],
				[
					[0.100f],
					[
						cast(float)images[WinImgs.LEFT].width,
						0.100f,
						cast(float)images[WinImgs.RIGHT].width
					],
					[0.100f]
				]
			);
			
			tBar.reskin();
		}
	}
	
	void paint() {
		int drawCount;
		int drawX, drawY, drawWidth, drawHeight;
		Area clip;
		
		scope Graphics g = new Graphics(m_drawBox);
		Viewport.do2D(m_clipBox);
		
		g.drawImage(images[WinImgs.BOTTOM_LEFT], 0, 0);	// bottom left
		g.drawImage(images[WinImgs.BOTTOM_RIGHT], m_drawBox.width - images[WinImgs.BOTTOM_RIGHT].width, 0);	// bottom right
		g.drawImage(images[WinImgs.TOP_LEFT], 0, m_drawBox.height - images[WinImgs.TOP_LEFT].height);	// top left
		g.drawImage(images[WinImgs.TOP_RIGHT], m_drawBox.width - images[WinImgs.TOP_RIGHT].width, m_drawBox.height - images[WinImgs.TOP_RIGHT].height);	// top right

		// bottom
		drawWidth = m_drawBox.width - images[WinImgs.BOTTOM_LEFT].width - images[WinImgs.BOTTOM_RIGHT].width;
		if ((drawWidth % images[WinImgs.BOTTOM].width) != 0) {
			drawCount = drawWidth / images[WinImgs.BOTTOM].width + 1;
		}
		else {
			drawCount = drawWidth / images[WinImgs.BOTTOM].width;
		}
		drawX = m_drawBox.left + images[WinImgs.BOTTOM_LEFT].width;
		drawY = m_drawBox.bottom;

		clip.left = drawX;
		clip.bottom = drawY;
		clip.width = drawWidth;
		clip.height = images[WinImgs.BOTTOM].height;
		clip.overlap(m_clipBox);
		Viewport.setClip(clip);
		
		for (int L = 0; L < drawCount; L++) {
			g.drawImage(images[WinImgs.BOTTOM], images[WinImgs.BOTTOM_LEFT].width + (L * images[WinImgs.BOTTOM].width), 0);
		}
		
		// top
		drawWidth = m_drawBox.width - images[WinImgs.TOP_LEFT].width - images[WinImgs.TOP_RIGHT].width;
		if ((drawWidth % images[WinImgs.TOP].width) != 0) {
			drawCount = drawWidth / images[WinImgs.TOP].width + 1;
		}
		else {
			drawCount = drawWidth / images[WinImgs.TOP].width;
		}
		drawX = m_drawBox.left + images[WinImgs.TOP_LEFT].width;
		drawY = m_drawBox.bottom + m_drawBox.height - images[WinImgs.TOP].height;

		clip.left = drawX;
		clip.bottom = drawY;
		clip.width = drawWidth;
		clip.height = images[WinImgs.TOP].height;
		clip.overlap(m_clipBox);
		Viewport.setClip(clip);
		
		for (int L = 0; L < drawCount; L++) {
			g.drawImage(images[WinImgs.TOP], images[WinImgs.TOP_LEFT].width + (L * images[WinImgs.TOP].width), m_drawBox.height - images[WinImgs.TOP].height);
		}
		
		// left
		drawHeight = m_drawBox.height - images[WinImgs.TOP_LEFT].height - images[WinImgs.BOTTOM_LEFT].height;
		if ((drawHeight % images[WinImgs.LEFT].height) != 0) {
			drawCount = drawHeight / images[WinImgs.LEFT].height + 1;
		}
		else {
			drawCount = drawHeight / images[WinImgs.LEFT].height;
		}
		drawX = m_drawBox.left;
		drawY = m_drawBox.bottom + images[WinImgs.BOTTOM_LEFT].height;
		
		clip.left = drawX;
		clip.bottom = drawY;
		clip.width = images[WinImgs.LEFT].width;
		clip.height = drawHeight;
		clip.overlap(m_clipBox);
		Viewport.setClip(clip);
		
		for (int L = 0; L < drawCount; L++) {
			g.drawImage(images[WinImgs.LEFT], 0, images[WinImgs.BOTTOM_LEFT].height + (L * images[WinImgs.LEFT].height));
		}
		
		// right
		drawHeight = m_drawBox.height - images[WinImgs.TOP_RIGHT].height - images[WinImgs.BOTTOM_RIGHT].height;
		if ((drawHeight % images[WinImgs.RIGHT].height) != 0) {
			drawCount = drawHeight / images[WinImgs.RIGHT].height + 1;
		}
		else {
			drawCount = drawHeight / images[WinImgs.RIGHT].height;
		}
		drawX = m_drawBox.left + m_drawBox.width - images[WinImgs.RIGHT].width;
		drawY = m_drawBox.bottom + images[WinImgs.BOTTOM_RIGHT].height;
		
		clip.left = drawX;
		clip.bottom = drawY;
		clip.width = images[WinImgs.RIGHT].width;
		clip.height = drawHeight;
		clip.overlap(m_clipBox);
		Viewport.setClip(clip);
		
		for (int L = 0; L < drawCount; L++) {
			g.drawImage(images[WinImgs.RIGHT], m_drawBox.width - images[WinImgs.RIGHT].width, images[WinImgs.BOTTOM_RIGHT].height + (L * images[WinImgs.RIGHT].height));
		}

		super.paint();
	}
	
	void add(Widget w) {
		super.add(1, 1, w);
	}
	
	void reskin() {
		images[WinImgs.TOP_LEFT]		= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.TOP_LEFT][SkinWindowEnums.IMAGE] ];
		images[WinImgs.TOP]				= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.TOP][SkinWindowEnums.IMAGE] ];
		images[WinImgs.TOP_RIGHT]		= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.TOP_RIGHT][SkinWindowEnums.IMAGE] ];
		images[WinImgs.LEFT]			= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.LEFT][SkinWindowEnums.IMAGE] ];
		images[WinImgs.RIGHT]			= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.RIGHT][SkinWindowEnums.IMAGE] ];
		images[WinImgs.BOTTOM_LEFT]		= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.BOTTOM_LEFT][SkinWindowEnums.IMAGE] ];
		images[WinImgs.BOTTOM]			= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.BOTTOM][SkinWindowEnums.IMAGE] ];
		images[WinImgs.BOTTOM_RIGHT]	= Skin.images[ Skin.window[drawStyle][SkinWindowEnums.BOTTOM_RIGHT][SkinWindowEnums.IMAGE] ];
		
		updateLayout(
			[
				cast(float)images[WinImgs.TOP].height,
				0.100f,
				cast(float)images[WinImgs.BOTTOM].height
			],
			[
				[0.100f],
				[
					cast(float)images[WinImgs.LEFT].width,
					0.100f,
					cast(float)images[WinImgs.RIGHT].width
				],
				[0.100f]
			]
		);
		
		super.reskin();
	}
}
