module aahz.widget.WindowManager;

import tango.io.Stdout;
import tango.util.container.LinkedList;
import tango.text.convert.Utf;
import tango.core.sync.Mutex;

import derelict.sdl.sdl;
import derelict.sdl.sdltypes;
import derelict.devil.il;
import derelict.opengl.gl;
import derelict.opengl.glu;

import aahz.widget.Viewport;
import aahz.widget.Widget;
import aahz.widget.Area;
import aahz.widget.Event;
import aahz.widget.Skin;
import aahz.controls.Keyboard;
import aahz.controls.Mouse;
import aahz.widget.Cursor;

struct WindowManager {
static private:
	LinkedList!(Widget)[10] widgets;
	Widget hoverWidget = null;
	
	sgcombo currComboCode = 0;
	sgcombo[ char[] ] comboNames;
	sgcombo[ sgkey[] ] comboKeys;
	LinkedList!(sgkey) keysDown;
	
	LinkedList!(Widget)[ sgevent ] eventListeners;
	bool[ Widget ] cursorListeners;
	
	Widget findHoverWidget(int x, int y) {	// Try to find the widget that the cursor is currently hovering over. However, ignore widgets which aren't listening for CURSOR so far as counting as an enter leave
		Widget res = null;
		bool foundBase = false;
		
		void checkSubWidgets(Widget w) {
			for (uint L = 0; L < w.children.length; L++) {
				for (uint L2 = 0; L2 < w.children[L].length; L2++) {
					foreach (child; w.children[L][L2]) {
						if (
							child.visible
							&& child.drawBox.left <= x
							&& child.drawBox.bottom <= y
							&& (child.drawBox.left + child.drawBox.width) > x
							&& (child.drawBox.bottom + child.drawBox.height) > y
							&& child.clipBox.left <= x
							&& child.clipBox.bottom <= y
							&& (child.clipBox.left + child.clipBox.width) > x
							&& (child.clipBox.bottom + child.clipBox.height) > y
						) {
							if ((child in cursorListeners) != null) {
								res = child;
								foundBase = true;
							}
							
							checkSubWidgets(child);
							if (foundBase) return; 
						}
					}
				}
			}
		}
		
		for (int L = (widgets.length - 1); L >= 0; L--) {	// Search from the highest to lowest level
			Widget[] ws = widgets[L].toArray();
			for (int L2 = (ws.length - 1); L2 >= 0; L2--) {	// ditto
				if (
					ws[L2].visible
					&& ws[L2].drawBox.left <= x
					&& ws[L2].drawBox.bottom <= y
					&& (ws[L2].drawBox.left + ws[L2].drawBox.width) > x
					&& (ws[L2].drawBox.bottom + ws[L2].drawBox.height) > y
					&& ws[L2].clipBox.left <= x
					&& ws[L2].clipBox.bottom <= y
					&& (ws[L2].clipBox.left + ws[L2].clipBox.width) > x
					&& (ws[L2].clipBox.bottom + ws[L2].clipBox.height) > y
				) {
					if ((ws[L2] in cursorListeners) != null) {
						res = ws[L2];
						foundBase = true;
					}
					
					checkSubWidgets(ws[L2]);
					if (foundBase) return res; 
				}
			}
		}
		return res;
	}
	
	bool checkCombo(out sgcombo combo) {
		uint keyCount = keysDown.size();
		if (keyCount == 0) {
			return false;
		}
		else if (keyCount == 1) {
			sgkey[] keys = keysDown.toArray();
			if ((keys in comboKeys) != null) {	// Combo is there
				combo = comboKeys[keys];	// send it back
				return true;	// Tell the caller that we've set combo
			}
			return false;
		}
		
		uint comboCount = comboKeys.length;
		sgkey[][] combos = comboKeys.keys;
		sgkey[] keys = keysDown.toArray();
		
		uint maxLength = 0;
		int index = -1;
		for (uint L = 0; L < comboCount; L++) {
			if (
				combos[L].length > maxLength	// No need to search it if we've already found a longer combo that matches
				&& combos[L][$-1] == keys[$-1]	// See if the last key in the combo matches the most recently pressed key. If so, check it completely
			) {
				uint want = 0;
				for (uint L2 = 0; L2 < keyCount; L2++) {	// See if we can find all of the keys in the combo in our down keys, in the correct order
					if (combos[L][want] == keys[L2]) ++want;
				}
				if (want == combos[L].length) {	// If we've found all of them, save it and move on
					maxLength = want;
					index = L;
				}
			}
		}
		
		if (index != -1) {
			combo = comboKeys[ combos[index] ];
			return true;
		}
		return false;
	}
	
static public:
	static this() {
		assert(SDLK_LAST <= 0xfff);	// Verify that our key codes all fit into Event.key
		assert(
			SDL_BUTTON_LEFT         == 1
			&& SDL_BUTTON_MIDDLE       == 2
			&& SDL_BUTTON_RIGHT        == 3
			&& SDL_BUTTON_WHEELUP      == 4
			&& SDL_BUTTON_WHEELDOWN    == 5
			&& SDL_BUTTON_X1           == 6
			&& SDL_BUTTON_X2           == 7
		);
		
		for (uint L = 0; L < widgets.length; L++) {
			widgets[L] = new LinkedList!(Widget);
		}
		keysDown = new LinkedList!(sgkey)();
	}
	
	void init() {
		SDL_EnableUNICODE(1);
		SDL_EventState(SDL_SYSWMEVENT, SDL_ENABLE);
	}
	
	void cleanup() {
		// reserved
	}
	
	void add(uint z, Widget w) {
		if (z >= widgets.length) throw new Exception("Invalid z-depth for WindowManager.add()");
		
		if (w.parent !is null) throw new Exception("Widgets may not be added to multiple locations");
		foreach (wList; widgets) {
			if (wList.contains(w)) throw new Exception("Widget is already added to WindowManager");
		}
		
		widgets[z].append(w);
	}
	
	void remove(Widget w) {
		foreach (wList; widgets) {
			wList.remove(w);
		}
	}
	
	bool doEvents() {
		SDL_Event event;

		while (SDL_PollEvent(&event)) {
			sgcombo combo;
			Event[] e;
			
			switch (event.type) {
				case SDL_QUIT:	// user has clicked on the window's close button
					return false;

				case SDL_ACTIVEEVENT:	// Application window focus

				break;
				case SDL_KEYDOWN:
					wchar[] utf16;
					e.length = 1;
					
					e[0].type = EventType.KEY_DOWN;
					e[0].key = cast(sgkey)event.key.keysym.sym;
					e[0].key |= KeySource.KEYBOARD;
					
					utf16.length = 1;
					utf16[0] = event.key.keysym.unicode;
					fromString16!(char)(utf16, e[0].utf8);
					
					keysDown.append(e[0].key);	// Check for combos
					if ( checkCombo(combo) ) {
						e.length = e.length + 1;
						e[$-1].type = EventType.COMBO;
						e[$-1].combo = combo;
					}
				break;
				case SDL_KEYUP:
					assert(SDLK_LAST <= 0xfff);
					wchar[] utf16;
					e.length = 1;
	
					e[0].type = EventType.KEY_UP;
					e[0].key = cast(sgkey)event.key.keysym.sym;
					e[0].key |= KeySource.KEYBOARD;
					
					utf16.length = 1;
					utf16[0] = event.key.keysym.unicode;
					fromString16!(char)(utf16, e[0].utf8);
					
					keysDown.remove(e[0].key);
				break;
				case SDL_MOUSEBUTTONDOWN:
					switch (event.button.button) {
					case SDL_BUTTON_X1:
					case SDL_BUTTON_X2:
					case SDL_BUTTON_LEFT:
					case SDL_BUTTON_RIGHT:
					case SDL_BUTTON_MIDDLE:
						e.length = 2;
						
						e[0].type = EventType.CURSOR_DOWN;
						e[0].key = cast(sgkey)event.button.button;
						e[0].key |= KeySource.MOUSE;
						
						e[1].type = EventType.KEY_DOWN;
						e[1].key = cast(sgkey)event.button.button;
						e[1].key |= KeySource.MOUSE;
					
						keysDown.append(e[1].key);	// Check for combos
						if ( checkCombo(combo) ) {
							e.length = e.length + 1;
							e[$-1].type = EventType.COMBO;
							e[$-1].combo = combo;
						}
					break;
					case SDL_BUTTON_WHEELUP:
						e.length = 1;
						e[0].type = EventType.MOUSEWHEEL_UP;
					break;
					case SDL_BUTTON_WHEELDOWN:
						e.length = 1;
						e[0].type = EventType.MOUSEWHEEL_DOWN;
					break;
					default:
					break;
					}
				break;
				case SDL_MOUSEBUTTONUP:
					switch (event.button.button) {
					case SDL_BUTTON_X1:
					case SDL_BUTTON_X2:
					case SDL_BUTTON_LEFT:
					case SDL_BUTTON_RIGHT:
					case SDL_BUTTON_MIDDLE:
						e.length = 2;
						
						e[0].type = EventType.CURSOR_UP;
						e[0].key = cast(sgkey)event.button.button;
						e[0].key |= KeySource.MOUSE;
						
						e[1].type = EventType.KEY_UP;
						e[1].key = cast(sgkey)event.button.button;
						e[1].key |= KeySource.MOUSE;
						
						keysDown.remove(e[1].key);
					break;
					default:	// ignore mousewheel
					break;
					}
				break;
				case SDL_MOUSEMOTION:
					Cursor.prevX = Cursor.x;
					Cursor.prevY = Cursor.y;
					Cursor.x = event.motion.x;
					Cursor.y = Viewport.height - event.motion.y;
					
					e.length = 1;
					e[0].type = EventType.MOVE1;
					e[0].diffX = event.motion.xrel;
					e[0].diffY = -event.motion.yrel;
					
					Widget newHover = findHoverWidget(Cursor.x, Cursor.y);
					if (newHover !is hoverWidget) {	// We have to process these here
						Event exunt, entre;
						exunt.type = EventType.CURSOR_LEAVE;
						entre.type = EventType.CURSOR_ENTER;
						
						if (hoverWidget !is null) hoverWidget.event(exunt);
						if (newHover !is null) newHover.event(entre);
						hoverWidget = newHover;
					}
				break;
				case SDL_JOYAXISMOTION:
					
				break;
				case SDL_JOYBALLMOTION:
					
				break;
				case SDL_JOYHATMOTION:
					
				break;
				case SDL_JOYBUTTONDOWN:
					
				break;
				case SDL_JOYBUTTONUP:
					
				break;
				case SDL_SYSWMEVENT:	// can be used for copy and paste (somehow)
					
				break;
				case SDL_VIDEORESIZE:
					Viewport.reshape(event.resize.w, event.resize.h);
				break;
//				case SDL_VIDEOEXPOSE:	// Monitor resolution set outside of app // Seems to be called on regular window resizing so I'm commenting it out
//					Viewport.reshape(1, 1);	// Resize to whatever the minimum window size is
//				break;
				default:
				break;
			}
			
			foreach (currE; e) {
				switch (currE.type) {
				case EventType.COMBO:
					if ((currE.value in eventListeners) != null) foreach (w; eventListeners[currE.value]) {
						w.event(currE);
					}
				break;
				case EventType.KEY_DOWN:
				case EventType.KEY_UP:
					Event all, specific;
					all.type = currE.type;
					specific.type = currE.type;
					specific.key = currE.key;
					
					if ((all.value in eventListeners) != null) foreach (w; eventListeners[all.value]) {
						w.event(currE);
					}
					if ((specific.value in eventListeners) != null) foreach (w; eventListeners[specific.value]) {
						w.event(currE);
					}
				break;
				case EventType.CURSOR_DOWN:
					if (hoverWidget !is null) {
						Widget curr = hoverWidget;
						Widget wTop = hoverWidget;
						while ((curr = curr.parent) !is null) {	// Find the topmost parent (the one that is sitting in WindowManager.widgets)
							wTop = curr;
						}
						foreach (wList; widgets) {
							if (
								wList.last(wTop) != -1	// If the item is in the list
								&& wList.last(wTop) != (wList.size - 1)	// And if the element isn't the top "window"
							) {
								wList.remove(wTop);	// Move to top
								wList.append(wTop);
								break;
							}
						}
						hoverWidget.event(currE);	// Send the event
					}
				break;
				case EventType.CURSOR_UP:
					if (hoverWidget !is null) hoverWidget.event(currE);
				break;
				case EventType.MOVE1:
				case EventType.MOVE2:
				case EventType.MOVE3:
					Event all;
					all.type = currE.type;
					if ((all.value in eventListeners) != null) foreach (w; eventListeners[all.value]) {
						w.event(currE);
					}
				break;
				case EventType.MOUSEWHEEL_DOWN:
				case EventType.MOUSEWHEEL_UP:
					if ((currE.value in eventListeners) != null) foreach (w; eventListeners[currE.value]) {
						w.event(currE);
					}
				break;
				default:
				break;
				}
			}
		}
		return true;
	}
	
	void paint() {
		Viewport.startPaint();
		
		Area view;
		
		view.left = 0;
		view.bottom = 0;
		view.width = Viewport.width;
		view.height = Viewport.height;
		
		for (uint L = 0; L < widgets.length; L++) {
			foreach (w; widgets[L]) {
				if (w.visible) w.updatePosition(view, view);
			}
		}
		
		for (uint L = 0; L < widgets.length; L++) {
			foreach (w; widgets[L]) {
				if (w.visible) w.paint();
			}
		}
		
		Viewport.endPaint();
	}
	
	// COMBO
	
	sgcombo createCombo(char[] comboName) {
		++currComboCode;
		comboNames[ comboName.dup ] = currComboCode;
		return currComboCode;
	}
	
	void registerComboKeys(sgcombo code, sgkey[] keys) {
		comboKeys[ keys.dup ] = code;
	}
	
	void unregisterComboKeys(sgkey[] keys) {
		comboKeys.remove(keys);
	}
	
	void deleteCombo(uint code) {
		foreach (keys; comboKeys.keys) {
			if ( comboKeys[keys] == code ) {
				comboKeys.remove(keys);
			}
		}
		foreach (names; comboNames.keys) {
			if ( comboNames[names] == code ) {
				comboNames.remove(names);
			}
		}
	}
	
	// LISTENERS

	void listenCursor(Widget w) {
		Event[4] e;
		e[0].type = EventType.CURSOR_DOWN;
		e[1].type = EventType.CURSOR_UP;
		e[2].type = EventType.CURSOR_ENTER;
		e[3].type = EventType.CURSOR_LEAVE;
		
		cursorListeners[w] = true;
		
		for (uint L = 0; L < e.length; L++) {
			if ((e[L].value in eventListeners) == null) {
				eventListeners[e[L].value] = new LinkedList!(Widget)();
			}
			eventListeners[e[L].value].append(w);
		}
	}
	
	void unlistenCursor(Widget w) {
		Event[4] e;
		e[0].type = EventType.CURSOR_DOWN;
		e[1].type = EventType.CURSOR_UP;
		e[2].type = EventType.CURSOR_ENTER;
		e[3].type = EventType.CURSOR_LEAVE;
		
		cursorListeners.remove(w);
		
		for (uint L = 0; L < e.length; L++) {
			if ((e[L].value in eventListeners) != null) {
				eventListeners[e[L].value].remove(w);
			}
		}
	}

	void listenCombo(Widget w, sgcombo combo) {
		Event e;
		e.type = EventType.COMBO;
		e.combo = combo;
		
		if ((e.value in eventListeners) == null) {
			eventListeners[e.value] = new LinkedList!(Widget)();
		}
		eventListeners[e.value].append(w);
	}
	
	void unlistenCombo(Widget w, sgcombo combo) {
		Event e;
		e.type = EventType.COMBO;
		e.combo = combo;
		
		if ((e.value in eventListeners) != null) {
			eventListeners[e.value].remove(w);
		}
	}

	void listenMove1(Widget w) {
		Event e;
		e.type = EventType.MOVE1;
		
		if ((e.value in eventListeners) == null) {
			eventListeners[e.value] = new LinkedList!(Widget)();
		}
		eventListeners[e.value].append(w);
	}
	
	void unlistenMove1(Widget w) {
		Event e;
		e.type = EventType.MOVE1;
		
		if ((e.value in eventListeners) != null) {
			eventListeners[e.value].remove(w);
		}
	}

	void listenMove2(Widget w) {
		Event e;
		e.type = EventType.MOVE2;
		
		if ((e.value in eventListeners) == null) {
			eventListeners[e.value] = new LinkedList!(Widget)();
		}
		eventListeners[e.value].append(w);
	}
	
	void unlistenMove2(Widget w) {
		Event e;
		e.type = EventType.MOVE2;
		
		if ((e.value in eventListeners) != null) {
			eventListeners[e.value].remove(w);
		}
	}

	void listenMove3(Widget w) {
		Event e;
		e.type = EventType.MOVE3;
		
		if ((e.value in eventListeners) == null) {
			eventListeners[e.value] = new LinkedList!(Widget)();
		}
		eventListeners[e.value].append(w);
	}
	
	void unlistenMove3(Widget w) {
		Event e;
		e.type = EventType.MOVE3;
		
		if ((e.value in eventListeners) != null) {
			eventListeners[e.value].remove(w);
		}
	}
	
	void listenKeys(Widget w) {
		Event[2] e;
		e[0].type = EventType.KEY_DOWN;
		e[1].type = EventType.KEY_UP;
		
		for (uint L = 0; L < e.length; L++) {
			if ((e[L].value in eventListeners) == null) {
				eventListeners[e[L].value] = new LinkedList!(Widget)();
			}
			eventListeners[e[L].value].append(w);
		}
	}
	
	void listenKey(Widget w, Key source) {
		Event[2] e;
		e[0].type = EventType.KEY_DOWN;
		e[1].type = EventType.KEY_UP;
		e[0].key = source;
		e[1].key = source;
		
		for (uint L = 0; L < e.length; L++) {
			if ((e[L].value in eventListeners) == null) {
				eventListeners[e[L].value] = new LinkedList!(Widget)();
			}
			eventListeners[e[L].value].append(w);
		}
	}
	
	void unlistenKeys(Widget w) {
		Event[2] e;
		e[0].type = EventType.KEY_DOWN;
		e[1].type = EventType.KEY_UP;
		
		for (uint L = 0; L < e.length; L++) {
			if ((e[L].value in eventListeners) != null) {
				eventListeners[e[L].value].remove(w);
			}
		}
	}
	
	void unlistenKey(Widget w, Key source) {
		Event[2] e;
		e[0].type = EventType.KEY_DOWN;
		e[1].type = EventType.KEY_UP;
		e[0].key = source;
		e[1].key = source;
		
		for (uint L = 0; L < e.length; L++) {
			if ((e[L].value in eventListeners) != null) {
				eventListeners[e[L].value].remove(w);
			}
		}
	}

	void listenMouseWheel(Widget w) {
		Event[2] e;
		e[0].type = EventType.MOUSEWHEEL_UP;
		e[1].type = EventType.MOUSEWHEEL_DOWN;
		
		for (uint L = 0; L < e.length; L++) {
			if ((e[L].value in eventListeners) == null) {
				eventListeners[e[L].value] = new LinkedList!(Widget)();
			}
			eventListeners[e[L].value].append(w);
		}
	}
	
	void unlistenMouseWheel(Widget w) {
		Event[2] e;
		e[0].type = EventType.MOUSEWHEEL_UP;
		e[1].type = EventType.MOUSEWHEEL_DOWN;
		
		for (uint L = 0; L < e.length; L++) {
			if ((e[L].value in eventListeners) != null) {
				eventListeners[e[L].value].remove(w);
			}
		}
	}
	
	// SKIN

	void loadSkin(char[] name) {	// Set to "" for default
		if (!Skin.inited) throw new Exception("aahz.widget.Skin must be initialised first");
		Skin.load(name);
		
		for (uint L = 0; L < widgets.length; L++) {
			foreach (w; widgets[L]) {
				w.reskin();
			}
		}
	}
}
