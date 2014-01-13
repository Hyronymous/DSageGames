module aahz.widget.Cursor;

import derelict.sdl.sdl;

enum CursorStyle {
	NORMAL = 0,
	UP_DOWN = 1,
	LEFT_RIGHT = 2
}

class Cursor {
private:
	static CursorStyle currStyle = CursorStyle.NORMAL;
	static SDL_Cursor*[] cursors;
	
	static char[][] arrow = [
		".                               ",
		"..                              ",
		".X.                              ",
		".XX.                            ",
		".XXX.                           ",
		".XXXX.                          ",
		".XXXXX.                         ",
		".XXXXXX.                        ",
		".XXXXXXX.                       ",
		".XXXXXXXX.                      ",
		".XXXXXXXXX.                     ",
		".XXXXXXXXXX.                    ",
		".XXXXXXXXXXX.                   ",
		".XXXXXXXXXXXX.                  ",
		".XXXXXXXXXXXXX.                 ",
		".XXXXXXXXXXXXXX.                ",
		".XXXXXXXXXXXXXXX.               ",
		".XXXXXXX..........              ",
		".XXXXXX.                        ",
		".XXXXX.                         ",
		".XXXX.                          ",
		".XXX.      ...                  ",
		".XX.      .XXX.                 ",
		".X.      .XXXXX.                ",
		"..      .XXXXXXX.               ",
		".       .XXXXXXX.               ",
		"        .XXXXXXX.               ",
		"         .XXXXX.                ",
		"          .XXX.                 ",
		"           ...                  ",
		"                                ",
		"                                "
	];
	static int arrHotX = 0, arrHotY = 0;
	
	static char[][] upDown = [
		"      .                         ",
		"     .X.                        ",
		"    .XXX.                       ",
		"   .XXXXX.                      ",
		"  .XXXXXXX.                     ",
		" .XXXXXXXXX.                    ",
		"....XXXXX....                   ",
		"   .XXXXX.                      ",
		"   .XXXXX.                      ",
		"   .XXXXX.                      ",
		"   .XXXXX.                      ",
		"   .XXXXX.                      ",
		"   .XXXXX.                      ",
		"   .XXXXX.                      ",
		"   .XXXXX.                      ",
		"   .XXXXX.                      ",
		"   .XXXXX.                      ",
		"   .XXXXX.                      ",
		"   .XXXXX.                      ",
		"   .XXXXX.                      ",
		"   .XXXXX.                      ",
		"   .XXXXX.                      ",
		"....XXXXX....                   ",
		" .XXXXXXXXX.                    ",
		"  .XXXXXXX.                     ",
		"   .XXXXX.                      ",
		"    .XXX.                       ",
		"     .X.                        ",
		"      .                         ",
		"                                ",
		"                                ",
		"                                "
	];
	static int udHotX = 7, udHotY = 15;
	
	static char[][] leftRight = [
		"      .               .         ",
		"     ..               ..        ",
		"    .X.               .X.       ",
		"   .XX.................XX.      ",
		"  .XXXXXXXXXXXXXXXXXXXXXXX.     ",
		" .XXXXXXXXXXXXXXXXXXXXXXXXX.    ",
		".XXXXXXXXXXXXXXXXXXXXXXXXXXX.   ",
		" .XXXXXXXXXXXXXXXXXXXXXXXXX.    ",
		"  .XXXXXXXXXXXXXXXXXXXXXXX.     ",
		"   .XX.................XX.      ",
		"    .X.               .X.       ",
		"     ..               ..        ",
		"      .               .         ",
		"                                ",
		"                                ",
		"                                ",
		"                                ",
		"                                ",
		"                                ",
		"                                ",
		"                                ",
		"                                ",
		"                                ",
		"                                ",
		"                                ",
		"                                ",
		"                                ",
		"                                ",
		"                                ",
		"                                ",
		"                                ",
		"                                "
	];
	static int lrHotX = 15, lrHotY = 7;
	
	static SDL_Cursor* toCursor(char[][] image, int hot_x, int hot_y) {
		int i, row, col;
		ubyte data[4*32];
		ubyte mask[4*32];

		i = -1;
		for ( row=0; row<32; ++row ) {
			for ( col=0; col<32; ++col ) {
				if ( col % 8 ) {
					data[i] <<= 1;
					mask[i] <<= 1;
				}
				else {
					++i;
					data[i] = mask[i] = 0;
				}
				switch (image[row][col]) {
				case 'X':
					data[i] |= 0x01;
					mask[i] |= 0x01;
				break;
				case '.':
					mask[i] |= 0x01;
				break;
				case ' ':
				break;
				}
			}
		}
		return SDL_CreateCursor(data.ptr, mask.ptr, 32, 32, hot_x, hot_y);
	}
	
public:
	static int prevX, prevY;
	static int x, y;
	static int diffX, diffY;
	
	static void init() {
		cursors.length = CursorStyle.max + 1;
		cursors[CursorStyle.NORMAL] = toCursor(arrow, arrHotX, arrHotY);
		cursors[CursorStyle.UP_DOWN] = toCursor(upDown, udHotX, udHotY);
		cursors[CursorStyle.LEFT_RIGHT] = toCursor(leftRight, lrHotX, lrHotY);
		
		SDL_SetCursor( cursors[CursorStyle.NORMAL] );
	}
	
	static void cleanup() {
		SDL_FreeCursor(cursors[CursorStyle.UP_DOWN]);
		SDL_FreeCursor(cursors[CursorStyle.LEFT_RIGHT]);
	}
	
	static void setStyle(CursorStyle style) {
		SDL_SetCursor( cursors[style] );
	}
}
