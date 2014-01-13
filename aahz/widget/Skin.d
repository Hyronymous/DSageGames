module aahz.widget.Skin;

import tango.text.xml.Document;
import tango.io.device.File;
import tango.io.Stdout;
import tango.util.Convert;
import tango.core.Memory;

import aahz.draw.Image;
import aahz.draw.Font;
import aahz.widget.Window;

enum SkinWindowEnums {
	TOP_LEFT = 0,
	TOP = 1,
	TOP_RIGHT = 2,
	LEFT = 3,
	RIGHT = 4,
	BOTTOM_LEFT = 5,
	BOTTOM = 6,
	BOTTOM_RIGHT = 7,
	CLOSE = 8,
	MINIMIZE = 9,
	LOCK = 10,
	TITLE = 11,
	ELEMENT_COUNT = 12,
	
	TOP_LEFT_COUNT = 1,
	TOP_COUNT = 1,
	TOP_RIGHT_COUNT = 1,
	LEFT_COUNT = 1,
	RIGHT_COUNT = 1,
	BOTTOM_LEFT_COUNT = 1,
	BOTTOM_COUNT = 1,
	BOTTOM_RIGHT_COUNT = 1,
	CLOSE_COUNT = 5,
	MINIMIZE_COUNT = 5,
	LOCK_COUNT = 8,
	TITLE_COUNT = 4,
	
	IMAGE = 0,
	NORMAL = 0,
	H = 1,
	V = 2,
	HOVER = 3,
	PRESSED = 4,
	UNLOCKED = 0,
	UNLOCKED_PRESSED = 3,
	UNLOCKED_HOVER = 4,
	LOCKED = 5,
	LOCKED_PRESSED = 6,
	LOCKED_HOVER = 7,
	WIDTH = 0,
	HEIGHT = 3,
}

enum SkinButtonEnums {
	NORMAL = 0,
	HOVER = 1,
	PRESSED = 2,
	STYLE_COUNT = 3,
	
	LEFT = 0,
	MIDDLE = 1,
	RIGHT = 2,
	ELEMENT_COUNT = 3
}

enum SkinScrollEnums {
	HORIZONTAL = 0,
	VERTICAL = 1,
	BOTH = 2,
	STYLE_COUNT = 3,
	
	NORMAL = 0,
	HOVER = 1,
	PRESSED = 2,
	ELEMENT_COUNT = 3,
	
	H_LEFT = 0,
	H_MIDDLE = 1,
	H_RIGHT = 2,
	H_SCROLL_LEFT = 3,
	H_SCROLL_MIDDLE = 4,
	H_SCROLL_RIGHT = 5,
	H_COUNT = 6,
	
	V_TOP = 0,
	V_MIDDLE = 1,
	V_BOTTOM = 2,
	V_SCROLL_TOP = 3,
	V_SCROLL_MIDDLE = 4,
	V_SCROLL_BOTTOM = 5,
	V_COUNT = 6,
	
	BH_LEFT = 0,
	BH_MIDDLE = 1,
	BH_RIGHT = 2,
	BH_SCROLL_LEFT = 3,
	BH_SCROLL_MIDDLE = 4,
	BH_SCROLL_RIGHT = 5,
	BV_TOP = 6,
	BV_MIDDLE = 7,
	BV_BOTTOM = 8,
	BV_SCROLL_TOP = 9,
	BV_SCROLL_MIDDLE = 10,
	BV_SCROLL_BOTTOM = 11,
	B_COUNT = 12
}

struct Skin {
static public:
	Image[ char[] ] images;
	
	char[][][SkinWindowEnums.ELEMENT_COUNT][WindowStyle.STYLE_COUNT] window;
	Font windowTitle;
	int windowTitleLeft, windowTitleBottom;
	char[] windowResize;
	char[] windowMinWidth, windowMinHeight;
	
	char[][SkinButtonEnums.ELEMENT_COUNT][SkinButtonEnums.STYLE_COUNT] button;
	Font buttonFont;
	int buttonV;
	
	char[][][][SkinScrollEnums.STYLE_COUNT] scroll;
	char[] scrollBlock;
	
	bool inited() {
		return m_inited;
	}
	
	bool loaded() {
		return m_loaded;
	}
	
	void init(char[] basePath) {
		m_inited = true;
		base = basePath.dup;
	}
	
	void cleanup() {
		m_inited = false;
		base.length = 0;
	}
	
static package:
	void load(char[] name) {
		clear();
		scope (success) m_loaded = true;
		
		scope char[] loadName = name;
		if (name.length == 0) {
			loadName = "Default";
		}
		
		scope char[] skinData = cast(char[])File.get("./skins/" ~ loadName ~ "/" ~ loadName ~ ".xml");
		
		scope auto skinXML = new Document!(char);
		skinXML.parse(skinData);	// Get XML data
		loadXML("./skins/" ~ name ~ "/", skinXML.tree);
		
		GC.collect();	// free anything that's been released (old images, etc.)
	}
	
static private:
	char[] base;
	bool m_inited = false;
	bool m_loaded = false;
		
	char[] getAttribute(Document!(char).Node node, char[] name) {
		foreach (attr; node.attributes) if (attr.name == name) return attr.value;
		return "";
	}
	
	void setFontColor(Font f, char[] text) {
		ubyte[3] c;
		for (uint L = 0; L < text.length; L++) switch(text[L]) {
		case '0':
			c[L / 2] |= 0x0 << ((1 - (L % 2)) * 4);
		break;
		case '1':
			c[L / 2] |= 0x1 << ((1 - (L % 2)) * 4);
		break;
		case '2':
			c[L / 2] |= 0x2 << ((1 - (L % 2)) * 4);
		break;
		case '3':
			c[L / 2] |= 0x3 << ((1 - (L % 2)) * 4);
		break;
		case '4':
			c[L / 2] |= 0x4 << ((1 - (L % 2)) * 4);
		break;
		case '5':
			c[L / 2] |= 0x5 << ((1 - (L % 2)) * 4);
		break;
		case '6':
			c[L / 2] |= 0x6 << ((1 - (L % 2)) * 4);
		break;
		case '7':
			c[L / 2] |= 0x7 << ((1 - (L % 2)) * 4);
		break;
		case '8':
			c[L / 2] |= 0x8 << ((1 - (L % 2)) * 4);
		break;
		case '9':
			c[L / 2] |= 0x9 << ((1 - (L % 2)) * 4);
		break;
		case 'a':
		case 'A':
			c[L / 2] |= 0xa << ((1 - (L % 2)) * 4);
		break;
		case 'b':
		case 'B':
			c[L / 2] |= 0xb << ((1 - (L % 2)) * 4);
		break;
		case 'c':
		case 'C':
			c[L / 2] |= 0xc << ((1 - (L % 2)) * 4);
		break;
		case 'd':
		case 'D':
			c[L / 2] |= 0xd << ((1 - (L % 2)) * 4);
		break;
		case 'e':
		case 'E':
			c[L / 2] |= 0xe << ((1 - (L % 2)) * 4);
		break;
		case 'f':
		case 'F':
			c[L / 2] |= 0xf << ((1 - (L % 2)) * 4);
		break;
		default:
			throw new Exception("Failed to parse color");
		break;
		}
		f.setColor(c[0], c[1], c[2]);
	}
	
	FontStyle parseFontStyle(char[] text) {
		FontStyle ret;
		
		for (uint L = 0; L < text.length; L++) switch(text[L]) {
		case 'n':
			ret |= FontStyle.NORMAL;
		break;
		case 'l':
			ret |= FontStyle.LIGHT;
		break;
		case 'b':
			ret |= FontStyle.BOLD;
		break;
		case 'i':
			ret |= FontStyle.ITALIC;
		break;
		case 'u':
			ret |= FontStyle.UNDERLINE;
		break;
		case 's':
			ret |= FontStyle.STRIKETHROUGH;
		break;
		default:
			throw new Exception("Failed to parse font style");
		break;
		}
		
		return ret;
	}

	void clear() {
		char[][] keys = images.keys;
		foreach (key; keys) {
			images.remove(key);
		}
		
		for (uint L = 0; L < WindowStyle.STYLE_COUNT; L++) {
			window[L][SkinWindowEnums.TOP_LEFT].length = SkinWindowEnums.TOP_LEFT_COUNT;
			for (uint L2 = 0; L2 < SkinWindowEnums.TOP_LEFT_COUNT; L2++) window[L][SkinWindowEnums.TOP_LEFT][L2].length = 0;
			
			window[L][SkinWindowEnums.TOP].length = SkinWindowEnums.TOP_COUNT;
			for (uint L2 = 0; L2 < SkinWindowEnums.TOP_COUNT; L2++) window[L][SkinWindowEnums.TOP][L2].length = 0;
			
			window[L][SkinWindowEnums.TOP_RIGHT].length = SkinWindowEnums.TOP_RIGHT_COUNT;
			for (uint L2 = 0; L2 < SkinWindowEnums.TOP_RIGHT_COUNT; L2++) window[L][SkinWindowEnums.TOP_RIGHT][L2].length = 0;
			
			window[L][SkinWindowEnums.LEFT].length = SkinWindowEnums.LEFT_COUNT;
			for (uint L2 = 0; L2 < SkinWindowEnums.LEFT_COUNT; L2++) window[L][SkinWindowEnums.LEFT][L2].length = 0;
			
			window[L][SkinWindowEnums.RIGHT].length = SkinWindowEnums.RIGHT_COUNT;
			for (uint L2 = 0; L2 < SkinWindowEnums.RIGHT_COUNT; L2++) window[L][SkinWindowEnums.RIGHT][L2].length = 0;
			
			window[L][SkinWindowEnums.BOTTOM_LEFT].length = SkinWindowEnums.BOTTOM_LEFT_COUNT;
			for (uint L2 = 0; L2 < SkinWindowEnums.BOTTOM_LEFT_COUNT; L2++) window[L][SkinWindowEnums.BOTTOM_LEFT][L2].length = 0;
			
			window[L][SkinWindowEnums.BOTTOM].length = SkinWindowEnums.BOTTOM_COUNT;
			for (uint L2 = 0; L2 < SkinWindowEnums.BOTTOM_COUNT; L2++) window[L][SkinWindowEnums.BOTTOM][L2].length = 0;
			
			window[L][SkinWindowEnums.BOTTOM_RIGHT].length = SkinWindowEnums.BOTTOM_RIGHT_COUNT;
			for (uint L2 = 0; L2 < SkinWindowEnums.BOTTOM_RIGHT_COUNT; L2++) window[L][SkinWindowEnums.BOTTOM_RIGHT][L2].length = 0;
			
			window[L][SkinWindowEnums.CLOSE].length = SkinWindowEnums.CLOSE_COUNT;
			for (uint L2 = 0; L2 < SkinWindowEnums.CLOSE_COUNT; L2++) window[L][SkinWindowEnums.CLOSE][L2].length = 0;
			
			window[L][SkinWindowEnums.MINIMIZE].length = SkinWindowEnums.MINIMIZE_COUNT;
			for (uint L2 = 0; L2 < SkinWindowEnums.MINIMIZE_COUNT; L2++) window[L][SkinWindowEnums.MINIMIZE][L2].length = 0;
			
			window[L][SkinWindowEnums.LOCK].length = SkinWindowEnums.LOCK_COUNT;
			for (uint L2 = 0; L2 < SkinWindowEnums.LOCK_COUNT; L2++) window[L][SkinWindowEnums.LOCK][L2].length = 0;
			
			window[L][SkinWindowEnums.TITLE].length = SkinWindowEnums.TITLE_COUNT;
			for (uint L2 = 0; L2 < SkinWindowEnums.TITLE_COUNT; L2++) window[L][SkinWindowEnums.TITLE][L2].length = 0;
		}
		windowTitle = null;
		windowTitleLeft = windowTitleBottom = 0;
		windowResize.length = 0;
		windowMinWidth.length = 0;
		windowMinHeight.length = 0;
		
		for (int L = 0; L < button.length; L++) for (int L2 = 0; L2 < button[L].length; L2++) {
			button[L][L2].length = 0;
		}
		buttonFont = null;
		buttonV = 0;
		
		for (int L = 0; L < scroll.length; L++) {
			switch (L) {
			case SkinScrollEnums.HORIZONTAL:
				scroll[L].length = SkinScrollEnums.H_COUNT;
			break;
			case SkinScrollEnums.VERTICAL:
				scroll[L].length = SkinScrollEnums.V_COUNT;
			break;
			case SkinScrollEnums.BOTH:
				scroll[L].length = SkinScrollEnums.B_COUNT;
			break;
			}
			
			for (int L2 = 0; L2 < scroll[L].length; L2++) {
				scroll[L][L2].length = SkinScrollEnums.ELEMENT_COUNT;
				for (int L3 = 0; L3 < scroll[L][L2].length; L3++) {
					scroll[L][L2][L3].length = 0;
				}
			}
		}
		scrollBlock.length = 0;
	}
	
	void loadXML(char[] path, Document!(char).Node root) {
		FontStyle titleStyle, btnStyle;
		char[] titleFont, titleColor, titleSize;
		char[] btnFont, btnColor, btnSize;
		
		foreach (n; root.children) switch (n.name) {
		case "skin":
			foreach (n2; n.children) switch (n2.name) {
			case "images":
				foreach (n3; n2.children) switch (n3.name) {
				case "image":
					images[
						getAttribute(n3, "name").dup
					]
					= new Image(
						path
						~ getAttribute(n3, "file")
					);
				break;
				default:
				break;
				}
			break;
			case "scrollbar":
				foreach (n3; n2.children) switch (n3.name) {
				case "horizontal":
					slurpScrollbar(n3, SkinScrollEnums.HORIZONTAL);
				break;
				case "vertical":
					slurpScrollbar(n3, SkinScrollEnums.VERTICAL);
				break;
				case "both":
					slurpScrollbar(n3, SkinScrollEnums.BOTH);
				break;
				default:
				break;
				}
			break;
			case "button":
				foreach (attr; n2.attributes) switch (attr.name) {
				case "font":
					btnFont = attr.value.dup;
				break;
				case "font-color":
					btnColor = attr.value.dup;
				break;
				case "font-size":
					btnSize = attr.value.dup;
				break;
				case "font-style":
					btnStyle = parseFontStyle(attr.value);
				break;
				case "text-bottom":
					buttonV = to!(int)(attr.value);
				break;
				default:
				break;
				}
				
				foreach (n3; n2.children) switch (n3.name) {
				case "normal":
					slurpButton(n3, SkinButtonEnums.NORMAL);
				break;
				case "hover":
					slurpButton(n3, SkinButtonEnums.HOVER);
				break;
				case "pressed":
					slurpButton(n3, SkinButtonEnums.PRESSED);
				break;
				default:
				break;
				}
			break;
			case "window":
				foreach (attr; n2.attributes) switch (attr.name) {
				case "title-font":
					titleFont = attr.value.dup;
				break;
				case "title-size":
					titleSize = attr.value.dup;
				break;
				case "title-color":
					titleColor = attr.value.dup;
				break;
				case "title-style":
					titleStyle = parseFontStyle(attr.value);
				break;
				case "title-left":
					windowTitleLeft = to!(int)(attr.value);
				break;
				case "title-bottom":
					windowTitleBottom = to!(int)(attr.value);
				break;
				case "min-width":
					windowMinWidth = attr.value.dup;
				break;
				case "min-height":
					windowMinHeight = attr.value.dup;
				break;
				default:
				break;
				}
				
				foreach (n3; n2.children) switch (n3.name) {
				case "resizable":
					foreach (attr; n3.attributes) switch (attr.name) {
					case "size":
						windowResize = attr.value.dup;
					break;
					default:
					break;
					}
				
					foreach (n4; n3.children) switch (n4.name) {
					case "lockable":
						foreach (n5; n4.children) switch (n5.name) {
						case "minimizable":
							foreach (n6; n5.children) switch (n6.name) {
							case "closable":
								slurpWindow(n6, WindowStyle.RESIZE | WindowStyle.CLOSE | WindowStyle.MINIMIZE | WindowStyle.LOCK);
							break;
							case "non-closable":
								slurpWindow(n6, WindowStyle.RESIZE | WindowStyle.MINIMIZE | WindowStyle.LOCK);
							break;
							default:
							break;
							}
						break;
						case "non-minimizable":
							foreach (n6; n5.children) switch (n6.name) {
							case "closable":
								slurpWindow(n6, WindowStyle.RESIZE | WindowStyle.CLOSE | WindowStyle.LOCK);
							break;
							case "non-closable":
								slurpWindow(n6, WindowStyle.RESIZE | WindowStyle.LOCK);
							break;
							default:
							break;
							}
						break;
						default:
						break;
						}
					break;
					case "non-lockable":
						foreach (n5; n4.children) switch (n5.name) {
						case "minimizable":
							foreach (n6; n5.children) switch (n6.name) {
							case "closable":
								slurpWindow(n6, WindowStyle.RESIZE | WindowStyle.CLOSE | WindowStyle.MINIMIZE);
							break;
							case "non-closable":
								slurpWindow(n6, WindowStyle.RESIZE | WindowStyle.MINIMIZE);
							break;
							default:
							break;
							}
						break;
						case "non-minimizable":
							foreach (n6; n5.children) switch (n6.name) {
							case "closable":
								slurpWindow(n6, WindowStyle.RESIZE | WindowStyle.CLOSE);
							break;
							case "non-closable":
								slurpWindow(n6, WindowStyle.RESIZE);
							break;
							default:
							break;
							}
						break;
						default:
						break;
						}
					break;
					default:
					break;
					}
				break;
				case "non-resizable":
					foreach (n4; n3.children) switch (n4.name) {
					case "lockable":
						foreach (n5; n4.children) switch (n5.name) {
						case "minimizable":
							foreach (n6; n5.children) switch (n6.name) {
							case "closable":
								slurpWindow(n6, WindowStyle.CLOSE | WindowStyle.MINIMIZE | WindowStyle.LOCK);
							break;
							case "non-closable":
								slurpWindow(n6, WindowStyle.MINIMIZE | WindowStyle.LOCK);
							break;
							default:
							break;
							}
						break;
						case "non-minimizable":
							foreach (n6; n5.children) switch (n6.name) {
							case "closable":
								slurpWindow(n6, WindowStyle.CLOSE | WindowStyle.LOCK);
							break;
							case "non-closable":
								slurpWindow(n6, WindowStyle.LOCK);
							break;
							default:
							break;
							}
						break;
						default:
						break;
						}
					break;
					case "non-lockable":
						foreach (n5; n4.children) switch (n5.name) {
						case "minimizable":
							foreach (n6; n5.children) switch (n6.name) {
							case "closable":
								slurpWindow(n6, WindowStyle.CLOSE | WindowStyle.MINIMIZE);
							break;
							case "non-closable":
								slurpWindow(n6, WindowStyle.MINIMIZE);
							break;
							default:
							break;
							}
						break;
						case "non-minimizable":
							foreach (n6; n5.children) switch (n6.name) {
							case "closable":
								slurpWindow(n6, WindowStyle.CLOSE);
							break;
							case "non-closable":
								slurpWindow(n6, WindowStyle.NONE);
							break;
							default:
							break;
							}
						break;
						default:
						break;
						}
					break;
					default:
					break;
					}
				break;
				default:
				break;
				}
			default:
			break;
			}
		break;
		default:
		break;
		}
		
		ubyte[3] c;
		int fSize = to!(int)(titleSize);
		windowTitle = new Font(titleFont, fSize, titleStyle);
		setFontColor(windowTitle, titleColor);
		
		fSize = to!(int)(btnSize);
		buttonFont = new Font(btnFont, fSize, btnStyle);
		setFontColor(buttonFont, btnColor);
	}

	void slurpWindow(Document!(char).Node n6, WindowStyle style) {
		foreach (n7; n6.children) switch (n7.name) {
		case "top-left":
			slurpTopLeft(n7, style);
		break;
		case "top":
			slurpTop(n7, style);
		break;
		case "top-right":
			slurpTopRight(n7, style);
		break;
		case "left":
			slurpLeft(n7, style);
		break;
		case "right":
			slurpRight(n7, style);
		break;
		case "bottom-left":
			slurpBottomLeft(n7, style);
		break;
		case "bottom":
			slurpBottom(n7, style);
		break;
		case "bottom-right":
			slurpBottomRight(n7, style);
		break;
		case "close":
			slurpClose(n7, style);
		break;
		case "minimize":
			slurpMinimize(n7, style);
		break;
		case "lock":
			slurpLock(n7, style);
		break;
		case "title":
			slurpTitle(n7, style);
		break;
		default:
		break;
		}
	}
	
	void slurpTopLeft(Document!(char).Node n7, WindowStyle style) {
		foreach (attr; n7.attributes) switch (attr.name) {
		case "image":
			window[
				style
			][
				SkinWindowEnums.TOP_LEFT
			][
				SkinWindowEnums.IMAGE
			] = attr.value.dup;
		break;
		default:
		break;
		}
	}
	
	void slurpTop(Document!(char).Node n7, WindowStyle style) {
		foreach (attr; n7.attributes) switch (attr.name) {
		case "image":
			window[
				style
			][
				SkinWindowEnums.TOP
			][
				SkinWindowEnums.IMAGE
			] = attr.value.dup;
		break;
		default:
		break;
		}
	}
	
	void slurpTopRight(Document!(char).Node n7, WindowStyle style) {
		foreach (attr; n7.attributes) switch (attr.name) {
		case "image":
			window[
				style
			][
				SkinWindowEnums.TOP_RIGHT
			][
				SkinWindowEnums.IMAGE
			] = attr.value.dup;
		break;
		default:
		break;
		}
	}
	
	void slurpLeft(Document!(char).Node n7, WindowStyle style) {
		foreach (attr; n7.attributes) switch (attr.name) {
		case "image":
			window[
				style
			][
				SkinWindowEnums.LEFT
			][
				SkinWindowEnums.IMAGE
			] = attr.value.dup;
		break;
		default:
		break;
		}
	}
	
	void slurpRight(Document!(char).Node n7, WindowStyle style) {
		foreach (attr; n7.attributes) switch (attr.name) {
		case "image":
			window[
				style
			][
				SkinWindowEnums.RIGHT
			][
				SkinWindowEnums.IMAGE
			] = attr.value.dup;
		break;
		default:
		break;
		}
	}
	
	void slurpBottomLeft(Document!(char).Node n7, WindowStyle style) {
		foreach (attr; n7.attributes) switch (attr.name) {
		case "image":
			window[
				style
			][
				SkinWindowEnums.BOTTOM_LEFT
			][
				SkinWindowEnums.IMAGE
			] = attr.value.dup;
		break;
		default:
		break;
		}
	}
	
	void slurpBottom(Document!(char).Node n7, WindowStyle style) {	// Go on! Slurp bottom!
		foreach (attr; n7.attributes) switch (attr.name) {
		case "image":
			window[
				style
			][
				SkinWindowEnums.BOTTOM
			][
				SkinWindowEnums.IMAGE
			] = attr.value.dup;
		break;
		default:
		break;
		}
	}
	
	void slurpBottomRight(Document!(char).Node n7, WindowStyle style) {
		foreach (attr; n7.attributes) switch (attr.name) {
		case "image":
			window[
				style
			][
				SkinWindowEnums.BOTTOM_RIGHT
			][
				SkinWindowEnums.IMAGE
			] = attr.value.dup;
		break;
		default:
		break;
		}
	}
	
	void slurpClose(Document!(char).Node n7, WindowStyle style) {
		foreach (attr; n7.attributes) switch (attr.name) {
		case "normal":
			window[
				style
			][
				SkinWindowEnums.CLOSE
			][
				SkinWindowEnums.NORMAL
			] = attr.value.dup;
		break;
		case "hover":
			window[
				style
			][
				SkinWindowEnums.CLOSE
			][
				SkinWindowEnums.HOVER
			] = attr.value.dup;
		break;
		case "pressed":
			window[
				style
			][
				SkinWindowEnums.CLOSE
			][
				SkinWindowEnums.PRESSED
			] = attr.value.dup;
		break;
		case "h":
			window[
				style
			][
				SkinWindowEnums.CLOSE
			][
				SkinWindowEnums.H
			] = attr.value.dup;
		break;
		case "v":
			window[
				style
			][
				SkinWindowEnums.CLOSE
			][
				SkinWindowEnums.V
			] = attr.value.dup;
		break;
		default:
		break;
		}
	}
	
	void slurpMinimize(Document!(char).Node n7, WindowStyle style) {
		foreach (attr; n7.attributes) switch (attr.name) {
		case "normal":
			window[
				style
			][
				SkinWindowEnums.MINIMIZE
			][
				SkinWindowEnums.NORMAL
			] = attr.value.dup;
		break;
		case "hover":
			window[
				style
			][
				SkinWindowEnums.MINIMIZE
			][
				SkinWindowEnums.HOVER
			] = attr.value.dup;
		break;
		case "pressed":
			window[
				style
			][
				SkinWindowEnums.MINIMIZE
			][
				SkinWindowEnums.PRESSED
			] = attr.value.dup;
		break;
		case "h":
			window[
				style
			][
				SkinWindowEnums.MINIMIZE
			][
				SkinWindowEnums.H
			] = attr.value.dup;
		break;
		case "v":
			window[
				style
			][
				SkinWindowEnums.MINIMIZE
			][
				SkinWindowEnums.V
			] = attr.value.dup;
		break;
		default:
		break;
		}
	}
	
	void slurpLock(Document!(char).Node n7, WindowStyle style) {
		foreach (attr; n7.attributes) switch (attr.name) {
		case "unlocked":
			window[
				style
			][
				SkinWindowEnums.LOCK
			][
				SkinWindowEnums.UNLOCKED
			] = attr.value.dup;
		break;
		case "unlocked-pressed":
			window[
				style
			][
				SkinWindowEnums.LOCK
			][
				SkinWindowEnums.UNLOCKED_PRESSED
			] = attr.value.dup;
		break;
		case "unlocked-hover":
			window[
				style
			][
				SkinWindowEnums.LOCK
			][
				SkinWindowEnums.UNLOCKED_HOVER
			] = attr.value.dup;
		break;
		case "locked":
			window[
				style
			][
				SkinWindowEnums.LOCK
			][
				SkinWindowEnums.LOCKED
			] = attr.value.dup;
		break;
		case "locked-pressed":
			window[
				style
			][
				SkinWindowEnums.LOCK
			][
				SkinWindowEnums.LOCKED_PRESSED
			] = attr.value.dup;
		break;
		case "locked-hover":
			window[
				style
			][
				SkinWindowEnums.LOCK
			][
				SkinWindowEnums.LOCKED_HOVER
			] = attr.value.dup;
		break;
		case "h":
			window[
				style
			][
				SkinWindowEnums.LOCK
			][
				SkinWindowEnums.H
			] = attr.value.dup;
		break;
		case "v":
			window[
				style
			][
				SkinWindowEnums.LOCK
			][
				SkinWindowEnums.V
			] = attr.value.dup;
		break;
		default:
		break;
		}
	}
	
	void slurpTitle(Document!(char).Node n7, WindowStyle style) {
		foreach (attr; n7.attributes) switch (attr.name) {
		case "h":
			window[
				style
			][
				SkinWindowEnums.TITLE
			][
				SkinWindowEnums.H
			] = attr.value.dup;
		break;
		case "v":
			window[
				style
			][
				SkinWindowEnums.TITLE
			][
				SkinWindowEnums.V
			] = attr.value.dup;
		break;
		case "width":
			window[
				style
			][
				SkinWindowEnums.TITLE
			][
				SkinWindowEnums.WIDTH
			] = attr.value.dup;
		break;
		case "height":
			window[
				style
			][
				SkinWindowEnums.TITLE
			][
				SkinWindowEnums.HEIGHT
			] = attr.value.dup;
		break;
		default:
		break;
		}
	}
	
	void slurpButton(Document!(char).Node n3, SkinButtonEnums style) {
		foreach (attr; n3.attributes) switch (attr.name) {
		case "left":
			button[style][SkinButtonEnums.LEFT] = attr.value.dup;
		break;
		case "middle":
			button[style][SkinButtonEnums.MIDDLE] = attr.value.dup;
		break;
		case "right":
			button[style][SkinButtonEnums.RIGHT] = attr.value.dup;
		break;
		default:
		break;
		}
	}
	
	void slurpScrollbar(Document!(char).Node n3, SkinScrollEnums style) {
		foreach (n4; n3.children) switch (n4.name) {
		case "left":
			slurpScrollItem(n4, style, (style == SkinScrollEnums.HORIZONTAL) ? SkinScrollEnums.H_LEFT : SkinScrollEnums.BH_LEFT);
		break;
		case "h-middle":
			slurpScrollItem(n4, style, (style == SkinScrollEnums.HORIZONTAL) ? SkinScrollEnums.H_MIDDLE : SkinScrollEnums.BH_MIDDLE);
		break;
		case "right":
			slurpScrollItem(n4, style, (style == SkinScrollEnums.HORIZONTAL) ? SkinScrollEnums.H_RIGHT : SkinScrollEnums.BH_RIGHT);
		break;
		case "scroll-left":
			slurpScrollItem(n4, style, (style == SkinScrollEnums.HORIZONTAL) ? SkinScrollEnums.H_SCROLL_LEFT : SkinScrollEnums.BH_SCROLL_LEFT);
		break;
		case "scroll-h-middle":
			slurpScrollItem(n4, style, (style == SkinScrollEnums.HORIZONTAL) ? SkinScrollEnums.H_SCROLL_MIDDLE : SkinScrollEnums.BH_SCROLL_MIDDLE);
		break;
		case "scroll-right":
			slurpScrollItem(n4, style, (style == SkinScrollEnums.HORIZONTAL) ? SkinScrollEnums.H_SCROLL_RIGHT : SkinScrollEnums.BH_SCROLL_RIGHT);
		break;
		case "top":
			slurpScrollItem(n4, style, (style == SkinScrollEnums.VERTICAL) ? SkinScrollEnums.V_TOP : SkinScrollEnums.BV_TOP);
		break;
		case "v-middle":
			slurpScrollItem(n4, style, (style == SkinScrollEnums.VERTICAL) ? SkinScrollEnums.V_MIDDLE : SkinScrollEnums.BV_MIDDLE);
		break;
		case "bottom":
			slurpScrollItem(n4, style, (style == SkinScrollEnums.VERTICAL) ? SkinScrollEnums.V_BOTTOM : SkinScrollEnums.BV_BOTTOM);
		break;
		case "scroll-top":
			slurpScrollItem(n4, style, (style == SkinScrollEnums.VERTICAL) ? SkinScrollEnums.V_SCROLL_TOP : SkinScrollEnums.BV_SCROLL_TOP);
		break;
		case "scroll-v-middle":
			slurpScrollItem(n4, style, (style == SkinScrollEnums.VERTICAL) ? SkinScrollEnums.V_SCROLL_MIDDLE : SkinScrollEnums.BV_SCROLL_MIDDLE);
		break;
		case "scroll-bottom":
			slurpScrollItem(n4, style, (style == SkinScrollEnums.VERTICAL) ? SkinScrollEnums.V_SCROLL_BOTTOM : SkinScrollEnums.BV_SCROLL_BOTTOM);
		break;
		case "block":
			foreach (attr; n4.attributes) switch (attr.name) {
			case "image":
				scrollBlock = attr.value.dup;
			break;
			default:
			break;
			}
		break;
		default:
		break;
		}
	}
	
	void slurpScrollItem(Document!(char).Node n4, SkinScrollEnums style, SkinScrollEnums element) {
		foreach (attr; n4.attributes) switch (attr.name) {
		case "normal":
			scroll[style][element][SkinScrollEnums.NORMAL] = attr.value.dup;
		break;
		case "hover":
			scroll[style][element][SkinScrollEnums.HOVER] = attr.value.dup;
		break;
		case "pressed":
			scroll[style][element][SkinScrollEnums.PRESSED] = attr.value.dup;
		break;
		default:
		break;
		}
	}
}
