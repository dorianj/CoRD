//
//  RDCBitmap.m
//  Remote Desktop
//
//  Created by Craig Dooley on 8/28/06.

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

#import "RDCBitmap.h"


@implementation RDCBitmap
-(void)bitmapWithData:(const unsigned char *)d size:(NSSize)s view:(RDCView *)v {
	int bitsPerPixel = [v bitsPerPixel];
	int bytesPerPixel = bitsPerPixel / 8;
	float r, g, b, a;
	uint8 *np;
	const uint8 *p, *end;
	NSColor *c;
	
	if (bitsPerPixel == 24) {
		data = [[NSData alloc] initWithBytes:d length:s.width * s.height];
	} else {
		data = [[NSMutableData dataWithCapacity:s.width * s.height * 3] retain];
		p = d;
		end = p + ((int)s.width * (int)s.height * bytesPerPixel);
		np = (unsigned char *)[data bytes];
		
		while (p < end) {
			if (bitsPerPixel == 8) {
				c = [v nscolorForRDCColor:*p];
				[c getRed:&r green:&g blue:&b alpha:&a];
				np[0] = r*255.0;
				np[1] = g*255.0;
				np[2] = b*255.0;
				np += 3;
				p += bytesPerPixel;
			} else {
				c = [v rgbForRDCColor:*(uint16 *)p r:&np[0] g:&np[1] b:&np[2]];
				np += 3;
				p += bytesPerPixel;
			}
		}
	}
	
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
}

-(void)glyphWithData:(const unsigned char *)d size:(NSSize)s view:(RDCView *)v {
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
}

-(void)cursorWithData:(const unsigned char *)d alpha:(const unsigned char *)a size:(NSSize)s hotspot:(NSPoint)hotspot view:(RDCView *)v {
	int scanline = (int)s.width + 7 / 8;
	uint8 *np;
	const uint8 *p, *end;
	static int offset;
	
	data = [[NSMutableData alloc] initWithCapacity:(int)s.width * (int)s.height * 4];
	p = a;
	end = a + ((int)s.width * (int)s.height * 3);
	np = (uint8 *)[data bytes];
	int i = 0;
	while (p < end) {
		np[0] = p[0];
		np[1] = p[1];
		np[2] = p[2];
		if (d[i / 8] & (0x80 >> (i % 8))) {
			np[3] = 0x00;
		} else {
			np[3] = 0xff;
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
	offset += 32;
}

-(NSImage *)image {
	return image;
}

-(void)dealloc {
	[cursor release];
	[image release];
	[bitmap release];
	[data release];
	[color release];
	[super dealloc];
}

-(void)setColor:(NSColor *)c {
	[c retain];
	[color release];
	color = c;
}

-(NSColor *)color {
	return color;
}

-(NSCursor *)cursor {
	return cursor;
}

@end
