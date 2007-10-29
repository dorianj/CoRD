/*	Copyright (c) 2006 Craig Dooley <xlnxminusx@gmail.com>
	
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
		- The stored bitmap is ARGB8888 with alpha data regardless if source has
			alpha as a memory-speed tradeoff: vImage can convert RGB565 directly
			only to ARGB8888 (or planar, which would add complexity). Also, (to my
			knowledge from inspecting Shark dumps), Cocoa will translate whatever
			we paint into a 32 bitmap internally, so there's no disadvantage there.
		- Using an accelerated buffer would speed up drawing. An option could be used
			for the situations where an NSImage is required. My tests on a machine
			with a capable graphics card show that CGImage would speed
			normal drawing up about 30-40%, and CGLayer would be 2-12 times quicker.
			The hassle is that some situations, a normal NSImage is needed
			(eg: when using the image as a pattern for NSColor and patblt), so it would 
			either have to create both or have a switch for which to create, and 
			neither CGImage nor CGLayer have a way to draw only a portion of itself,
			meaning the only way to do it is clip drawing to match the origin.
			I've written some basic code to use CFLayer, but it needs more work
			before I commit it.
*/

#import "RDCBitmap.h"
#import <Accelerate/Accelerate.h>

#import "AppController.h"
#import "miscellany.h"
#import "RDCView.h"

@implementation RDCBitmap

- (id)initWithBitmapData:(const unsigned char *)sourceBitmap size:(NSSize)s view:(RDCView *)v
{
	if (![super init])
		return nil;

	int bytesPerPixel = [v bitsPerPixel] / 8;
	
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
	
	if (bytesPerPixel == 1)
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
	else if (bytesPerPixel == 2)
	{
		vImage_Buffer newBuffer, sourceBuffer;
		sourceBuffer.width = newBuffer.width = width;
		sourceBuffer.height = newBuffer.height = height;
		
		newBuffer.data = outputBitmap;
		newBuffer.rowBytes = width * 4;
		
		sourceBuffer.data = (void *)sourceBitmap;
		sourceBuffer.rowBytes = width * bytesPerPixel;
		
		vImageConvert_RGB565toARGB8888(255, &sourceBuffer, &newBuffer, 0);		
	}
	else if (bytesPerPixel == 3 || bytesPerPixel == 4)
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
	
	planes[0] = (unsigned char *)[data bytes];
	planes[1] = NULL;
	
	bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes
													 pixelsWide:width
													 pixelsHigh:height
												  bitsPerSample:8
												samplesPerPixel:4
													   hasAlpha:YES
													   isPlanar:NO
												 colorSpaceName:NSDeviceRGBColorSpace
												   bitmapFormat:NSAlphaFirstBitmapFormat
													bytesPerRow:width * 4
												   bitsPerPixel:32];

	image = [[NSImage alloc] init];
	[image addRepresentation:bitmap];
	[image setFlipped:YES];
	
	return self;
}

- (id)initWithGlyphData:(const unsigned char *)d size:(NSSize)s view:(RDCView *)v
{	
	if (![super init])
		return nil;
		
	int scanline = ((int)s.width + 7) / 8;
	
	data = [[NSData alloc] initWithBytes:d length:scanline * s.height];
	planes[0] = planes[1] = (unsigned char *)[data bytes];
	
	bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes
													 pixelsWide:s.width
													 pixelsHigh:s.height
												  bitsPerSample:1
												samplesPerPixel:2
													   hasAlpha:YES
													   isPlanar:YES
												 colorSpaceName:NSDeviceBlackColorSpace
													bytesPerRow:scanline
												   bitsPerPixel:1];	

	image = [[NSImage alloc] init];
	[image addRepresentation:bitmap];
	[image setFlipped:YES];
	[self setColor:[[NSColor blackColor] retain]];
	
	return self;
}

- (id)initWithCursorData:(const unsigned char *)d alpha:(const unsigned char *)a size:(NSSize)s
		hotspot:(NSPoint)hotspot view:(RDCView *)v
{	
	if (![super init])
		return nil;

	int scanline = (int)s.width + 7 / 8;
	uint8 *np;
	const uint8 *p, *end;
	
	data = [[NSMutableData alloc] initWithCapacity:(int)s.width * (int)s.height * 4];
	p = a;
	end = a + ((int)s.width * (int)s.height * 3);
	np = (uint8 *)[data bytes];
	int i = 0, alpha;
	while (p < end)
	{
		np[0] = p[0];
		np[1] = p[1];
		np[2] = p[2];
		
		alpha = d[i / 8] & (0x80 >> (i % 8));
		if (alpha && (np[0] || np[1] || np[2]))
		{
			np[0] = np[1] = np[2] = 0;
			np[3] = 0xff;
		}
		else
		{
			np[3] = alpha ? 0 : 0xff;
		}

		i++;
		p += 3;
		np += 4;
	}
		
	planes[0] = (unsigned char *)[data bytes];
	planes[1] = NULL;
	
	
	bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes
													 pixelsWide:s.width
													 pixelsHigh:s.height
												  bitsPerSample:8
												samplesPerPixel:4
													   hasAlpha:YES
													   isPlanar:NO
												 colorSpaceName:NSDeviceRGBColorSpace
													bytesPerRow:scanline * 4
												   bitsPerPixel:0];	
	
	image = [[NSImage alloc] init];
	[image addRepresentation:bitmap];
	[image setFlipped:YES];
	
	cursor = [[NSCursor alloc] initWithImage:image hotSpot:hotspot];
	
	return self;
}


#pragma mark -
#pragma mark Drawing the RDCBitmap

// Draws in the specified rect
- (void)drawInRect:(NSRect)dstRect fromRect:(NSRect)srcRect operation:(NSCompositingOperation)op
{
	[image drawInRect:dstRect fromRect:srcRect operation:op fraction:1.0];
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
	[bitmap release];
	[data release];
	[color release];
	[super dealloc];
}

-(void)setColor:(NSColor *)c
{
	[c retain];
	[color release];
	color = c;
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
