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

#import <Cocoa/Cocoa.h>

#import "rdesktop.h" // POINT


@class RDInstance;
@class RDCBitmap;
@class RDCKeyboard;

@interface RDCView : NSView
{
	RDInstance *controller;
	NSImage *back;
	NSPoint mouseLoc;
	NSRect clipRect;
	NSColor *foregroundColor, *backgroundColor;
	NSCursor *cursor;
	int bitdepth;
	RDCKeyboard *keyTranslator;
	unsigned int *colorMap;	// size of 0xff always
}

- (void)startUpdate;
- (void)stopUpdate;
- (void)fillRect:(NSRect)r;
- (void)fillRect:(NSRect)rect withColor:(NSColor *) color;
- (void)fillRect:(NSRect)rect withColor:(NSColor *) color patternOrigin:(NSPoint)origin;
- (void)polyline:(POINT *)points npoints:(int)nPoints color:(NSColor *)c width:(int)w;
- (void)polygon:(POINT *)points npoints:(int)nPoints color:(NSColor *)c  winding:(NSWindingRule)winding;
- (void)setColorMap:(unsigned int *)map;
- (unsigned int *)colorMap;
- (void)memblt:(NSRect)r from:(NSImage *)src withOrigin:(NSPoint)origin;
- (void)screenBlit:(NSRect)from to:(NSPoint)to;
- (void)drawLineFrom:(NSPoint)start to:(NSPoint)end color:(NSColor *)color width:(int)w;
- (int)width;
- (int)height;
- (void)drawGlyph:(RDCBitmap *)glyph at:(NSRect)r fg:(int)fgcolor bg:(int)bgcolor;
- (void)setClip:(NSRect)r;
- (void)resetClip;
- (int)bitsPerPixel;
- (NSColor *)nscolorForRDCColor:(int)col;
- (void)rgbForRDCColor:(int)col r:(unsigned char *)r g:(unsigned char *)g b:(unsigned char *)b;
- (void)setForeground:(NSColor *)color;
- (void)setBackground:(NSColor *)color;
- (void)swapRect:(NSRect)r;
- (void)ellipse:(NSRect)r color:(NSColor *)c;
- (void)setController:(RDInstance *)instance;
- (void)setBitdepth:(int)depth;
- (void)setCursor:(NSCursor *)cursor;
- (void)setNeedsDisplayInRectAsValue:(NSValue *)rectValue;
@end
