//  Copyright (c) 2006 Craig Dooley <xlnxminusx@gmail.com>
//  Permission is hereby granted, free of charge, to any person obtaining a 
//  copy of this software and associated documentation files (the "Software"), 
//  to deal in the Software without restriction, including without limitation 
//  the rights to use, copy, modify, merge, publish, distribute, sublicense, 
//  and/or sell copies of the Software, and to permit persons to whom the 
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in 
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

/*	Notes: The ivar 'data' is used because NSBitmapImageRep does not copy the bitmap data.
*/

#import "RDCBitmap.h"

#import "RDCView.h"

@implementation RDCBitmap

- (id)initWithBitmapData:(const unsigned char *)d size:(NSSize)s view:(RDCView *)v
{
	if (![super init])
		return nil;

	int bitsPerPixel = [v bitsPerPixel];
	int bytesPerPixel = bitsPerPixel / 8;
	uint8 *np, *nc;
	const uint8 *p, *end;
	unsigned realLength, newLength;
	
	realLength = (int)s.width * (int)s.height * bytesPerPixel;
	newLength = (int)s.width * (int)s.height * 3;
	p = d;
	end = p + realLength;
	
	nc = np = malloc(newLength);
	while (p < end)
	{
		if (bitsPerPixel == 16)
		{
			[v rgbForRDCColor:*(uint16 *)p r:&nc[0] g:&nc[1] b:&nc[2]];
		}
		else if (bitsPerPixel == 8)
		{
			[v rgbForRDCColor:*p r:&nc[0] g:&nc[1] b:&nc[2]];
		}
		else // 24 and 32 bpp
		{
			// swap R and B
			nc[0] = p[2];
			nc[1] = p[1];
			nc[2] = p[0];
		}
		p += bytesPerPixel;
		nc += 3;
	}
	
	data = [[NSData alloc] initWithBytesNoCopy:(void *)np length:newLength];
	
	planes[0] = (unsigned char *)[data bytes];
	planes[1] = NULL;
	
	bitmap = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes
													 pixelsWide:(int)s.width 
													 pixelsHigh:(int)s.height
												  bitsPerSample:8
												samplesPerPixel:3
													   hasAlpha:NO
													   isPlanar:NO
												 colorSpaceName:NSDeviceRGBColorSpace
													bytesPerRow:s.width * 3
												   bitsPerPixel:0];

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
												   bitsPerPixel:0];	

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
