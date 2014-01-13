module aahz.widget.Viewport;

import derelict.sdl.sdl;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.wgl;
import derelict.util.exception;

import derelict.devil.il;
import derelict.devil.ilu;
import derelict.devil.ilut;
import derelict.freetype.ft;

import tango.io.Stdout;
import tango.util.Convert;

import aahz.render.Camera;
import aahz.math.Matrix;
import aahz.widget.Area;
import aahz.draw.Graphics;
import aahz.draw.Font;
import aahz.shared.shared;

version (Windows) {
	import tango.sys.win32.Types;
	import tango.sys.win32.UserGdi;
}

class Viewport {
private:
	enum ViewType {
		NONE,
		_3D,
		_2D
	}
	static char[] m_title;
	static int m_width = 640;
	static int m_height = 480;
	static ViewType currType = ViewType.NONE;
	static uint m_time = 0;
	static uint m_interval = 0;
	
	static uint[10] m_intervals;
	static uint m_intervalIndex = 0;
	
	version (Windows) {
		static HGLRC context = null;
	}
	
	static void start2D(Area a) {
		glViewport( 0, 0, m_width, m_height);
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		gluOrtho2D(0.0f, cast(float)Viewport.width, 0.0f, cast(float)Viewport.height);
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
		
		glEnable(GL_SCISSOR_TEST);	// Enable scissoring
		glScissor(a.left, a.bottom, a.width, a.height);
	}
	
	static void start3D(Camera c, Area a) {
		glViewport( a.left, a.bottom, a.width, a.height );
		float ratio = cast(float)a.width / cast(float)a.height;

		glMatrixMode(GL_PROJECTION);		
		glLoadIdentity();
		gluPerspective(
			c.fov,
			ratio,
			c.near,
			c.far
		);

		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
		
		Matrix transform;
		transform = c.getMatrix();
		glMultMatrixf(transform.data.ptr);
	}
	
	static void end2D() {
		glDisable(GL_SCISSOR_TEST);
	}
	
	static void end3D() {
	}
	
public:
	static void init(char[] title, uint width, uint height) {
		m_title = title.dup;
		m_width = width;
		m_height = height;
		
		AAHZ_loadSDL();
		AAHZ_loadGL();
		
		SDL_SetVideoMode(
			m_width,
			m_height,
			32,
			SDL_OPENGL | SDL_RESIZABLE
		);
		SDL_GL_SetAttribute( SDL_GL_DOUBLEBUFFER, 1 );
		
		version (Windows) {
			SDL_SysWMinfo wInfo;
			HDC hDC;
			
			int res = SDL_GetWMInfo(&wInfo);
			if (res == -1) goto NO_LOVE;
			
			hDC = GetDC( wInfo.window );
			if (hDC is null) goto NO_LOVE;
				
			context = wglCreateContext( hDC );
			if (context is null) goto NO_LOVE;
			
			wglMakeCurrent( hDC, context );			
			try {
				DerelictGL.loadVersions(GLVersion.Version21);	// Get it to load whatever the most recent driver version is
			}
			catch(SharedLibProcLoadException slple) {}
			
NO_LOVE:	;

		}
		
		SDL_SetVideoMode(
			m_width,
			m_height,
			32,
			SDL_OPENGL | SDL_RESIZABLE
		);
		glClearColor(0.0f, 0.0f, 0, 0);
		
		
		SDL_WM_SetCaption(m_title.ptr, null);
	}
	
	static void cleanup() {
		version (Windows) {
			if (context !is null) wglDeleteContext( context );
		}
		
		AAHZ_unloadGL();
		AAHZ_unloadSDL();
	}
	
	static void reshape(uint width, uint height) {
		if (width < 640) width = 640;
		if (height < 480) height = 480;
		
		m_width = width;
		m_height = height;
		
		SDL_SetVideoMode(
			m_width,
			m_height,
			32,
			SDL_OPENGL | SDL_RESIZABLE
		);
		glClearColor(0.0f, 0.0f, 0, 0);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);	// Turn on alpha blending
		glEnable(GL_BLEND);
	}
	
	static void startPaint() {
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		
		uint newTime = SDL_GetTicks();
		if (newTime < m_time) {	// looped
			m_interval = uint.max - m_time + newTime;
			m_time = newTime;
		}
		else {			
			m_interval = newTime - m_time;
			m_time = newTime;
		}
		m_intervals[ m_intervalIndex ] = m_interval;
		++m_intervalIndex;
		if (m_intervalIndex >= m_intervals.length) m_intervalIndex = 0;
		
		glEnable(GL_BLEND);	// enable blending
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);	// Turn on alpha blending
	}
	
	static void endPaint() {
		switch (currType) {
		case ViewType._2D:
			end2D();
		break;
		case ViewType._3D:
			end3D();
		break;
		default:
		break;
		}
		currType = ViewType.NONE;
		
		glDisable(GL_BLEND);
		SDL_GL_SwapBuffers();
	}
	
	static void do2D(Area a) {
		switch (currType) {
		case ViewType.NONE:
			start2D(a);
		break;
		case ViewType._2D:
			glScissor(a.left, a.bottom, a.width, a.height);
		break;
		case ViewType._3D:
			end3D();
			start2D(a);
		break;
		}
		currType = ViewType._2D;
	}
	
	static void do3D(Camera c, Area a) {
		switch (currType) {
		case ViewType.NONE:
			start3D(c, a);
		break;
		case ViewType._2D:
			end2D();
			start3D(c, a);
		break;
		case ViewType._3D:
			glViewport( a.left, a.bottom, a.width, a.height );
			float ratio = cast(float)width / cast(float)height;

			glMatrixMode(GL_PROJECTION);		
			glLoadIdentity();
			gluPerspective(
				c.fov,
				ratio,
				c.near,
				c.far
			);

			glMatrixMode(GL_MODELVIEW);
			glLoadIdentity();
			
			Matrix transform;
			transform = c.getMatrix();
			glMultMatrixf(transform.data.ptr);
		break;
		}
		currType = ViewType._3D;
	}
	
	static void setClip(Area a) {
		glScissor(a.left, a.bottom, a.width, a.height);
	}
	
	static int width() {
		return m_width;
	}
	
	static int height() {
		return m_height;
	}
	
	static uint time() {
		return m_time;
	}
	
	static uint interval() {
		return m_interval;
	}
	
	static uint getFPS() {
		uint sum;
		foreach (item; m_intervals) sum += item;
		float fps = 1000.0f / cast(float)sum;
		fps *= m_intervals.length;
		
		return to!(uint)(fps);
	}
}
