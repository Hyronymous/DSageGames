module aahz.draw.Font;

import derelict.freetype.ft;
import tango.text.convert.Utf;
import tango.io.Stdout;

import aahz.draw.Image;
import aahz.draw.Color;
import aahz.shared.shared;
import aahz.util.String;

enum FontStyle {
	NORMAL = 0x0,
	LIGHT = 0x1,
	BOLD = 0x2,
	
	ITALIC = 0x4,
	UNDERLINE = 0x8,
	STRIKETHROUGH = 0x10
}

class Font {
private:
	static char[] path;
	static char[][ FontStyle ][ char[] ] fileName;
	
	FT_Face face;
	uint m_height;
	uint m_baseline;
	float m_angle;
	float m_kerning;
	
	uint imageCount = 0;
	Image[] images;
	uint[ dchar[] ] imageIndexes;
	Color3ub color;

public:
	static void init(char[] path) {
		this.path = path.dup;
		AAHZ_loadFT();
	}
	
	static void cleanup() {
		AAHZ_unloadFT();
	}
	
	static void registerFont(char[] file, char[] name, FontStyle style) {
		char[] nameAccess = name.dup;
		fileName[ nameAccess ][ style ] = file.dup;
	}
	
	static char[][] getFonts() {
		return fileName.keys;
	}
	
	this(char[] name, uint size, FontStyle style) {
		char[] loadPath = path ~ fileName[ name ][ style ] ~ "\0";
		m_height = size;
		
		FT_Error res = FT_New_Face(
			ft_library,
			loadPath.ptr,
			0,
			&face
		);
		if (0 != res) throw new Exception("Font could not be loaded");
		
		res = FT_Set_Pixel_Sizes(
			face,	/* handle to face object */
			0,		/* pixel_width */
			size	/* pixel_height */
		);
		if (0 != res) throw new Exception("Unable to match requested font size");
		
		m_baseline = cast(uint)(cast(float)(face.height - face.ascender) / cast(float)face.height * cast(float)size);
	}
	
	~this() {
		FT_Done_Face(face);
	}
	
	void setColor(ubyte r, ubyte g, ubyte b) {
		color.set(r, g, b);
	}
	
	Image getChar(char[] text, int offset = 0) {
		Image ret;
		FT_Error res;

		int offsetMax = offset + 4;
		if (offsetMax >= text.length) offsetMax = text.length;
		dchar[] utf32 = toString32( text[offset..offsetMax] );	// At maximum, we need to convert 4 bytes. Slice for speed
		utf32.length = 1;
		
		uint* p = (utf32 in imageIndexes);
		if (p != null) {
			return images[ *p ];
		}

		uint id = FT_Get_Char_Index( face, utf32[0] );	// Grab the index

		res = FT_Load_Glyph(
			face,		/* handle to face object */
			id,			/* glyph index */
			FT_LOAD_DEFAULT	/* load flags, see below */ 
		);
		if (res != 0) throw new Exception("Error in font system");
		
		FT_Glyph glyph;
		FT_BitmapGlyph bitmap_glyph;
		FT_Bitmap* bitmap;
		
		res = FT_Get_Glyph(face.glyph, &glyph);
		if (res != 0) throw new Exception("Error in font system");
		scope (exit) FT_Done_Glyph(glyph);
		
		res = FT_Glyph_To_Bitmap( &glyph, FT_Render_Mode.FT_RENDER_MODE_NORMAL, null, 1 );
		if (res != 0) throw new Exception("Error in font system");
		bitmap_glyph = cast(FT_BitmapGlyph)glyph;
		bitmap = &bitmap_glyph.bitmap;
		
		int imgWidth = face.glyph.metrics.width >> 6;
		int imgHeight = face.glyph.metrics.height >> 6;
		int imgAdvance = face.glyph.metrics.horiAdvance >> 6;
		int imgHDiff = face.glyph.metrics.horiBearingX >> 6;
		int imgVDiff = face.glyph.metrics.horiBearingY >> 6;
		ret = new Image(ImageType.RGBA, imgAdvance, m_height);
		
		Image temp = new Image(ImageType.RGBA, bitmap.width, bitmap.rows);
		if (bitmap.pitch > 0) {	// Need to flip image
			uint source = bitmap.pitch * bitmap.rows - bitmap.pitch;
			uint dest = 0;
			
			for (uint L = 0; L < bitmap.rows; L++) {
				for (uint L2 = 0; L2 < bitmap.width; L2++) {
					uint dest4 = dest + L2 * 4;
					temp.m_data[dest4] = color.r;
					temp.m_data[dest4 + 1] = color.g;
					temp.m_data[dest4 + 2] = color.b;
					temp.m_data[dest4 + 3] = bitmap.buffer[source + L2];
				}
				dest += bitmap.width * 4;
				source -= bitmap.pitch;
			}
		}
		else {	// copy over straight
			uint source = 0;
			uint dest = 0;
			
			for (uint L = 0; L < bitmap.rows; L++) {
				for (uint L2 = 0; L2 < bitmap.width; L2++) {
					uint dest4 = dest + L2 * 4;
					temp.m_data[dest4] = color.r;
					temp.m_data[dest4 + 1] = color.g;
					temp.m_data[dest4 + 2] = color.b;
					temp.m_data[dest4 + 3] = bitmap.buffer[source + L2];
				}
				dest -= bitmap.width * 4;	// pitch is a negative value
				source -= bitmap.pitch;
			}
		}
		ret.draw(temp, imgHDiff, m_baseline - (imgHeight - imgVDiff), false);
		
		images.length = imageCount + 1;
		images[ imageCount ] = ret;
		imageIndexes[ utf32 ] = imageCount;
		++imageCount;
		
		return ret;
	}
	
	Image getText(String text) {
		Image ret;
		Image[] images;
		uint iWidth, iHeight;
		iHeight = m_height;
		
		images.length = text.length;
		for (uint L = 0; L < text.length; L++) {
			text.select(L, 1);
			images[L] = getChar(text.selection, 0);

			iWidth += images[L].width;
		}
		
		int left = 0;
		ret = new Image(ImageType.RGBA, iWidth, iHeight);
		for (uint L = 0; L < images.length; L++) {
			ret.draw(images[L], left, 0);
			left += images[L].width;
		}
		return ret;
	}
	
	uint height() {
		return m_height;
	}
}
