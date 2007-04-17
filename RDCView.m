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

#import "RDCView.h"
#import "RDCKeyboard.h"
#import "RDCBitmap.h"
#import "RDInstance.h"

#import <sys/types.h>
#import "scancodes.h"

@interface RDCView (Private)
	- (void)send_modifiers:(NSEvent *)ev enable:(BOOL)en;
@end

#pragma mark -

@implementation RDCView

#pragma mark NSView functions
- (id)initWithFrame:(NSRect)frame
{
	if (![super initWithFrame:frame])
		return nil;
		
	back = [[NSImage alloc] initWithSize:frame.size];
		
	// Other initializations
	cursor = [[NSCursor arrowCursor] retain];
	[self addCursorRect:[self visibleRect] cursor:cursor];
	colorMap = malloc(0xff * sizeof(unsigned int));
	memset(colorMap, 0, 0xff * sizeof(unsigned int));
	keyTranslator = [[RDCKeyboard alloc] init];
	
	// Fill background with default
	[self resetClip];
	[back lockFocus];
	[[NSColor blackColor] set];
	[NSBezierPath fillRect:frame];
	[back unlockFocus];
    
	[self setBounds:NSMakeRect(0.0, 0.0, frame.size.width, frame.size.height)];
	screenSize = frame.size;
	
    return self;
}

- (void)setController:(RDInstance *)instance
{
	controller = instance;
	[keyTranslator setController:instance];
	bitdepth = [instance conn]->serverBpp;
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)wantsDefaultClipping
{
	return NO;
}

- (void)drawRect:(NSRect)rect
{
	// xxx: performance heavy, looks nice though
	if (fabs(screenSize.width - rect.size.width) > .001)
	{
		[[NSGraphicsContext currentContext] setShouldAntialias:YES];
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];		
	}
	
	int nRects, i;
	const NSRect* rects;
	[self getRectsBeingDrawn:&rects count:&nRects];
	for (i = 0; i < nRects; i++)
	{
		[back drawInRect:rects[i] fromRect:rects[i]  operation:NSCompositeCopy fraction:1.0f];
	}
}

- (BOOL)isFlipped
{
	return YES;
}

- (BOOL)isOpaque
{
	return YES;
}

- (void)resetCursorRects
{
    [self discardCursorRects];
    [self addCursorRect:[self visibleRect] cursor:cursor]; 
}

- (void)setFrame:(NSRect)frame
{	
	[super setFrame:frame];
	
	NSRect bounds = NSMakeRect(0.0, 0.0, screenSize.width, screenSize.height);

	if (frame.size.width > bounds.size.width)
		bounds.origin.x = (frame.size.width - bounds.size.width)/2.0;
		
	if (frame.size.height > bounds.size.height)
		bounds.origin.y = (frame.size.height - bounds.size.height)/2.0;
		
	[self setBounds:bounds];
}



#pragma mark -
#pragma mark NSObject functions

- (void)dealloc
{
	[keyTranslator release];
	[cursor release];
	[back release];

	free(colorMap);
	[super dealloc];
}


#pragma mark -
#pragma mark Remote Desktop handlers 
- (void)startUpdate
{
	[back lockFocus];
}

- (void)stopUpdate
{
	[back unlockFocus];
}

- (void)ellipse:(NSRect)r color:(NSColor *)c
{
	[back lockFocus];
	NSRectClip(clipRect);
	[c set];
	[[NSBezierPath bezierPathWithOvalInRect:r] fill];
	[back unlockFocus];
}

- (void)polygon:(POINT *)points npoints:(int)nPoints color:(NSColor *)c
		winding:(NSWindingRule)winding
{
	NSBezierPath *bp = [NSBezierPath bezierPath];
	int i;
	
	[bp moveToPoint:NSMakePoint(points[0].x + 0.5, points[0].y + 0.5)];
	for (i = 1; i < nPoints; i++)
		[bp relativeLineToPoint:NSMakePoint(points[i].x, points[i].y)];

	[bp closePath];
	
	[back lockFocus];
	NSRectClip(clipRect);
	[c set];
	[bp fill];
	[back unlockFocus];
}

- (void)polyline:(POINT *)points npoints:(int)nPoints color:(NSColor *)c width:(int)w
{
	NSBezierPath *bp = [NSBezierPath bezierPath];
	int i;
	
	[bp moveToPoint:NSMakePoint(points[0].x + 0.5, points[0].y + 0.5)];
	for (i = 1; i < nPoints; i++)
		[bp relativeLineToPoint:NSMakePoint(points[i].x, points[i].y)];

	[bp setLineWidth:w];

	[back lockFocus];
	NSRectClip(clipRect);
	[c set];
	[bp closePath];
	[bp stroke];
	[back unlockFocus];
}

- (void)fillRect:(NSRect)rect withColor:(NSColor *) color
{	
	[self fillRect:rect withColor:color patternOrigin:NSZeroPoint];
}

- (void)fillRect:(NSRect)rect withColor:(NSColor *) color patternOrigin:(NSPoint)origin
{
	[back lockFocus];
	NSRectClip(clipRect);
	[color set];
	[[NSGraphicsContext currentContext] setPatternPhase:origin];
	[NSBezierPath fillRect:rect];
	[back unlockFocus];
}

- (void)memblt:(NSRect)to from:(NSImage *)image withOrigin:(NSPoint)origin
{
	[back lockFocus];
	NSRectClip(clipRect);
	[image drawInRect:to
			 fromRect:NSMakeRect(origin.x, origin.y, to.size.width, to.size.height)
			operation:NSCompositeCopy
			 fraction:1.0];
	[back unlockFocus];
}

- (void)screenBlit:(NSRect)from to:(NSPoint)to
{
	[back lockFocus];
	NSRectClip(clipRect);
	NSCopyBits(nil, from, to);
	[back unlockFocus];
}

- (void)drawLineFrom:(NSPoint)start to:(NSPoint)end color:(NSColor *)color width:(int)width
{
	NSBezierPath *bp = [NSBezierPath bezierPath];
	[back lockFocus];
	NSRectClip(clipRect);
	[color set];
	[bp moveToPoint:start];
	[bp lineToPoint:end];
	[bp setLineWidth:width];
	[bp closePath];
	[bp stroke];
	[back unlockFocus];
}

- (void)drawGlyph:(RDCBitmap *)glyph at:(NSRect)r fg:(NSColor *)fgcolor bg:(NSColor *)bgcolor
{
	NSImage *image = [glyph image];
	
	if (![[glyph color] isEqual:fgcolor])
	{
		[image lockFocus];
		[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeSourceAtop];
		[fgcolor setFill];
		[NSBezierPath fillRect:NSMakeRect(0, 0, [image size].width, [image size].height)];
		[image unlockFocus];
		[glyph setColor:fgcolor];
	}
	
	NSRectClip(clipRect);
	[image drawInRect:r
			 fromRect:NSMakeRect(0, 0, r.size.width, r.size.height)
			operation:NSCompositeSourceOver
		     fraction:1.0];
}

- (void)swapRect:(NSRect)r
{
	[back lockFocus];
	NSRectClip(clipRect);
	CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	CGContextSaveGState(context);
	CGContextSetBlendMode(context, kCGBlendModeDifference);
	CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
	CGContextFillRect(context, CGRectMake(r.origin.x, r.origin.y, r.size.width, r.size.height));
	CGContextFlush(context);
	CGContextRestoreGState(context);
	[back unlockFocus];
}

- (void)setClip:(NSRect)r
{
	clipRect = r;
}

- (void)resetClip
{
	NSRect r = NSZeroRect;
	r.size = [back size];
	clipRect = r;
}


#pragma mark -
#pragma mark NSResponder Event Handlers

- (void)keyDown:(NSEvent *)ev
{
	[keyTranslator handleKeyEvent:ev keyDown:YES];
}

- (void)keyUp:(NSEvent *)ev
{
	[keyTranslator handleKeyEvent:ev keyDown:NO];
}


- (void)flagsChanged:(NSEvent *)ev
{ 		
	[keyTranslator handleFlagsChanged:ev];
}

- (void)mouseDown:(NSEvent *)ev
{
	int flags = [ev modifierFlags];
	if ((flags & NSShiftKeyMask) && (flags & NSControlKeyMask))
	{
		[keyTranslator sendScancode:SCANCODE_CHAR_LSHIFT flags:RDP_KEYRELEASE];
		[keyTranslator sendScancode:SCANCODE_CHAR_LCTRL flags:RDP_KEYRELEASE];
		[self rightMouseDown:ev];
		[keyTranslator sendScancode:SCANCODE_CHAR_LSHIFT flags:RDP_KEYPRESS];
		[keyTranslator sendScancode:SCANCODE_CHAR_LCTRL flags:RDP_KEYPRESS];
		return;
	}
	
	mouseLoc = [self convertPoint:[ev locationInWindow] fromView:nil];
	[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_DOWN | MOUSE_FLAG_BUTTON1 param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
}

- (void)mouseUp:(NSEvent *)ev
{
	int flags = [ev modifierFlags];
	if ((flags & NSShiftKeyMask) && (flags & NSControlKeyMask))
	{
		[keyTranslator sendScancode:SCANCODE_CHAR_LSHIFT flags:RDP_KEYRELEASE];
		[keyTranslator sendScancode:SCANCODE_CHAR_LCTRL flags:RDP_KEYRELEASE];
		[self rightMouseUp:ev];
		[keyTranslator sendScancode:SCANCODE_CHAR_LSHIFT flags:RDP_KEYPRESS];
		[keyTranslator sendScancode:SCANCODE_CHAR_LCTRL flags:RDP_KEYPRESS];
		return;
	}
	
	mouseLoc = [self convertPoint:[ev locationInWindow] fromView:nil];
	[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_BUTTON1 param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
}

- (void)rightMouseDown:(NSEvent *)ev
{
	mouseLoc = [self convertPoint:[ev locationInWindow] fromView:nil];
	[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_DOWN | MOUSE_FLAG_BUTTON2 param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
}

- (void)rightMouseUp:(NSEvent *)ev
{
	mouseLoc = [self convertPoint:[ev locationInWindow] fromView:nil];
	[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_BUTTON2 param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
}

- (void)otherMouseDown:(NSEvent *)ev
{
	mouseLoc = [self convertPoint:[ev locationInWindow] fromView:nil];
	[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_DOWN | MOUSE_FLAG_BUTTON3 param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
}

- (void)otherMouseUp:(NSEvent *)ev
{
	mouseLoc = [self convertPoint:[ev locationInWindow] fromView:nil];
	[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_BUTTON3 param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
}

- (void)scrollWheel:(NSEvent *)ev
{
	if ([ev deltaY] > 0)
	{
		[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_DOWN | MOUSE_FLAG_BUTTON4 param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
		[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_BUTTON4 param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
	}
	else if ([ev deltaY] < 0)
	{
		[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_DOWN | MOUSE_FLAG_BUTTON5 param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
		[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_BUTTON5 param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
	}
}

- (BOOL)checkMouseInBounds:(NSEvent *)ev
{ 
	mouseLoc = [self convertPoint:[ev locationInWindow] fromView:nil];
	return NSPointInRect([self convertPoint:[ev locationInWindow] fromView:nil], [self bounds]);
}

- (void)mouseDragged:(NSEvent *)ev
{
	if ([self checkMouseInBounds:ev])
		[self mouseMoved:ev];
}

- (void)mouseMoved:(NSEvent *)ev
{
	if ([self checkMouseInBounds:ev])
		[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_MOVE param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
	else
		[super mouseMoved:ev];
}


#pragma mark -
#pragma mark Converting RDP Colors

- (void)rgbForRDCColor:(int)col r:(unsigned char *)r g:(unsigned char *)g b:(unsigned char *)b
{
	if (bitdepth == 8)
	{
		int t = colorMap[col];
		*r = (t >> 16) & 0xff;
		*g = (t >> 8)  & 0xff;
		*b =  t        & 0xff;
	}
	else if (bitdepth == 16)
	{
		*r = ((col >> 8) & 0xf8) | ((col >> 13) & 0x7);
		*g = ((col >> 3) & 0xfc) | ((col >> 9) & 0x3);
		*b = ((col << 3) & 0xf8) | ((col >> 2) & 0x7);
	}
	else if (bitdepth == 24 || bitdepth == 32)
	{
		*r =  col        & 0xff;
		*g = (col >> 8)  & 0xff;
		*b = (col >> 16) & 0xff;
	}
	else
	{
		DEBUG_UI( (@"Attempting to convert color in unknown bitdepth %d", bitdepth) );
	}
}

- (NSColor *)nscolorForRDCColor:(int)col
{
	int r, g, b, t;
	
	if (bitdepth == 8)
	{
		t = colorMap[col];
		r = (t >> 16) & 0xff;
		g = (t >> 8)  & 0xff;
		b = t & 0xff;
	}
	else if (bitdepth == 16)
	{
		r = ((col >> 8) & 0xf8) | ((col >> 13) & 0x7);
		g = ((col >> 3) & 0xfc) | ((col >> 9) & 0x3);
		b = ((col << 3) & 0xf8) | ((col >> 2) & 0x7);
	}
	else if (bitdepth == 24)
	{
		r = col & 0xff;
		g = (col >> 8)  & 0xff;
		b = (col >> 16) & 0xff;
	}
	else
	{
		NSLog(@"Bitdepth = %d", bitdepth);
		r = g = b = 0;
	}
	
	return [NSColor colorWithDeviceRed:(float)r / 255.0
								 green:(float)g / 255.0
							  	  blue:(float)b / 255.0
							     alpha:1.0];
}


#pragma mark -
#pragma mark Accessors

- (int)bitsPerPixel
{
	return bitdepth;
}

- (int)width
{
	return [self bounds].size.width;
}

- (int)height
{
	return [self bounds].size.height;
}

- (unsigned int *)colorMap
{
	return colorMap;
}

- (void)setColorMap:(unsigned int *)map
{
	free(colorMap);
	colorMap = map;
}

- (void)setBitdepth:(int)depth
{
	bitdepth = depth;
}

- (void)setCursor:(NSCursor *)cur
{
	[cur retain];
	[cursor release];
	cursor = cur;
	
	[[self window] invalidateCursorRectsForView:self];
	[[self window] resetCursorRects];
}

- (void)setNeedsDisplayInRectAsValue:(NSValue *)rectValue
{
	NSRect r = [rectValue rectValue];
	
	// Hack: make the box 1px bigger all around; seems to make updates much more
	//	reliable when the screen is stretched
	r.origin.x = (int)r.origin.x - 1.0;
	r.origin.y = (int)r.origin.y - 1.0;
	r.size.width = (int)r.size.width + 2.0;
	r.size.height = (int)r.size.height + 2.0;

	[self setNeedsDisplayInRect:r];
}

@end
