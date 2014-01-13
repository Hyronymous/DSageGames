module aahz.draw.Graphics;

import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.devil.il;
import derelict.freetype.ft;

import aahz.widget.Viewport;
import aahz.widget.Area;
import aahz.draw.Image;
import aahz.draw.Color;
import aahz.draw.Font;
import aahz.util.String;

import tango.io.Stdout;

scope class Graphics {
private:
	int m_left, m_bottom, m_width, m_height;
	Color4ub m_color;
	
public:
	this(int left, int bottom, int width, int height) {
		m_left = left;
		m_bottom = bottom;
		m_width = width;
		m_height = height;
	}
	
	this(Area area) {
		m_left = area.left;
		m_bottom = area.bottom;
		m_width = area.width;
		m_height = area.height;
	}
	
	void setColor(Color4ub c) {
		m_color = c;
		glColor4ubv(m_color.data.ptr);
	}
	
	void setColor(Color3ub c) {
		m_color = c;
		glColor4ubv(m_color.data.ptr);
	}
	
	void setColor(Color4f c) {
		m_color = c;
		glColor4ubv(m_color.data.ptr);
	}
	
	void setColor(Color3f c) {
		m_color = c;
		glColor4ubv(m_color.data.ptr);
	}
	
	void setColor(ubyte r, ubyte g, ubyte b, ubyte a = 0xff) {
		m_color.set(r, g, b, a);
		glColor4ubv(m_color.data.ptr);
	}
	
	void setColor(float r, float g, float b, float a = 1.0f) {
		m_color.set(r, g, b, a);
		glColor4ubv(m_color.data.ptr);
	}
	
	void drawImage(Image i, int left, int bottom) {
		int drawX = m_left + left;
		int drawY = m_bottom + bottom;
		GLenum format, type;
		
		switch (i.type) {
		case ImageType.RGBA:
			format = GL_RGBA;
			type = GL_UNSIGNED_INT_8_8_8_8_REV;
		break;
		case ImageType.RGB:
			format = GL_RGB;
			type = GL_UNSIGNED_BYTE;
		break;
		case ImageType.GREYSCALE:
			format = GL_LUMINANCE;
			type = GL_UNSIGNED_BYTE;
		break;
		case ImageType.GREYSCALE_ALPHA:
			format = GL_LUMINANCE_ALPHA;
			type = GL_UNSIGNED_SHORT;
		break;
		case ImageType.BITMAP:
			format = GL_BITMAP;
			type = GL_UNSIGNED_BYTE;
		break;
		}
		
		if (drawX < 0) {	// glRasterPos() won't accept negative values, so we need to skew the viewport
			if (drawY < 0) {	// both are negative
				glViewport(drawX, drawY, Viewport.width - drawX, Viewport.height - drawY);
				
				glRasterPos2i(
					0,
					0
				);
				glDrawPixels(
					i.width,
					i.height,
					format,
					type,
					i.data
				);
				
				glViewport(0, 0, Viewport.width, Viewport.height);
			}
			else {	// only drawX is negative
				glViewport(drawX, 0, Viewport.width - drawX, Viewport.height);
				
				glRasterPos2i(
					0,
					drawY
				);
				glDrawPixels(
					i.width,
					i.height,
					format,
					type,
					i.data
				);
				
				glViewport(0, 0, Viewport.width, Viewport.height);
			}
		}
		else if (drawY < 0) {	// only drawY is negative
			glViewport(0, drawY, Viewport.width, Viewport.height - drawY);
			
			glRasterPos2i(
				drawX,
				0
			);
			glDrawPixels(
				i.width,
				i.height,
				format,
				type,
				i.data
			);
			
			glViewport(0, 0, Viewport.width, Viewport.height);
		}
		else {	// Draw normal
			glRasterPos2i(
				drawX,
				drawY
			);
			glDrawPixels(
				i.width,
				i.height,
				format,
				type,
				i.data
			);
		}
	}
	
	void fillSquare(int left, int bottom, int width, int height) {
		int drawX = m_left + left;
		int drawY = m_bottom + bottom;
		glRecti( drawX, drawY, drawX + width, drawY + height );
	}
	
	void fillSquare(Area a) {
		int drawX = m_left + a.left;
		int drawY = m_bottom + a.bottom;
		glRecti( drawX, drawY, drawX + a.width, drawY + a.height );
	}
	
	void drawText(Font f, String text, int left, int bottom) {
		for (uint L = 0; L < text.length; L++) {
			text.select(L, 1);
			Image img = f.getChar(text.selection, 0);
			drawImage(img, left, bottom);
			left += img.width;
		}
	}
}
