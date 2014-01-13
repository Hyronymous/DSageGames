module aahz.widget.ScrollPanel;

import aahz.widget.Widget;
import aahz.widget.Area;
import aahz.widget.Panel;
import aahz.widget.Viewport;
import aahz.widget.Event;
import aahz.widget.PositionBox;
import aahz.widget.WindowManager;
import aahz.widget.Skin;
import aahz.draw.Graphics;
import aahz.draw.Color;
import aahz.draw.Image;

import tango.util.container.LinkedList;
import tango.util.Convert;
import tango.io.Stdout;

class ScrollPanel : Widget {
private:
	const int SCROLL_AMOUNT = 100;	// Amount that scroll buttons scroll
	enum SPStyle {
		PLAIN = 0,
		HBAR = 0x1,
		VBAR = 0x2,
		BOTH = 0x3
	}

	int m_width, m_height;
	float m_scrollH = 0.0f, m_scrollV = 0.0f;
	float m_adjustH = 0.0f, m_adjustV = 0.0f;
	SPStyle m_style = SPStyle.PLAIN;
	Color4ub m_color;
	Scrollbar[2] scrollbars;
	
	enum ScrollFacing {
		HORIZONTAL = 0,
		VERTICAL = 1,
		LEFT = 0,
		RIGHT = 1,
		UP = 2,
		DOWN = 3
	}	
	enum ScrollStyle {
		NORMAL = 0,
		HOVER = 1,
		PRESSED = 2
	}
	
	class ScrollButton : Widget {
	private:
		Image[3] images;
		ScrollFacing m_facing;
		bool clicking = false;
		bool entered = false;
		
		void skinStuff() {
			if (m_style != SPStyle.BOTH) {
				switch (m_facing) {
				case ScrollFacing.LEFT:
					images[ ScrollStyle.NORMAL ] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_LEFT ][ SkinScrollEnums.NORMAL ] ];
					images[ ScrollStyle.HOVER ] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_LEFT ][ SkinScrollEnums.HOVER ] ];
					images[ ScrollStyle.PRESSED ] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_LEFT ][ SkinScrollEnums.PRESSED ] ];
					
					situate(
						Comparator.ABSOLUTE, Alignment.LEFT, 0.0f,
						Comparator.ABSOLUTE, Alignment.BOTTOM, 0.0f,
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].width,
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].height
					);
				break;
				case ScrollFacing.RIGHT:
					images[ ScrollStyle.NORMAL ] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_RIGHT ][ SkinScrollEnums.NORMAL ] ];
					images[ ScrollStyle.HOVER ] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_RIGHT ][ SkinScrollEnums.HOVER ] ];
					images[ ScrollStyle.PRESSED ] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_RIGHT ][ SkinScrollEnums.PRESSED ] ];
					
					situate(
						Comparator.ABSOLUTE, Alignment.RIGHT, 0.0f,
						Comparator.ABSOLUTE, Alignment.BOTTOM, 0.0f,
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].width,
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].height
					);
				break;
				case ScrollFacing.UP:
					images[ ScrollStyle.NORMAL ] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_TOP ][ SkinScrollEnums.NORMAL ] ];
					images[ ScrollStyle.HOVER ] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_TOP ][ SkinScrollEnums.HOVER ] ];
					images[ ScrollStyle.PRESSED ] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_TOP ][ SkinScrollEnums.PRESSED ] ];
					
					situate(
						Comparator.ABSOLUTE, Alignment.LEFT, 0.0f,
						Comparator.ABSOLUTE, Alignment.TOP, 0.0f,
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].width,
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].height
					);
				break;
				case ScrollFacing.DOWN:
					images[ ScrollStyle.NORMAL ] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_BOTTOM ][ SkinScrollEnums.NORMAL ] ];
					images[ ScrollStyle.HOVER ] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_BOTTOM ][ SkinScrollEnums.HOVER ] ];
					images[ ScrollStyle.PRESSED ] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_BOTTOM ][ SkinScrollEnums.PRESSED ] ];
					
					situate(
						Comparator.ABSOLUTE, Alignment.LEFT, 0.0f,
						Comparator.ABSOLUTE, Alignment.BOTTOM, 0.0f,
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].width,
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].height
					);
				break;
				}
			}
			else {
				switch (m_facing) {
				case ScrollFacing.LEFT:
					images[ ScrollStyle.NORMAL ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_LEFT ][ SkinScrollEnums.NORMAL ] ];
					images[ ScrollStyle.HOVER ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_LEFT ][ SkinScrollEnums.HOVER ] ];
					images[ ScrollStyle.PRESSED ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_LEFT ][ SkinScrollEnums.PRESSED ] ];
					
					situate(
						Comparator.ABSOLUTE, Alignment.LEFT, 0.0f,
						Comparator.ABSOLUTE, Alignment.BOTTOM, 0.0f,
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].width,
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].height
					);
				break;
				case ScrollFacing.RIGHT:
					images[ ScrollStyle.NORMAL ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_RIGHT ] [ SkinScrollEnums.NORMAL ]];
					images[ ScrollStyle.HOVER ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_RIGHT ][ SkinScrollEnums.HOVER ] ];
					images[ ScrollStyle.PRESSED ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_RIGHT ][ SkinScrollEnums.PRESSED ] ];
					
					situate(
						Comparator.ABSOLUTE, Alignment.RIGHT, cast(float)(-Skin.images[ Skin.scrollBlock ].width),	// skip past block
						Comparator.ABSOLUTE, Alignment.BOTTOM, 0.0f,
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].width,
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].height
					);
				break;
				case ScrollFacing.UP:
					images[ ScrollStyle.NORMAL ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_TOP ][ SkinScrollEnums.NORMAL ] ];
					images[ ScrollStyle.HOVER ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_TOP ][ SkinScrollEnums.HOVER ] ];
					images[ ScrollStyle.PRESSED ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_TOP ][ SkinScrollEnums.PRESSED ] ];
					
					situate(
						Comparator.ABSOLUTE, Alignment.LEFT, 0.0f,
						Comparator.ABSOLUTE, Alignment.TOP, 0.0f,
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].width,
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].height
					);
				break;
				case ScrollFacing.DOWN:
					images[ ScrollStyle.NORMAL ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_BOTTOM ][ SkinScrollEnums.NORMAL ] ];
					images[ ScrollStyle.HOVER ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_BOTTOM ][ SkinScrollEnums.HOVER ] ];
					images[ ScrollStyle.PRESSED ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_BOTTOM ][ SkinScrollEnums.PRESSED ] ];
					
					situate(
						Comparator.ABSOLUTE, Alignment.LEFT, 0.0f,
						Comparator.ABSOLUTE, Alignment.BOTTOM, 0.0f,
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].width,
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].height
					);
				break;
				}
			}
		}
		
	public:
		this(ScrollFacing facing) {
			m_facing = facing;
			skinStuff();
			WindowManager.listenCursor(this);
		}
		
		~this() {
			WindowManager.unlistenCursor(this);
		}
		
		void reskin() {
			skinStuff();
		}
		
		void paint() {
			scope Graphics g = new Graphics(m_drawBox);
			Viewport.do2D(m_clipBox);
			
			if (clicking) {
				g.drawImage(images[ScrollStyle.PRESSED], 0, 0);
			}
			else if (entered) {
				g.drawImage(images[ScrollStyle.HOVER], 0, 0);
			}
			else {
				g.drawImage(images[ScrollStyle.NORMAL], 0, 0);
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
						switch (m_facing) {
						case ScrollFacing.LEFT:
							this.outer.scrollHorizontal(-SCROLL_AMOUNT);
						break;
						case ScrollFacing.RIGHT:
							this.outer.scrollHorizontal(SCROLL_AMOUNT);
						break;
						case ScrollFacing.DOWN:
							this.outer.scrollVertical(SCROLL_AMOUNT);
						break;
						case ScrollFacing.UP:
							this.outer.scrollVertical(-SCROLL_AMOUNT);
						break;
						}
					}
					clicking = false;
				}
			break;
			}
		}
	}
	
	class ScrollArea : Widget {
	private:
		class Scroller : Widget {
		private:
			enum ScrollerPart {
				TOP = 0,
				LEFT = 0,
				MIDDLE = 1,
				BOTTOM = 2,
				RIGHT = 2
			}
			
			Image[3][3] images;
			ScrollFacing m_facing;
			bool moving = false;
			bool entered = false;
			int minSize;
			
			void skinStuff() {
				if (m_style != SPStyle.BOTH) {
					switch (m_facing) {
					case ScrollFacing.HORIZONTAL:
						images[ScrollerPart.LEFT][ScrollStyle.NORMAL] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_SCROLL_LEFT ][ SkinScrollEnums.NORMAL ] ];
						images[ScrollerPart.MIDDLE][ScrollStyle.NORMAL] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_SCROLL_MIDDLE ][ SkinScrollEnums.NORMAL ] ];
						images[ScrollerPart.RIGHT][ScrollStyle.NORMAL] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_SCROLL_RIGHT ][ SkinScrollEnums.NORMAL ] ];

						images[ScrollerPart.LEFT][ScrollStyle.HOVER] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_SCROLL_LEFT ][ SkinScrollEnums.HOVER ] ];
						images[ScrollerPart.MIDDLE][ScrollStyle.HOVER] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_SCROLL_MIDDLE ][ SkinScrollEnums.HOVER ] ];
						images[ScrollerPart.RIGHT][ScrollStyle.HOVER] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_SCROLL_RIGHT ][ SkinScrollEnums.HOVER ] ];

						images[ScrollerPart.LEFT][ScrollStyle.PRESSED] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_SCROLL_LEFT ][ SkinScrollEnums.PRESSED ] ];
						images[ScrollerPart.MIDDLE][ScrollStyle.PRESSED] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_SCROLL_MIDDLE ][ SkinScrollEnums.PRESSED ] ];
						images[ScrollerPart.RIGHT][ScrollStyle.PRESSED] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_SCROLL_RIGHT ][ SkinScrollEnums.PRESSED ] ];

						minSize =
							images[ScrollerPart.LEFT][ScrollStyle.NORMAL].width
							+ images[ScrollerPart.RIGHT][ScrollStyle.NORMAL].width
						;
					break;
					case ScrollFacing.VERTICAL:
						images[ScrollerPart.TOP][ScrollStyle.NORMAL] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_SCROLL_TOP ][ SkinScrollEnums.NORMAL ] ];
						images[ScrollerPart.MIDDLE][ScrollStyle.NORMAL] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_SCROLL_MIDDLE ][ SkinScrollEnums.NORMAL ] ];
						images[ScrollerPart.BOTTOM][ScrollStyle.NORMAL] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_SCROLL_BOTTOM ][ SkinScrollEnums.NORMAL ] ];

						images[ScrollerPart.TOP][ScrollStyle.HOVER] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_SCROLL_TOP ][ SkinScrollEnums.HOVER ] ];
						images[ScrollerPart.MIDDLE][ScrollStyle.HOVER] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_SCROLL_MIDDLE ][ SkinScrollEnums.HOVER ] ];
						images[ScrollerPart.BOTTOM][ScrollStyle.HOVER] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_SCROLL_BOTTOM ][ SkinScrollEnums.HOVER ] ];

						images[ScrollerPart.TOP][ScrollStyle.PRESSED] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_SCROLL_TOP ][ SkinScrollEnums.PRESSED ] ];
						images[ScrollerPart.MIDDLE][ScrollStyle.PRESSED] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_SCROLL_MIDDLE ][ SkinScrollEnums.PRESSED ] ];
						images[ScrollerPart.BOTTOM][ScrollStyle.PRESSED] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_SCROLL_BOTTOM ][ SkinScrollEnums.PRESSED ] ];

						minSize =
							images[ScrollerPart.TOP][ScrollStyle.NORMAL].height
							+ images[ScrollerPart.BOTTOM][ScrollStyle.NORMAL].height
						;
					break;
					}
				}
				else {	// BOTH
					switch (m_facing) {
					case ScrollFacing.HORIZONTAL:
						images[ScrollerPart.LEFT][ScrollStyle.NORMAL] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_SCROLL_LEFT ][ SkinScrollEnums.NORMAL ] ];
						images[ScrollerPart.MIDDLE][ScrollStyle.NORMAL] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_SCROLL_MIDDLE ][ SkinScrollEnums.NORMAL ] ];
						images[ScrollerPart.RIGHT][ScrollStyle.NORMAL] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_SCROLL_RIGHT ][ SkinScrollEnums.NORMAL ] ];

						images[ScrollerPart.LEFT][ScrollStyle.HOVER] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_SCROLL_LEFT ][ SkinScrollEnums.HOVER ] ];
						images[ScrollerPart.MIDDLE][ScrollStyle.HOVER] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_SCROLL_MIDDLE ][ SkinScrollEnums.HOVER ] ];
						images[ScrollerPart.RIGHT][ScrollStyle.HOVER] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_SCROLL_RIGHT ][ SkinScrollEnums.HOVER ] ];

						images[ScrollerPart.LEFT][ScrollStyle.PRESSED] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_SCROLL_LEFT ][ SkinScrollEnums.PRESSED ] ];
						images[ScrollerPart.MIDDLE][ScrollStyle.PRESSED] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_SCROLL_MIDDLE ][ SkinScrollEnums.PRESSED ] ];
						images[ScrollerPart.RIGHT][ScrollStyle.PRESSED] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_SCROLL_RIGHT ][ SkinScrollEnums.PRESSED ] ];

						minSize =
							images[ScrollerPart.LEFT][ScrollStyle.NORMAL].width
							+ images[ScrollerPart.RIGHT][ScrollStyle.NORMAL].width
						;
					break;
					case ScrollFacing.VERTICAL:
						images[ScrollerPart.TOP][ScrollStyle.NORMAL] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_SCROLL_TOP ][ SkinScrollEnums.NORMAL ] ];
						images[ScrollerPart.MIDDLE][ScrollStyle.NORMAL] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_SCROLL_MIDDLE ][ SkinScrollEnums.NORMAL ] ];
						images[ScrollerPart.BOTTOM][ScrollStyle.NORMAL] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_SCROLL_BOTTOM ][ SkinScrollEnums.NORMAL ] ];

						images[ScrollerPart.TOP][ScrollStyle.HOVER] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_SCROLL_TOP ][ SkinScrollEnums.HOVER ] ];
						images[ScrollerPart.MIDDLE][ScrollStyle.HOVER] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_SCROLL_MIDDLE ][ SkinScrollEnums.HOVER ] ];
						images[ScrollerPart.BOTTOM][ScrollStyle.HOVER] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_SCROLL_BOTTOM ][ SkinScrollEnums.HOVER ] ];

						images[ScrollerPart.TOP][ScrollStyle.PRESSED] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_SCROLL_TOP ][ SkinScrollEnums.PRESSED ] ];
						images[ScrollerPart.MIDDLE][ScrollStyle.PRESSED] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_SCROLL_MIDDLE ][ SkinScrollEnums.PRESSED ] ];
						images[ScrollerPart.BOTTOM][ScrollStyle.PRESSED] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_SCROLL_BOTTOM ][ SkinScrollEnums.PRESSED ] ];

						minSize =
							images[ScrollerPart.TOP][ScrollStyle.NORMAL].height
							+ images[ScrollerPart.BOTTOM][ScrollStyle.NORMAL].height
						;
					break;
					}
				}
			}
			
		public:
			this(ScrollFacing facing) {
				m_facing = facing;
				skinStuff();
				WindowManager.listenKey(this, Key.MOUSE_LEFT);
				WindowManager.listenCursor(this);
				WindowManager.listenMove1(this);
			}
			
			~this() {
				WindowManager.unlistenKey(this, Key.MOUSE_LEFT);
				WindowManager.unlistenMove1(this);
				WindowManager.unlistenCursor(this);
			}
			
			void reskin() {
				skinStuff();
			}
			
			void updatePosition(Area pBox, Area pClip) {	// move it based on the parent's size
				if (m_facing == ScrollFacing.HORIZONTAL) {
					float width = (cast(float)this.outer.outer.m_drawBox.width / cast(float)this.outer.outer.m_width) * cast(float)pBox.width;
					if (width < minSize) width = minSize;

					float left = m_scrollH * (cast(float)pBox.width - width);
					
					situate(
						Comparator.ABSOLUTE, Alignment.LEFT, left,
						Comparator.ABSOLUTE, Alignment.BOTTOM, 0.0f,
						Comparator.ABSOLUTE, width,
						Comparator.ABSOLUTE, images[ScrollerPart.LEFT][ScrollStyle.NORMAL].height
					);
				}
				else {	// VERTICAL
					float height = (cast(float)this.outer.outer.m_drawBox.height / cast(float)this.outer.outer.m_height) * cast(float)pBox.height;
					if (height < minSize) height = minSize;

					float bottom = cast(float)pBox.height - height - m_scrollV * (cast(float)pBox.height - height);
					
					situate(
						Comparator.ABSOLUTE, Alignment.LEFT, 0.0f,
						Comparator.ABSOLUTE, Alignment.BOTTOM, bottom,
						Comparator.ABSOLUTE, images[ScrollerPart.BOTTOM][ScrollStyle.NORMAL].width,
						Comparator.ABSOLUTE, height
					);
				}
				
				super.updatePosition(pBox, pClip);
			}
			
			void paint() {
				scope Graphics g = new Graphics(m_drawBox);
				Viewport.do2D(m_clipBox);
				
				ScrollStyle sStyle;
				
				if (moving) {
					sStyle = ScrollStyle.PRESSED;
				}
				else if (entered) {
					sStyle = ScrollStyle.HOVER;
				}
				else {
					sStyle = ScrollStyle.NORMAL;
				}
				
				if (m_facing == ScrollFacing.HORIZONTAL) {
					g.drawImage(images[ScrollerPart.LEFT][sStyle], 0, 0);
					g.drawImage(images[ScrollerPart.RIGHT][sStyle], m_drawBox.width - images[ScrollerPart.RIGHT][sStyle].width, 0);
					
					int drawPos = images[ScrollerPart.LEFT][sStyle].width;
					int midWidth = m_drawBox.width - (images[ScrollerPart.LEFT][sStyle].width + images[ScrollerPart.RIGHT][sStyle].width);
					int drawCount = midWidth / images[ScrollerPart.MIDDLE][sStyle].width;
					if ((midWidth % images[ScrollerPart.MIDDLE][sStyle].width) != 0) ++drawCount;
					
					Area clip;
					clip.left = m_drawBox.left + drawPos;
					clip.bottom = m_drawBox.bottom;
					clip.width = midWidth;
					clip.height = images[ScrollerPart.MIDDLE][sStyle].height;
					clip.overlap(m_clipBox);
					
					Viewport.setClip(clip);
					for (int L = 0; L < drawCount; L++) {
						g.drawImage(images[ScrollerPart.MIDDLE][sStyle], drawPos, 0);
						drawPos += images[ScrollerPart.MIDDLE][sStyle].width;
					}
				}
				else {	// VERTICAL
					g.drawImage(images[ScrollerPart.BOTTOM][sStyle], 0, 0);
					g.drawImage(images[ScrollerPart.TOP][sStyle], 0, m_drawBox.height - images[ScrollerPart.TOP][sStyle].height);
					
					int drawPos = images[ScrollerPart.BOTTOM][sStyle].height;
					int midHeight = m_drawBox.height - (images[ScrollerPart.BOTTOM][sStyle].height + images[ScrollerPart.TOP][sStyle].height);
					int drawCount = midHeight / images[ScrollerPart.MIDDLE][sStyle].height;
					if ((midHeight % images[ScrollerPart.MIDDLE][sStyle].height) != 0) ++drawCount;
					
					Area clip;
					clip.left = m_drawBox.left;
					clip.bottom = m_drawBox.bottom + drawPos;
					clip.width = images[ScrollerPart.MIDDLE][sStyle].height;
					clip.height = midHeight;
					clip.overlap(m_clipBox);
					
					Viewport.setClip(clip);
					for (int L = 0; L < drawCount; L++) {
						g.drawImage(images[ScrollerPart.MIDDLE][sStyle], 0, drawPos);
						drawPos += images[ScrollerPart.MIDDLE][sStyle].height;
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
				break;
				case EventType.CURSOR_DOWN:
					if (e.key == Key.MOUSE_LEFT) {
						moving = true;
					}
				break;
				case EventType.KEY_UP:
				case EventType.CURSOR_UP:
					if (e.key == Key.MOUSE_LEFT) {
						moving = false;
					}
				break;
				case EventType.MOVE1:
					if (moving) {
						if (m_facing == ScrollFacing.HORIZONTAL) {
							int amount = to!(int)(
								(cast(float)e.diffX / cast(float)(this.outer.m_drawBox.width - minSize))
								* cast(float)this.outer.outer.m_width
							);
							this.outer.outer.scrollHorizontal(amount);
						}
						else {	// VERTICAL
							int amount = to!(int)(
								-(cast(float)e.diffY / cast(float)(this.outer.m_drawBox.height - minSize))
								* cast(float)this.outer.outer.m_height
							);
							this.outer.outer.scrollVertical(amount);
						}
					}
				break;
				default:
				break;
				}
				
				super.event(e);
			}
		}
		
		Image[3] images;
		ScrollFacing m_facing;
		bool clicking = false;
		bool entered = false;
		
		Scroller scroller;
		
		void skinStuff() {
			if (m_style != SPStyle.BOTH) {
				switch (m_facing) {
				case ScrollFacing.HORIZONTAL:
					images[ ScrollStyle.NORMAL ] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_MIDDLE ][ SkinScrollEnums.NORMAL ] ];
					images[ ScrollStyle.HOVER ] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_MIDDLE ][ SkinScrollEnums.HOVER ] ];
					images[ ScrollStyle.PRESSED ] = Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_MIDDLE ][ SkinScrollEnums.PRESSED ] ];
					
					situate(
						Comparator.ABSOLUTE, Alignment.LEFT, cast(float)(Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.NORMAL ][ SkinScrollEnums.H_LEFT ] ].width),
						Comparator.ABSOLUTE, Alignment.BOTTOM, 0.0f,
						Comparator.ADDITIVE, -(
							cast(float)(
								Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_LEFT ][ SkinScrollEnums.NORMAL ] ].width
								+ Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_RIGHT ][ SkinScrollEnums.NORMAL ] ].width
							)
						),
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].height
					);
				break;
				case ScrollFacing.VERTICAL:
					images[ ScrollStyle.NORMAL ] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_MIDDLE ][ SkinScrollEnums.NORMAL ] ];
					images[ ScrollStyle.HOVER ] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_MIDDLE ][ SkinScrollEnums.HOVER ] ];
					images[ ScrollStyle.PRESSED ] = Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_MIDDLE ][ SkinScrollEnums.PRESSED ] ];
					
					situate(
						Comparator.ABSOLUTE, Alignment.LEFT, 0.0f,
						Comparator.ABSOLUTE, Alignment.BOTTOM, cast(float)(Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_BOTTOM ][ SkinScrollEnums.NORMAL ] ].height),
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].width,
						Comparator.ADDITIVE, -(
							cast(float)(
								Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_BOTTOM ][ SkinScrollEnums.NORMAL ] ].height
								+ Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_TOP ][ SkinScrollEnums.NORMAL ] ].height
							)
						)
					);
				break;
				}
			}
			else {	// BOTH
				switch (m_facing) {
				case ScrollFacing.HORIZONTAL:
					images[ ScrollStyle.NORMAL ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_MIDDLE ][ SkinScrollEnums.NORMAL ] ];
					images[ ScrollStyle.HOVER ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_MIDDLE ][ SkinScrollEnums.HOVER ] ];
					images[ ScrollStyle.PRESSED ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_MIDDLE ][ SkinScrollEnums.PRESSED ] ];
					
					situate(
						Comparator.ABSOLUTE, Alignment.LEFT, cast(float)(Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_LEFT ][ SkinScrollEnums.NORMAL ] ].width),
						Comparator.ABSOLUTE, Alignment.BOTTOM, 0.0f,
						Comparator.ADDITIVE, -(
							cast(float)(
								Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_LEFT ][ SkinScrollEnums.NORMAL ] ].width
								+ Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_RIGHT ][ SkinScrollEnums.NORMAL ] ].width
								+ Skin.images[ Skin.scrollBlock ].width
							)
						),
						Comparator.ABSOLUTE, cast(float)images[ ScrollStyle.NORMAL ].height
					);
				break;
				case ScrollFacing.VERTICAL:
					images[ ScrollStyle.NORMAL ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_MIDDLE ][ SkinScrollEnums.NORMAL ] ];
					images[ ScrollStyle.HOVER ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_MIDDLE ][ SkinScrollEnums.HOVER ] ];
					images[ ScrollStyle.PRESSED ] = Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_MIDDLE ][ SkinScrollEnums.PRESSED ] ];
					
					situate(
						Comparator.ABSOLUTE, Alignment.LEFT, 0.0f,
						Comparator.ABSOLUTE, Alignment.BOTTOM, cast(float)(Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_BOTTOM ][ SkinScrollEnums.NORMAL ] ].height),
						Comparator.ABSOLUTE, images[ ScrollStyle.NORMAL ].width,
						Comparator.ADDITIVE, -(
							cast(float)(
								Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_BOTTOM ][ SkinScrollEnums.NORMAL ] ].height
								+ Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_TOP ][ SkinScrollEnums.NORMAL ] ].height
							)
						)
					);
				break;
				}
			}
		}
		
	public:
		this(ScrollFacing facing) {
			m_facing = facing;
			skinStuff();
			WindowManager.listenCursor(this);
			
			scroller = new Scroller(facing);
			setLayout([0.100f], [[0.100f]]);
			add(0, 0, scroller);
		}
		
		~this() {
			WindowManager.unlistenCursor(this);
			remove(0, 0, scroller);
			delete scroller;
		}
		
		void reskin() {
			skinStuff();
			
			super.reskin();
		}
		
		void paint() {
			scope Graphics g = new Graphics(m_drawBox);
			Viewport.do2D(m_clipBox);
			
			ScrollStyle sStyle;
			
			if (clicking) {
				sStyle = ScrollStyle.PRESSED;
			}
			else if (entered) {
				sStyle = ScrollStyle.HOVER;
			}
			else {
				sStyle = ScrollStyle.NORMAL;
			}
			
			int drawCount, drawPos;
			if (m_facing == ScrollFacing.HORIZONTAL) {
				drawCount = m_drawBox.width / images[sStyle].width;
				if ((m_drawBox.width % images[sStyle].width) != 0) ++drawCount;
				
				for (int L = 0; L < drawCount; L++) {
					g.drawImage(images[sStyle], drawPos, 0);
					drawPos += images[sStyle].width;
				}
			}
			else {	// ScrollFacing.VERTICAL
				drawCount = m_drawBox.height / images[sStyle].height;
				if ((m_drawBox.height % images[sStyle].height) != 0) ++drawCount;
				
				for (int L = 0; L < drawCount; L++) {
					g.drawImage(images[sStyle], 0, drawPos);
					drawPos += images[sStyle].height;
				}
			}
			
			super.paint();
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
						// !!!!!!!!!!
					}
					clicking = false;
				}
			break;
			}
			
			super.event(e);
		}
	
		int getThickness() {
			if (m_facing == ScrollFacing.HORIZONTAL) {
				return images[ScrollStyle.NORMAL].height;
			}
			else {
				return images[ScrollStyle.NORMAL].width;
			}
		}
	}
	
	class Scrollbar : Widget {
	private:
		Image block;
		ScrollFacing m_facing;
		
		ScrollButton[2] buttons;
		ScrollArea scrollArea;
		
		void skinStuff() {
			if (m_facing == ScrollFacing.HORIZONTAL) {
				block = Skin.images[ Skin.scrollBlock ];
			}
			
			if (m_style != SPStyle.BOTH) {
				if (m_facing == ScrollFacing.HORIZONTAL) {
					setMinWidth(Comparator.ABSOLUTE, cast(float)(
						Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_LEFT ][ SkinScrollEnums.NORMAL ] ].width
						+ Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_RIGHT ][ SkinScrollEnums.NORMAL ] ].width
						+ Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_SCROLL_LEFT ][ SkinScrollEnums.NORMAL ] ].width
						+ Skin.images[ Skin.scroll[ SkinScrollEnums.HORIZONTAL ][ SkinScrollEnums.H_SCROLL_RIGHT ][ SkinScrollEnums.NORMAL ] ].width
					));
				}
				else {
					setMinHeight(Comparator.ABSOLUTE, cast(float)(
						Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_TOP ][ SkinScrollEnums.NORMAL ] ].height
						+ Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_BOTTOM ][ SkinScrollEnums.NORMAL ] ].height
						+ Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_SCROLL_TOP ][ SkinScrollEnums.NORMAL ] ].height
						+ Skin.images[ Skin.scroll[ SkinScrollEnums.VERTICAL ][ SkinScrollEnums.V_SCROLL_BOTTOM ][ SkinScrollEnums.NORMAL ] ].height
					));
				}
			}
			else {	// both
				if (m_facing == ScrollFacing.HORIZONTAL) {
					setMinWidth(Comparator.ABSOLUTE, cast(float)(
						Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_LEFT ][ SkinScrollEnums.NORMAL ] ].width
						+ Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_RIGHT ][ SkinScrollEnums.NORMAL ] ].width
						+ Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_SCROLL_LEFT ][ SkinScrollEnums.NORMAL ] ].width
						+ Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BH_SCROLL_RIGHT ][ SkinScrollEnums.NORMAL ] ].width
						+ Skin.images[ Skin.scrollBlock ].width
					));
				}
				else {
					setMinHeight(Comparator.ABSOLUTE, cast(float)(
						Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_TOP ][ SkinScrollEnums.NORMAL ] ].height
						+ Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_BOTTOM ][ SkinScrollEnums.NORMAL ] ].height
						+ Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_SCROLL_TOP ][ SkinScrollEnums.NORMAL ] ].height
						+ Skin.images[ Skin.scroll[ SkinScrollEnums.BOTH ][ SkinScrollEnums.BV_SCROLL_BOTTOM ][ SkinScrollEnums.NORMAL ] ].height
					));
				}
			}
		}
		
	public:
		this(ScrollFacing facing) {
			m_facing = facing;
			situate("left:0", "bottom:0", "100%", "100%");
			
			if (m_facing == ScrollFacing.HORIZONTAL) {
				buttons[0] = new ScrollButton(ScrollFacing.LEFT);
				buttons[1] = new ScrollButton(ScrollFacing.RIGHT);
				scrollArea = new ScrollArea(ScrollFacing.HORIZONTAL);
			}
			else {
				buttons[0] = new ScrollButton(ScrollFacing.UP);
				buttons[1] = new ScrollButton(ScrollFacing.DOWN);
				scrollArea = new ScrollArea(ScrollFacing.VERTICAL);
			}
			setLayout([0.100f], [[0.100f]]);
			add(0, 0, buttons[0]);
			add(0, 0, buttons[1]);
			add(0, 0, scrollArea);
			
			skinStuff();
		}
		
		void reskin() {
			skinStuff();
			super.reskin();
		}
		
		void paint() {
			if (m_facing == ScrollFacing.HORIZONTAL && m_style == SPStyle.BOTH) {
				scope Graphics g = new Graphics(m_drawBox);
				Viewport.do2D(m_clipBox);
				g.drawImage(block, m_drawBox.width - block.width, 0);
			}
			
			super.paint();
		}
		
		int getThickness() {
			return scrollArea.getThickness();
		}
	}
	
public:
	this(int width, int height) {
		if (!Skin.loaded) throw new Exception("ScrollPanels require that a skin be loaded");
		else if (width < 1 || height < 1) throw new Exception("Scroll area must be greater than 0");
		
		m_width = width;
		m_height = height;
		
		layoutHeights.length = 1;
		layoutWidths.length = 1;
		layoutWidths[0].length = 1;
		
		layoutHeights[0] = 0.100f;
		layoutWidths[0][0] = 0.100f;
		
		children.length = 2;
		children[0].length = 2;
		children[1].length = 1;
		
		for (int L = 0; L < children.length; L++) for (int L2 = 0; L2 < children[L].length; L2++) {
			children[L][L2] = new LinkedList!(Widget);
		}
		
		scrollbars[ ScrollFacing.HORIZONTAL ] = new Scrollbar(ScrollFacing.HORIZONTAL);
		scrollbars[ ScrollFacing.VERTICAL ] = new Scrollbar(ScrollFacing.VERTICAL);
	}
	
	void add(Widget w) {
		super.add(0, 0, w);
	}
	
	void remove(Widget w) {
		super.remove(0, 0, w);
	}

	void setColor(ubyte r, ubyte g, ubyte b, ubyte a = 0xff) {
		m_color.set(r, g, b, a);
	}
	
	void scrollHorizontal(int amount) {
		m_adjustH += amount;
	}
	
	void scrollVertical(int amount) {
		m_adjustV += amount;
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
	
	void updatePosition(Area pBox, Area pClip) {
		scope (exit) {
			m_adjustH = m_adjustV = 0.0f;
		}
		
		Area cell, cellClip;
		bool styleChanged = false;
		
		toArea(pBox, m_drawBox);	// Get my draw area relative to my parent
		m_clipBox.set(m_drawBox);	// Copy into clip area
		m_clipBox.overlap(pClip);	// shrink clip area to fit in parent's
		if (m_clipBox.isZero()) return;	// Nothing to draw
		
		if (m_width <= m_drawBox.width) {	// Display area fits inside viewing area
			if ((m_style & SPStyle.HBAR) == SPStyle.HBAR) {	// Has bar. Need to get rid of it
				children[1][0].remove( scrollbars[ ScrollFacing.HORIZONTAL ] );
				layoutHeights.length = 1;
				layoutWidths.length = 1;
				
				m_style ^= SPStyle.HBAR;
				styleChanged = true;
				m_scrollH = 0.0f;	// reset the scrollbar
			}
		}
		else {	// Doesn't fit, need to have scrollbars
			if ((m_style & SPStyle.HBAR) != SPStyle.HBAR)  {	// doesn't have bar. Need to add it
				layoutHeights.length = 2;
				layoutWidths.length = 2;
				layoutWidths[1].length = 1;
				children[1][0].append( scrollbars[ ScrollFacing.HORIZONTAL ] );
				
				m_style ^= SPStyle.HBAR;
				styleChanged = true;
			}
		}
		
		if (m_height <= m_drawBox.height) {	// Display area fits inside viewing area
			if ((m_style & SPStyle.VBAR) == SPStyle.VBAR) {	// Has bar. Need to get rid of it
				children[0][1].remove( scrollbars[ ScrollFacing.VERTICAL ] );
				layoutWidths[0].length = 1;
				
				m_style ^= SPStyle.VBAR;
				styleChanged = true;
				m_scrollV = 0.0f;	// reset the scrollbar
			}
		}
		else {	// Doesn't fit, need to have scrollbars
			if ((m_style & SPStyle.VBAR) != SPStyle.VBAR)  {	// doesn't have bar. Need to add it
				layoutWidths[0].length = 2;
				children[0][1].append( scrollbars[ ScrollFacing.VERTICAL ] );
				
				m_style ^= SPStyle.VBAR;
				styleChanged = true;
			}
		}
		
		if (styleChanged) {
			scrollbars[ ScrollFacing.HORIZONTAL ].reskin();
			scrollbars[ ScrollFacing.VERTICAL ].reskin();
			
			switch (m_style) {
			case SPStyle.BOTH:
				layoutHeights[1] = cast(float)scrollbars[ ScrollFacing.HORIZONTAL ].getThickness();
				layoutWidths[0][1] = cast(float)scrollbars[ ScrollFacing.VERTICAL ].getThickness();
				layoutWidths[1][0] = 0.100f;
			break;
			case SPStyle.HBAR:
				layoutHeights[1] = cast(float)scrollbars[ ScrollFacing.HORIZONTAL ].getThickness();
				layoutWidths[1][0] = 0.100f;
			break;
			case SPStyle.VBAR:
				layoutWidths[0][1] = cast(float)scrollbars[ ScrollFacing.VERTICAL ].getThickness();
			break;
			default:
			break;
			}
		}
		
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
					if (L == 0 && L2 == 0) {	// Set up a fake drawBox for cell (0,0)
						Area lieBox;
						
						if (cell.width < m_width) {	// doesn't fit
							float diff = m_width - cell.width;
							m_scrollH += m_adjustH / diff;
							if (m_scrollH < 0.0f) m_scrollH = 0.0f;
							else if (m_scrollH > 1.0f) m_scrollH = 1.0f;
							
							lieBox.left = cell.left - to!(int)(m_scrollH * diff);
							lieBox.width = m_width;
						}
						else {	// fits
							lieBox.left = cell.left;
							lieBox.width = cell.width;
						}
						
						if (cell.height < m_height) {	// doesn't fit
							float diff = m_height - cell.height;
							m_scrollV += m_adjustV / diff;
							if (m_scrollV < 0.0f) m_scrollV = 0.0f;
							else if (m_scrollV > 1.0f) m_scrollV = 1.0f;
							
							lieBox.bottom = cell.bottom - to!(int)((1.0f - m_scrollV) * diff);
							lieBox.height = m_height;
						}
						else {	// fits
							lieBox.bottom = cell.bottom;
							lieBox.height = cell.height;
						}
						
						foreach (w; children[L][L2]) {
							w.updatePosition(lieBox, cellClip);	// LIE!
						}
					}
					else {	// All the other cells, draw normal
						foreach (w; children[L][L2]) {
							w.updatePosition(cell, cellClip);
						}
					}
				}
				
				cell.left += widths[L2];
			}
		}
	}
	
	void setLayout() {}	// disabled
	void updateLayout() {}	// disabled
}
