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

/*	Note: 'backing store' in this class refers only to the ivar 'back',  not anything appkit-related.
*/

#import "RDCView.h"
#import "RDCKeyboard.h"
#import "RDCBitmap.h"
#import "RDInstance.h"

#import "scancodes.h"

@interface RDCView (Private)
	- (void)send_modifiers:(NSEvent *)ev enable:(BOOL)en;
	- (void)focusBackingStore;
	- (void)releaseBackingStore;
@end

#pragma mark -

@implementation RDCView

#pragma mark NSObject

- (void)dealloc
{
	[keyTranslator release];
	[cursor release];
	[back release];

	free(colorMap);
	colorMap = NULL;
	
	[super dealloc];
}


#pragma mark -
#pragma mark NSView

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

- (BOOL)wantsDefaultClipping
{
	return NO;
}

- (void)drawRect:(NSRect)rect
{
	if (fabs(screenSize.width - [self frame].size.width) > .001)
	{
		[[NSGraphicsContext currentContext] setShouldAntialias:YES];
		if ([self inLiveResize])
			[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationLow];
		else
			[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	}
	
	
	int nRects, i;
	const NSRect* rects;
	[self getRectsBeingDrawn:&rects count:&nRects];
	for (i = 0; i < nRects; i++)
	{
		[back drawInRect:rects[i] fromRect:rects[i]  operation:NSCompositeCopy fraction:1.0];
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

- (void)viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	[self setNeedsDisplay:YES];
}


#pragma mark -
#pragma mark NSResponder Event Handlers

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)resignFirstResponder
{
	[self releaseRemoteModifiers];
	return [super resignFirstResponder];
}

- (BOOL)becomeFirstResponder
{
	[controller synchronizeRemoteClipboard:[NSPasteboard generalPasteboard] suggestedFormat:0];
	return YES;
}

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
#pragma mark Drawing to the backing store 

- (void)ellipse:(NSRect)r color:(NSColor *)c
{
	[self focusBackingStore];
	[c set];
	[[NSBezierPath bezierPathWithOvalInRect:r] fill];
	[self releaseBackingStore];
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
	
	[self focusBackingStore];
	[c set];
	[bp fill];
	[self releaseBackingStore];
}

- (void)polyline:(POINT *)points npoints:(int)nPoints color:(NSColor *)c width:(int)w
{
	NSBezierPath *bp = [NSBezierPath bezierPath];
	int i;
	
	[bp moveToPoint:NSMakePoint(points[0].x + 0.5, points[0].y + 0.5)];
	for (i = 1; i < nPoints; i++)
		[bp relativeLineToPoint:NSMakePoint(points[i].x, points[i].y)];

	[bp setLineWidth:w];
	[bp closePath];
	
	[self focusBackingStore];
	[c set];
	[bp stroke];
	[self releaseBackingStore];
}

- (void)fillRect:(NSRect)rect withColor:(NSColor *)color
{	
	[self fillRect:rect withColor:color patternOrigin:NSZeroPoint];
}

- (void)fillRect:(NSRect)rect withColor:(NSColor *) color patternOrigin:(NSPoint)origin
{
	[self focusBackingStore];
	[color set];
	[[NSGraphicsContext currentContext] setPatternPhase:origin];
	[NSBezierPath fillRect:rect];
	[self releaseBackingStore];
}

- (void)memblt:(NSRect)to from:(RDCBitmap *)image withOrigin:(NSPoint)origin
{
	[self focusBackingStore];
	
	NSAffineTransform *xform = [NSAffineTransform transform];	
	[xform translateXBy:to.origin.x yBy:to.origin.y];
	[xform concat];
	
	[image drawInRect:NSMakeRect(0.0, 0.0, to.size.width, to.size.height)
			 fromRect:NSMakeRect(origin.x, origin.y, to.size.width, to.size.height)
			operation:NSCompositeCopy];
	[self releaseBackingStore];
}

- (void)screenBlit:(NSRect)from to:(NSPoint)to
{
	[self focusBackingStore];
	NSCopyBits(nil, from, to);
	[self releaseBackingStore];
}

- (void)drawLineFrom:(NSPoint)start to:(NSPoint)end color:(NSColor *)color width:(int)width
{
	[NSBezierPath setDefaultLineWidth:0.0];
	
	[self focusBackingStore];
	[color set];
	[NSBezierPath strokeLineFromPoint:start toPoint:end];
	[self releaseBackingStore];
}

- (void)drawGlyph:(RDCBitmap *)glyph at:(NSRect)r fg:(NSColor *)fgcolor bg:(NSColor *)bgcolor
{
	// Assumes that focusBackingStore has already been called (for efficiency)
	
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
	
	[image drawInRect:r
			 fromRect:NSMakeRect(0, 0, r.size.width, r.size.height)
			operation:NSCompositeSourceOver
		     fraction:1.0];
}

- (void)swapRect:(NSRect)r
{
	[self focusBackingStore];
	CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	CGContextSaveGState(context);
	CGContextSetBlendMode(context, kCGBlendModeDifference);
	CGContextSetRGBFillColor(context, 1.0, 1.0, 1.0, 1.0);
	CGContextFillRect(context, CGRectMake(r.origin.x, r.origin.y, r.size.width, r.size.height));
	CGContextFlush(context);
	CGContextRestoreGState(context);
	[self releaseBackingStore];
}


#pragma mark -
#pragma mark Clipping backing store drawing

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
#pragma mark Controlling drawing to the backing store

- (void)startUpdate
{
	[self focusBackingStore];
}

- (void)stopUpdate
{
	[self releaseBackingStore];
}

- (void)focusBackingStore
{
	[back lockFocus];
	NSRectClip(clipRect);
}

- (void)releaseBackingStore
{
	[back unlockFocus];
}


#pragma mark -
#pragma mark Converting RDP Colors

- (void)rgbForRDCColor:(int)col r:(unsigned char *)r g:(unsigned char *)g b:(unsigned char *)b
{
	if (bitdepth == 16)
	{
		*r = (( (col >> 11) & 0x1f) * 255 + 15) / 31;
		*g = (( (col >> 5) & 0x3f) * 255 + 31) / 63;
		*b = ((col & 0x1f) * 255 + 15) / 31;
		return;
	}
	
	int t = (bitdepth == 8) ? colorMap[col] : col;

	*b = (t >> 16) & 0xff;
	*g = (t >> 8)  & 0xff;
	*r = t & 0xff;
}

- (NSColor *)nscolorForRDCColor:(int)col
{
	int r, g, b;
	if (bitdepth == 16)
	{
		r = (( (col >> 11) & 0x1f) * 255 + 15) / 31;
		g = (( (col >> 5) & 0x3f) * 255 + 31) / 63;
		b = ((col & 0x1f) * 255 + 15) / 31;
	}
	else // 8, 24, 32
	{
		int t = (bitdepth == 8) ? colorMap[col] : col;
		b = (t >> 16) & 0xff;
		g = (t >> 8)  & 0xff;
		r = t & 0xff;
	}
	
	return [NSColor colorWithDeviceRed:(float)r / 255.0
								 green:(float)g / 255.0
							  	  blue:(float)b / 255.0
							     alpha:1.0];
}


#pragma mark -
#pragma mark Other

// Assures that all modifier keys are released
- (void)releaseRemoteModifiers
{
	NSEvent *releaseModsEv = [NSEvent keyEventWithType:NSFlagsChanged location:NSZeroPoint
				modifierFlags:0 timestamp:nil windowNumber:0 context:nil characters:@""
				charactersIgnoringModifiers:@"" isARepeat:NO keyCode:0];
	[keyTranslator handleFlagsChanged:releaseModsEv];
}

- (void)setNeedsDisplayInRects:(NSArray *)rects
{
	NSEnumerator *enumerator = [rects objectEnumerator];
	id dirtyRect;
	
	while ( (dirtyRect = [enumerator nextObject]) )
		[self setNeedsDisplayInRectAsValue:dirtyRect];
	
	[rects release];
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


#pragma mark -
#pragma mark Accessors

- (void)setController:(RDInstance *)instance
{
	controller = instance;
	[keyTranslator setController:instance];
	bitdepth = [instance conn]->serverBpp;
}

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

@end
