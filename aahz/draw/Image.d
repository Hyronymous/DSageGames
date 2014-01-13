module aahz.draw.Image;

import derelict.devil.il;
import derelict.devil.ilu;
import derelict.devil.ilut;

import tango.io.Stdout;
import tango.core.BitArray;

import aahz.draw.Color;
import aahz.shared.shared;

enum ImageType {
	RGB,
	RGBA,
	GREYSCALE,
	GREYSCALE_ALPHA,
	BITMAP
}

class Image {
package:
	ImageType m_type;
	int m_width;
	int m_height;
	ubyte[] m_data;
	uint m_bitWidth;
	
public:
	static void init() {
		AAHZ_loadIL();
		
		ilOriginFunc(IL_ORIGIN_LOWER_LEFT);
		ilEnable(IL_ORIGIN_SET);
	}
	
	static void cleanup() {
		AAHZ_unloadIL();
	}

	this(char[] path) {
		uint id;
		ILenum format, bytesPerPixel;
		ilGenImages(1, &id);
		ilBindImage(id);
		scope (exit) ilDeleteImages(1, &id);
		
		if (!ilLoadImage(path.ptr)) throw new Exception("Image could not be loaded");
		m_width = ilGetInteger(IL_IMAGE_WIDTH);
		m_height = ilGetInteger(IL_IMAGE_HEIGHT);
		format = ilGetInteger(IL_IMAGE_FORMAT);
		
		switch (format) {
		case IL_COLOR_INDEX:
			ILenum palType = ilGetInteger(IL_PALETTE_TYPE);
			switch (palType) {
			case IL_PAL_RGB24:
			case IL_PAL_RGB32:
			case IL_PAL_BGR24:
			case IL_PAL_BGR32:
				m_type = ImageType.RGB;
				bytesPerPixel = 3;
			break;
			case IL_PAL_RGBA32:
			case IL_PAL_BGRA32:
				m_type = ImageType.RGBA;
				bytesPerPixel = 4;
			break;
			case IL_PAL_NONE:
			default:
				throw new Exception("Unknown image format");
			break;
			}
		break;
		case IL_RGB:
		case IL_BGR:
			m_type = ImageType.RGB;
			bytesPerPixel = 3;
		break;
		case IL_RGBA:
		case IL_BGRA:
			m_type = ImageType.RGBA;
			bytesPerPixel = 4;
		break;
		case IL_LUMINANCE:
			m_type = ImageType.GREYSCALE;
			bytesPerPixel = 1;
		break;
		case IL_LUMINANCE_ALPHA:
			m_type = ImageType.GREYSCALE_ALPHA;
			bytesPerPixel = 2;
		break;
		default:
			throw new Exception("Unknown image format");
		break;
		}
		
		m_data.length =
			m_width * bytesPerPixel
			* m_height
		;
		ilCopyPixels(
			0,	// xOff
			0,	// yOff
			0,	// zOff
			m_width,	// width
			m_height,	// height
			1,	// depth
			(m_type == ImageType.RGB) ? IL_RGB : IL_RGBA,	// format
			IL_UNSIGNED_BYTE,	// type
			m_data.ptr	// out -> data
		);
	}
	
	this(ImageType type, uint width, uint height) {
		m_type = type;
		m_width = width;
		m_height = height;
		
		switch (type) {
		case ImageType.RGB:
			m_data.length = width * 3 * height;
		break;
		case ImageType.RGBA:
			m_data.length = width * 4 * height;
		break;
		case ImageType.GREYSCALE:
			m_data.length = width * height;
		break;
		case ImageType.GREYSCALE_ALPHA:
			m_data.length = width * 2 * height;
		break;
		case ImageType.BITMAP:
			m_bitWidth = width / 8;	// one byte handles 8 horizontal spaces
			if ((width % 8) != 0) m_bitWidth += 1;	// pad to byte width horizontally
			m_data.length = m_bitWidth * height;
		break;
		}
		m_data[] = 0x00;
	}
	
	void draw(Image img, int x, int y, bool blend = true) {
		uint copyWidth, copyHeight;
		uint sourceX, sourceY;
		uint destX, destY;
		
		if (x < 0) {
			sourceX = -x;
			destX = 0;
			if (img.m_width + x > m_width) {	// -|---|-
				copyWidth = m_width;
			}
			else {	// --|-- |
				copyWidth = img.m_width + x;
			}
		}
		else {
			sourceX = 0;
			destX = x;
			if (x + img.m_width <= m_width) {	// | --- |
				copyWidth = img.m_width;
			}
			else {	// | --|--
				copyWidth = m_width - x;
			}
		}
		
		if (y < 0) {
			sourceY = -y;
			destY = 0;
			if (img.m_height + y > m_height) {	// -|---|-
				copyHeight = m_height;
			}
			else {	// --|-- |
				copyHeight = img.m_height + y;
			}
		}
		else {
			sourceY = 0;
			destY = y;
			if (y + img.m_height <= m_height) {	// | --- |
				copyHeight = img.m_height;
			}
			else {	// | --|--
				copyHeight = m_height - y;
			}
		}
		
		if (m_type == img.m_type) switch (m_type) {	// If types match, copying over is much easier. Separating out for clarity of code
		case ImageType.RGB:
			uint destStart = destY * (m_width * 3);
			uint sourceStart = sourceY * (img.m_width * 3);
			
			for (uint L = 0; L < copyHeight; L++) {
				uint byteWidth = copyWidth * 3;
				m_data[
					(destStart + destX * 3)..(destStart + destX * 3 + byteWidth)
				] = img.m_data[
					(sourceStart + sourceX * 3)..(sourceStart + sourceX * 3 + byteWidth)
				];
				destStart += (m_width * 3);
				sourceStart += (img.m_width * 3);
			}
		break;
		case ImageType.RGBA:
			uint destStart = destY * (m_width * 4);
			uint sourceStart = sourceY * (img.m_width * 4);
			
			if (blend) {
				for (uint L = 0; L < copyHeight; L++) {
					for (uint L2 = 0; L2 < copyWidth; L2++) {	// See http://en.wikipedia.org/wiki/Alpha_compositing for formula for blending two transparent surfaces
						uint dI = destStart + 4 * (destX + L2);	// destination index for pixel's first byte
						uint sI = sourceStart + 4 * (sourceX + L2);	// source
						float sAlpha = cast(float)img.m_data[sI + 3] / cast(float)0xff;
						float dAlpha = cast(float)m_data[dI + 3] / cast(float)0xff;
						
						uint sR = cast(uint)(img.m_data[sI] * sAlpha);
						uint sG = cast(uint)(img.m_data[sI + 1] * sAlpha);
						uint sB = cast(uint)(img.m_data[sI + 2] * sAlpha);

						uint dR = cast(uint)(m_data[dI] * dAlpha);
						uint dG = cast(uint)(m_data[dI + 1] * dAlpha);
						uint dB = cast(uint)(m_data[dI + 2] * dAlpha);
						
						dR = sR + cast(uint)((1.0f - sAlpha) * dR);
						dG = sG + cast(uint)((1.0f - sAlpha) * dG);
						dB = sB + cast(uint)((1.0f - sAlpha) * dB);

						uint dA = cast(uint)((sAlpha + dAlpha * (1.0f - sAlpha)) * 0xff);
						
						if (dR > 0xff) dR = 0xff;
						if (dG > 0xff) dG = 0xff;
						if (dB > 0xff) dB = 0xff;
						if (dA > 0xff) dA = 0xff;
						
						m_data[dI] = cast(ubyte)dR;
						m_data[dI + 1] = cast(ubyte)dG;
						m_data[dI + 2] = cast(ubyte)dB;
						m_data[dI + 3] = cast(ubyte)dA;
					}
					
					destStart += (m_width * 4);
					sourceStart += (img.m_width * 4);
				}
			}
			else { // no blending. Just overwrite
				for (uint L = 0; L < copyHeight; L++) {
					uint byteWidth = copyWidth * 4;
					m_data[
						(destStart + destX * 4)..(destStart + destX * 4 + byteWidth)
					] = img.m_data[
						(sourceStart + sourceX * 4)..(sourceStart + sourceX * 4 + byteWidth)
					];
					destStart += (m_width * 4);
					sourceStart += (img.m_width * 4);
				}
			}
		break;
		case ImageType.GREYSCALE:
			uint destStart = destY * (m_width);
			uint sourceStart = sourceY * (img.m_width);
			
			for (uint L = 0; L < copyHeight; L++) {
				uint byteWidth = copyWidth;
				m_data[
					(destStart + destX)..(destStart + destX + byteWidth)
				] = img.m_data[
					(sourceStart + sourceX)..(sourceStart + sourceX + byteWidth)
				];
				destStart += (m_width);
				sourceStart += (img.m_width);
			}
		break;
		case ImageType.GREYSCALE_ALPHA:
			uint destStart = destY * (m_width * 2);
			uint sourceStart = sourceY * (img.m_width * 2);
			
			if (blend) {
				for (uint L = 0; L < copyHeight; L++) {
					for (uint L2 = 0; L2 < copyWidth; L2++) {	// See http://en.wikipedia.org/wiki/Alpha_compositing for formula for blending two transparent surfaces
						uint dI = destStart + 2 * (destX + L2);	// destination index for pixel's first byte
						uint sI = sourceStart + 2 * (sourceX + L2);	// source
						float sAlpha = cast(float)img.m_data[sI + 1] / cast(float)0xff;
						float dAlpha = cast(float)m_data[dI + 1] / cast(float)0xff;
						
						uint sR = cast(uint)(img.m_data[sI] * sAlpha);
						uint dR = cast(uint)(m_data[dI] * dAlpha);
						dR = sR + cast(uint)((1.0f - sAlpha) * dR);

						uint dA = cast(uint)((sAlpha + dAlpha * (1.0f - sAlpha)) * 0xff);
						
						if (dR > 0xff) dR = 0xff;
						if (dA > 0xff) dA = 0xff;
						
						m_data[dI] = cast(ubyte)dR;
						m_data[dI + 1] = cast(ubyte)dA;
					}
					
					destStart += (m_width * 2);
					sourceStart += (img.m_width * 2);
				}
			}
			else { // no blending. Just overwrite
				for (uint L = 0; L < copyHeight; L++) {
					uint byteWidth = copyWidth * 2;
					m_data[
						(destStart + destX * 2)..(destStart + destX * 2 + byteWidth)
					] = img.m_data[
						(sourceStart + sourceX * 2)..(sourceStart + sourceX * 2 + byteWidth)
					];
					destStart += (m_width * 2);
					sourceStart += (img.m_width * 2);
				}
			}
		break;
		case ImageType.BITMAP:
			throw new Exception("Image conversion type not currently supported");
		break;
		}
		else switch (m_type) {	// Have to convert between types
		case ImageType.RGB:	// dest
			switch (img.m_type) {
			case ImageType.RGBA:	// source
				throw new Exception("Image conversion type not currently supported");
			break;
			case ImageType.GREYSCALE:
				throw new Exception("Image conversion type not currently supported");
			break;
			case ImageType.GREYSCALE_ALPHA:
				throw new Exception("Image conversion type not currently supported");
			break;
			case ImageType.BITMAP:
				throw new Exception("Image conversion type not currently supported");
			break;
			}
		break;
		case ImageType.RGBA:
			switch (img.m_type) {
			case ImageType.RGB:
				uint destStart = destY * (m_width * 4);
				uint sourceStart = sourceY * (img.m_width * 3);
				
				for (uint L = 0; L < copyHeight; L++) {
					for (uint L2 = 0; L2 < copyWidth; L2++) {
						uint dI = destStart + destX * 4 + (L2 * 4);	// destination index for pixel's first byte
						uint sI = sourceStart + sourceX * 3 + (L2 * 3);	// source
						
						m_data[dI] = img.m_data[sI];
						m_data[dI + 1] = img.m_data[sI + 1];
						m_data[dI + 2] = img.m_data[sI + 2];
						m_data[dI + 3] = 0xff;
					}
					
					destStart += (m_width * 4);
					sourceStart += (img.m_width * 3);
				}
			break;
			case ImageType.GREYSCALE:
				throw new Exception("Image conversion type not currently supported");
			break;
			case ImageType.GREYSCALE_ALPHA:
				throw new Exception("Image conversion type not currently supported");
			break;
			case ImageType.BITMAP:
				throw new Exception("Image conversion type not currently supported");
			break;
			}
			
		break;
		case ImageType.GREYSCALE:
			switch (img.m_type) {
			case ImageType.RGB:
				throw new Exception("Image conversion type not currently supported");
			break;
			case ImageType.RGBA:
				throw new Exception("Image conversion type not currently supported");
			break;
			case ImageType.GREYSCALE_ALPHA:
				throw new Exception("Image conversion type not currently supported");
			break;
			case ImageType.BITMAP:
				throw new Exception("Image conversion type not currently supported");
			break;
			}
			
		break;
		case ImageType.GREYSCALE_ALPHA:
			switch (img.m_type) {
			case ImageType.RGB:
				throw new Exception("Image conversion type not currently supported");
			break;
			case ImageType.RGBA:
				throw new Exception("Image conversion type not currently supported");
			break;
			case ImageType.GREYSCALE:
				throw new Exception("Image conversion type not currently supported");
			break;
			case ImageType.BITMAP:
				throw new Exception("Image conversion type not currently supported");
			break;
			}
			
		break;
		case ImageType.BITMAP:
			switch (img.m_type) {
			case ImageType.RGB:
				throw new Exception("Image conversion type not currently supported");
			break;
			case ImageType.RGBA:
				throw new Exception("Image conversion type not currently supported");
			break;
			case ImageType.GREYSCALE:
				throw new Exception("Image conversion type not currently supported");
			break;
			case ImageType.GREYSCALE_ALPHA:
				throw new Exception("Image conversion type not currently supported");
			break;
			}
		break;
		}
	}
	
	ImageType type() {
		return m_type;
	}
	
	int width() {
		return m_width;
	}
	
	int height() {
		return m_height;
	}
	
	ubyte* data() {
		return m_data.ptr;
	}
}
