/*	Copyright (c) 2006 Craig Dooley <xlnxminusx@gmail.com>, 2007-2009 Dorian Johnson <2009@dorianj.net>
	
	This file is part of CoRD.
	CoRD is free software; you can redistribute it and/or modify it under the
	terms of the GNU General Public License as published by the Free Software
	Foundation; either version 2 of the License, or (at your option) any later
	version.

	CoRD is distributed in the hope that it will be useful, but WITHOUT ANY
	WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
	FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with
	CoRD; if not, write to the Free Software Foundation, Inc., 51 Franklin St,
	Fifth Floor, Boston, MA 02110-1301 USA
*/

/*	Notes:
		- The ivar 'data' is used because NSBitmapImageRep does not copy the bitmap data.
		- The stored bitmap (for non cursors/glyphs) is ARGB8888 regardless of source type for simplicity.
		- Using an accelerated buffer would speed up drawing. An option could be used for the situations where an NSImage is required. My tests on a machine with a capable graphics card show that CGImage would speed normal drawing up about 30-40%, and CGLayer would be 2-12 times quicker. The hassle is that some situations, a normal NSImage is needed (eg: when using the image as a pattern for NSColor and patblt), so it would either have to create both or have a switch for which to create, and neither CGImage nor CGLayer have a way to draw only a portion of itself, meaning the only way to do it is clip drawing to match the origin. I've written some basic code to use CFLayer, but it needs more work before I commit it.
*/

#import "CRDBitmap.h"
#import "AppController.h"
#import "CRDShared.h"
#import "CRDSessionView.h"

@implementation CRDBitmap

// Currently is adequately optimized: only somewhat critical
- (id)initWithBitmapData:(const unsigned char *)sourceBitmap size:(NSSize)s view:(CRDSessionView *)v
{
	if (![super init])
		return nil;

	int bitsPerPixel = [v bitsPerPixel],  bytesPerPixel = (bitsPerPixel + 7) / 8;
	
	uint8 *outputBitmap, *nc;
	const uint8 *p, *end;
	unsigned realLength, newLength;
	unsigned int *colorMap;
	int width = (int)s.width, height = (int)s.height;
	
	realLength = width * height * bytesPerPixel;
	newLength = width * height * 4;
	
	p = sourceBitmap;
	end = p + realLength;
	
	nc = outputBitmap = malloc(newLength);
	
	if (bitsPerPixel == 8)
	{
		colorMap = [v colorMap];
		while (p < end)
		{
			nc[0] = 255;
			nc[1] = colorMap[*p] & 0xff;
			nc[2] = (colorMap[*p] >> 8) & 0xff;
			nc[3] = (colorMap[*p] >> 16) & 0xff;
			
			p++;
			nc += 4;
		}
	}
	else if (bitsPerPixel == 16)
	{
		while (p < end)
		{
			unsigned short c = p[0] | (p[1] << 8);

			nc[0] = 255;
			nc[1] = (( (c >> 11) & 0x1f) * 255 + 15) / 31;
			nc[2] = (( (c >> 5) & 0x3f) * 255 + 31) / 63;
			nc[3] = ((c & 0x1f) * 255 + 15) / 31;
			
			p += bytesPerPixel;
			nc += 4;
		}
	}
	else if (bitsPerPixel == 15)
	{
		while (p < end)
		{
			unsigned short c = p[0] | (p[1] << 8);

			nc[0] = 255;
			nc[1] = (( (c >> 10) & 0x1f) * 255 + 15) / 31;
			nc[2] = (( (c >> 5) & 0x1f) * 255 + 15) / 31;
			nc[3] = ((c & 0x1f) * 255 + 15) / 31;
			
			p += bytesPerPixel;
			nc += 4;
		}
	}
	else if (bitsPerPixel == 24 || bitsPerPixel == 32)
	{
		while (p < end)
		{
			nc[0] = 255;
			nc[1] = p[2];
			nc[2] = p[1];
			nc[3] = p[0];
			
			p += bytesPerPixel;
			nc += 4;
		}
	}
	
	data = [[NSData alloc] initWithBytesNoCopy:(void *)outputBitmap length:newLength];
	
	unsigned char *planes[2] = {(unsigned char *)[data bytes], NULL};
	
	NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes
													 pixelsWide:width
													 pixelsHigh:height
												  bitsPerSample:8
												samplesPerPixel:4
													   hasAlpha:YES
													   isPlanar:NO
												 colorSpaceName:NSCalibratedRGBColorSpace
												   bitmapFormat:NSAlphaFirstBitmapFormat
													bytesPerRow:width * 4
												   bitsPerPixel:32] autorelease];
	
	image = [[NSImage alloc] init];
	[image addRepresentation:bitmap];
	[image setFlipped:YES];
	
	return self;
}

// Somewhat critical region: many glyph CRDBitmaps are created, one for each character drawn, as well as some when patterns are drawn. Currently efficient enough.
- (id)initWithGlyphData:(const unsigned char *)d size:(NSSize)s view:(CRDSessionView *)v
{	
	if (![super init])
		return nil;
	
	int width = s.width, height = s.height, scanline = ((int)width + 7) / 8;
	
	data = [[NSData alloc] initWithBytes:d length:scanline * height];

	unsigned char *planes[2] = {(unsigned char *)[data bytes], (unsigned char *)[data bytes]};
	
	NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes
													 pixelsWide:width
													 pixelsHigh:height
												  bitsPerSample:1
												samplesPerPixel:2
													   hasAlpha:YES
													   isPlanar:YES
												 colorSpaceName:NSDeviceBlackColorSpace
													bytesPerRow:scanline
												   bitsPerPixel:0] autorelease];	
	
	image = [[NSImage alloc] init];
	[image addRepresentation:bitmap];
	[image setFlipped:YES];
	[self setColor:[NSColor blackColor]];
	
	return self;
}

// Not a performance critical region at all
- (id)initWithCursorData:(const unsigned char *)xorMask alpha:(const unsigned char *)andMask size:(NSSize)s hotspot:(NSPoint)hotspot view:(CRDSessionView *)v bpp:(int)bpp
{	
	if (![super init])
		return nil;

	int w = roundf(s.width), h = roundf(s.height);
	
	if (!w || !h)
	{
		image = [[NSImage alloc] initWithSize:NSMakeSize(1,1)];		
		cursor = [[NSCursor alloc] initWithImage:image hotSpot:hotspot];
		return self;
	}

	int andScanlineLength = CRDRoundUpToEven(s.width/8.0f), xorScanlineLength = CRDRoundUpToEven(s.width * bpp / 8.0f);
	const uint8 *d = xorMask, *a = andMask;
		
	data = [[NSMutableData alloc] initWithCapacity:(int)s.width * (int)s.height * 4];
	uint8 *np = (uint8 *)[data bytes];
	
	int alphaBit, alphaIndex, x;
	
	for (int i = 0; i < h; i++)
	{
		a = andMask + andScanlineLength * i;
		d = xorMask + xorScanlineLength * i;
		
		for (int j = 0; j < w; j++)
		{
			alphaBit = a[j/8] & (0x80 >> (j % 8));
			
			switch (bpp)
			{
				case 1:
					x = (d[j/8] & (0x80 >> (j % 8))) ^ alphaBit;
					np[0] = np[1] = np[2] = x ? 0xff : 0;					
					np[3] = (alphaBit && x) ? 0 : 0xff;
					break;
	
				case 24:
					np[0] = d[2];
					np[1] = d[1];
					np[2] = d[0]; 
					np[3] = alphaBit ? 0 : 0xff; 
					d += 3;
					break;

				case 32:
					np[0] = d[2];
					np[1] = d[1];
					np[2] = d[0];
					np[3] = d[3];			
					d += 4;
					break;
				
				// Some potential cursor bpp's that we haven't implemented yet (but are evidently used by some servers in some circumstances)
				case 4:
				case 8:
				case 15:
				case 16:
				default:
					np[0] = np[1] = np[2] = 0;
					np[3] = 0xff;
					break;
			}

			np += 4;
		}
	}
	
	unsigned char *planes[2] = {(unsigned char *)[data bytes], NULL};
	NSBitmapImageRep *bitmap = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes
													 pixelsWide:s.width
													 pixelsHigh:s.height
												  bitsPerSample:8
												samplesPerPixel:4
													   hasAlpha:YES
													   isPlanar:NO
												 colorSpaceName:NSDeviceRGBColorSpace
													bytesPerRow:w * 4
												   bitsPerPixel:0] autorelease];	
	
	image = [[NSImage alloc] init];
	[image addRepresentation:bitmap];
	
	if (bpp == 4 || bpp == 8 || bpp == 15 || bpp == 16)
	{
		CRDLog(CRDLogLevelError, @"Cursor sent in unsupported bit-depth: %d bpp", bpp);
		cursor = [NSCursor arrowCursor];
		return self;
	}
	
	if (bpp == 32 || bpp == 24)
		[image setFlipped:YES];
		
	cursor = [[NSCursor alloc] initWithImage:image hotSpot:hotspot];
	return self;
}


#pragma mark -
#pragma mark Drawing the CRDBitmap

// The most critical region of this class and one of the most critical paths in the connection thread
- (void)drawInRect:(NSRect)dstRect fromRect:(NSRect)srcRect operation:(NSCompositingOperation)op
{
	[image drawInRect:dstRect fromRect:srcRect operation:op fraction:1.0];
}


#pragma mark -
#pragma mark Manipulating the bitmap

- (void)overlayColor:(NSColor *)c
{
	[image lockFocus]; {
		[c setFill];
		NSRectFillUsingOperation(CRDRectFromSize([image size]), NSCompositeSourceAtop);
	} [image unlockFocus];
}

#pragma mark -
#pragma mark Accessors
-(NSImage *)image
{
	return image;
}

-(void)dealloc
{
	[cursor release];
	[image release];
	[data release];
	[color release];
	[super dealloc];
}

-(void)setColor:(NSColor *)c
{
	if (c == color)
		return;

	[color release];
	color = [c retain];
}

-(NSColor *)color
{
	return color;
}

-(NSCursor *)cursor
{
	return cursor;
}

@end
