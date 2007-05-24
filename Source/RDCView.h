/*  Copyright (c) 2006 Craig Dooley <xlnxminusx@gmail.com>
	
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

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <OpenGL/gl.h>

#import "rdesktop.h"

@class RDInstance;
@class RDCBitmap;
@class RDCKeyboard;

@interface RDCView : NSOpenGLView
{
	RDInstance *controller;
	
	// OpenGL back buffer
	CGContextRef rdBufferContext;
	unsigned char *rdBufferBitmapData;
	int rdBufferBitmapLength;
	GLuint rdBufferTexture;
	int rdBufferWidth, rdBufferHeight;
	
	NSPoint mouseLoc;
	NSRect clipRect;
	NSCursor *cursor;
	int bitdepth;
	RDCKeyboard *keyTranslator;
	unsigned int *colorMap;	// always a size of 256
	NSSize screenSize;
	
	// For mouse event throttling
	NSDate *lastMouseEventSentAt;
	NSEvent *deferredMouseEvent;
	NSTimer *mouseInputScheduler;
}

// Drawing
- (void)ellipse:(NSRect)r color:(NSColor *)c;
- (void)polygon:(POINT *)points npoints:(int)nPoints color:(NSColor *)c winding:(NSWindingRule)winding;
- (void)polyline:(POINT *)points npoints:(int)nPoints color:(NSColor *)c width:(int)w;
- (void)fillRect:(NSRect)rect withColor:(NSColor *)color;
- (void)fillRect:(NSRect)rect withColor:(NSColor *)color patternOrigin:(NSPoint)origin;
- (void)fillRect:(NSRect)rect withRDColor:(int)color;
- (void)drawBitmap:(RDCBitmap *)image inRect:(NSRect)r from:(NSPoint)origin operation:(NSCompositingOperation)op;
- (void)screenBlit:(NSRect)from to:(NSPoint)to;
- (void)drawLineFrom:(NSPoint)start to:(NSPoint)end color:(NSColor *)color width:(int)width;
- (void)drawGlyph:(RDCBitmap *)glyph at:(NSRect)r fg:(NSColor *)fgcolor bg:(NSColor *)bgcolor;
- (void)swapRect:(NSRect)r;

// Other rdesktop handlers
- (void)setClip:(NSRect)r;
- (void)resetClip;

// Backing store
- (void)startUpdate;
- (void)stopUpdate;
- (void)focusBackingStore;
- (void)releaseBackingStore;

- (BOOL)checkMouseInBounds:(NSEvent *)ev;
- (void)sendMouseInput:(unsigned short)flags;

// Converting colors
- (void)rgbForRDCColor:(int)col r:(unsigned char *)r g:(unsigned char *)g b:(unsigned char *)b;
- (NSColor *)nscolorForRDCColor:(int)col;

// Other
- (void)setNeedsDisplayInRects:(NSArray *)rects;
- (void)setNeedsDisplayInRectAsValue:(NSValue *)rectValue;
- (void)writeScreenCaptureToFile:(NSString *)path;
- (void)setScreenSize:(NSSize)newSize;

// Accessors
- (void)setController:(RDInstance *)instance;
- (int)bitsPerPixel;
- (void)setBitdepth:(int)depth;
- (int)width;
- (int)height;
- (unsigned int *)colorMap;
- (void)setColorMap:(unsigned int *)map;
- (void)setCursor:(NSCursor *)cur;

@end
