module aahz.shared.shared;

import tango.core.sync.Mutex;

import derelict.sdl.sdl;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.devil.il;
import derelict.devil.ilu;
import derelict.devil.ilut;
import derelict.freetype.ft;

private:
int sdlLoaded = 0;
int ilLoaded = 0;
int glLoaded = 0;
int ftLoaded = 0;

public:
FT_Library ft_library;

void AAHZ_loadSDL() {
	if (sdlLoaded == 0) {
		DerelictSDL.load();
		SDL_Init( SDL_INIT_VIDEO | SDL_INIT_JOYSTICK );
	}
	++sdlLoaded;
}

void AAHZ_unloadSDL() {
	if (sdlLoaded == 0) return;
	--sdlLoaded;
	if (sdlLoaded == 0) {
		SDL_Quit();
		DerelictSDL.unload();
	}
}

void AAHZ_loadIL() {
	if (ilLoaded == 0) {
		DerelictIL.load();
		DerelictILU.load();
		DerelictILUT.load();
		
		ilInit();
		iluInit();
		
		AAHZ_loadGL();
		ilutRenderer(ILUT_OPENGL);
	}
	++ilLoaded;
}

void AAHZ_unloadIL() {
	if (ilLoaded == 0) return;
	--ilLoaded;
	if (ilLoaded == 0) {
		AAHZ_unloadGL();
		
		DerelictILUT.unload();
		DerelictILU.unload();
		DerelictIL.unload();
	}
}

void AAHZ_loadGL() {
	if (glLoaded == 0) {
		DerelictGL.load();
		DerelictGLU.load();
	}
	++glLoaded;
}

void AAHZ_unloadGL() {
	if (glLoaded == 0) return;
	--glLoaded;
	if (glLoaded == 0) {
		DerelictGLU.unload();
		DerelictGL.unload();
	}
}

void AAHZ_loadFT() {
	if (ftLoaded == 0) {
		DerelictFT.load();
		FT_Error res = FT_Init_FreeType(&ft_library);
		if (0 != res) throw new Exception("FreeType could not be initialized");
	}
	++ftLoaded;
}

void AAHZ_unloadFT() {
	if (ftLoaded == 0) return;
	--ftLoaded;
	if (ftLoaded == 0) {
		FT_Done_FreeType(ft_library);
		DerelictFT.unload();
	}
}
