//
//  RDCView.m
//  Remote Desktop
//
//  Created by Craig Dooley on 4/25/06.

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
#import "constants.h"
#import "scancodes.h"

@implementation RDCView

#pragma mark NSView functions
- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		back = [[NSImage alloc] initWithSize:frame.size];
		[self resetClip];
		[back lockFocus];
		[[NSColor blackColor] set];
		[NSBezierPath fillRect:frame];
		[back unlockFocus];
		
		attributes = [[NSMutableDictionary alloc] init];
		[attributes setValue:[NSColor whiteColor] forKey:NSForegroundColorAttributeName];
    }
    return self;
}


-(BOOL)acceptsFirstResponder {
	return YES;
}

- (void)drawRect:(NSRect)rect {
	[back drawInRect:rect fromRect:rect operation:NSCompositeCopy fraction:1.0];
	// [NSStringFromPoint(mouseLoc) drawAtPoint:NSMakePoint(10, 10) withAttributes:attributes];	
}

-(BOOL)isFlipped {
	return YES;
}

#pragma mark NSObject functions

-(void)dealloc {
	[super dealloc];
}

#pragma mark Remote Desktop methods
-(void)ellipse:(NSRect)r color:(NSColor *)c {
	[back lockFocus];
	NSRectClip(clipRect);
	[c set];
	[[NSBezierPath bezierPathWithOvalInRect:r] fill];
	[back unlockFocus];
}

-(void)polygon:(POINT *)points npoints:(int)nPoints color:(NSColor *)c  winding:(NSWindingRule)winding {
	NSBezierPath *bp = [NSBezierPath bezierPath];
	int i;
	
	[bp moveToPoint:NSMakePoint(points[0].x + 0.5, points[0].y + 0.5)];
	for (i = 1; i < nPoints; i++) {
		[bp relativeLineToPoint:NSMakePoint(points[i].x, points[i].y)];
	}
	[bp closePath];
	
	[back lockFocus];
	NSRectClip(clipRect);
	[c set];
	[bp fill];
	[back unlockFocus];
}

-(void)polyline:(POINT *)points npoints:(int)nPoints color:(NSColor *)c width:(int)w {
	NSBezierPath *bp = [NSBezierPath bezierPath];
	int i;
	
	[bp moveToPoint:NSMakePoint(points[0].x + 0.5, points[0].y + 0.5)];
	for (i = 1; i < nPoints; i++) {
		[bp relativeLineToPoint:NSMakePoint(points[i].x, points[i].y)];
	}
	[bp setLineWidth:w];

	[back lockFocus];
	NSRectClip(clipRect);
	[c set];
	[bp stroke];
	[back unlockFocus];
}

-(void)fillRect:(NSRect)rect {
	[self fillRect:rect withColor:foregroundColor patternOrigin:NSZeroPoint];
}

-(void)fillRect:(NSRect)rect withColor:(NSColor *) color {	
	[self fillRect:rect withColor:color patternOrigin:NSZeroPoint];
}

-(void)fillRect:(NSRect)rect withColor:(NSColor *) color patternOrigin:(NSPoint)origin {
	[back lockFocus];
	NSRectClip(clipRect);
	[color set];
	[[NSGraphicsContext currentContext] setPatternPhase:origin];
	[NSBezierPath fillRect:rect];
	[back unlockFocus];
}

-(void)memblt:(NSRect)to from:(NSImage *)image withOrigin:(NSPoint)origin {
	[back lockFocus];
	NSRectClip(clipRect);
	[image drawInRect:to
			 fromRect:NSMakeRect(origin.x, origin.y, to.size.width, to.size.height)
			operation:NSCompositeSourceOver
			 fraction:1.0];
	[back unlockFocus];
}




-(NSColor *)translateColor:(int)col {
	int bitdepth = [controller conn]->serverBpp;
	NSColor *ret;
	int r, g, b;
	
	if (bitdepth == 8) {
		ret = [colorMap objectAtIndex:col];
	} else if (bitdepth == 16) {
		r = ((col >> 8) & 0xf8) | ((col >> 13) & 0x7);
		g = ((col >> 3) & 0xfc) | ((col >> 9) & 0x3);
		b =((col << 3) & 0xf8) | ((col >> 2) & 0x7);
		ret = [NSColor colorWithDeviceRed:(float)r / 255.0
										green:(float)g / 255.0
										 blue:(float)b / 255.0
										alpha:1.0];
	} else if (bitdepth == 24) {
		r = (col >> 16) & 0xff;
		g = (col >> 8)  & 0xff;
		b = col & 0xff;
		ret = [NSColor colorWithDeviceRed:(float)r / 255.0
										green:(float)g / 255.0
										 blue:(float)b / 255.0
										alpha:1.0];
	} else {
		NSLog(@"Bitdepth = %d", bitdepth);
		ret = [NSColor blackColor];
	}
	
	return ret;
}

-(void)send_modifiers:(NSEvent *)ev enable:(BOOL)en {
	int NSFlags = [ev modifierFlags];
	int flag;
	
	if (en == YES) {
		flag = RDP_KEYPRESS;
	} else {
		flag = RDP_KEYRELEASE;
	}
	
	if (NSFlags & NSAlphaShiftKeyMask) {
		[controller sendInput:RDP_INPUT_SCANCODE flags:flag param1:SCANCODE_CHAR_CAPSLOCK param2:0];
	}
	
	if (NSFlags & NSShiftKeyMask) {
		[controller sendInput:RDP_INPUT_SCANCODE flags:flag param1:SCANCODE_CHAR_LSHIFT param2:0];
	}
	
	if (NSFlags & NSControlKeyMask) {
		[controller sendInput:RDP_INPUT_SCANCODE flags:flag param1:SCANCODE_CHAR_LCTRL param2:0];
	}
	
	if (NSFlags & NSAlternateKeyMask) {
		[controller sendInput:RDP_INPUT_SCANCODE flags:flag param1:SCANCODE_CHAR_LALT param2:0];
	}
	
	if (NSFlags & NSCommandKeyMask) {
		[controller sendInput:RDP_INPUT_SCANCODE flags:flag param1:SCANCODE_CHAR_LWIN param2:0];
	}
}

-(void)set_remote_modifiers:(NSEvent *)ev {
	[self send_modifiers:ev enable:YES];
}

-(void)restore_remote_modifiers:(NSEvent *)ev {
	[self send_modifiers:ev enable:NO];
}

-(void)saveDesktop {
	[save release];
	save = [back copy];
}

-(void)restoreDesktop:(NSRect)size {
	[back lockFocus];
	NSRectClip(clipRect);
	[save drawInRect:size
			fromRect:size
		   operation:NSCompositeCopy
			fraction:1.0];
	[back unlockFocus];
}

-(void)screenBlit:(NSRect)from to:(NSPoint)to {
	[back lockFocus];
	NSRectClip(clipRect);
	NSCopyBits(nil, from, to);
	[back unlockFocus];
	
}

-(void)drawLineFrom:(NSPoint)start to:(NSPoint)end color:(NSColor *)color width:(int)width {
	NSBezierPath *bp = [NSBezierPath bezierPath];
	[back lockFocus];
	NSRectClip(clipRect);
	[color set];
	[bp moveToPoint:start];
	[bp lineToPoint:end];
	[bp setLineWidth:width];
	[bp stroke];
	[back unlockFocus];
}


-(void)drawGlyph:(RDCBitmap *)glyph at:(NSRect)r fg:(int)fgcolor bg:(int)bgcolor {
	NSColor *fg, *bg;
	fg = [self translateColor:fgcolor];
	bg = [self translateColor:bgcolor];
	NSImage *image = [glyph image];
	
	if (! [[glyph color] isEqual:fg]) {
		[image lockFocus];
		[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeSourceAtop];
		[fg setFill];
		[NSBezierPath fillRect:NSMakeRect(0, 0, [image size].width, [image size].height)];
		[image unlockFocus];
		[glyph setColor:fg];
	}
	
	[back lockFocus];
	NSRectClip(clipRect);
	[image drawInRect:r
			 fromRect:NSMakeRect(0, 0, r.size.width, r.size.height)
			operation:NSCompositeSourceOver
			 fraction:1.0];
	[back unlockFocus];
}

-(void)setClip:(NSRect)r {
	clipRect = r;
}

-(void)resetClip {
	NSRect r = NSZeroRect;
	r.size = [back size];
	
	clipRect = r;
}

#pragma mark Event Handling Methods

-(void)keyDown:(NSEvent *)ev {
	int key = [ev keyCode];
	unsigned char scancode = [[RDCKeyboard shared] scancodeForKeycode:key];
	[self set_remote_modifiers:ev];
	[controller sendInput:RDP_INPUT_SCANCODE flags:RDP_KEYPRESS param1:scancode param2:0];
	[self restore_remote_modifiers:ev];
}

-(void)keyUp:(NSEvent *)ev {
	int key = [ev keyCode];
	unsigned char scancode = [[RDCKeyboard shared] scancodeForKeycode:key];
	[controller sendInput:RDP_INPUT_SCANCODE flags:RDP_KEYRELEASE param1:scancode param2:0];
}

-(void)mouseDown:(NSEvent *)ev {
	mouseLoc = [self convertPoint:[ev locationInWindow] fromView:nil];
	[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_DOWN | MOUSE_FLAG_BUTTON1 param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
}

-(void)mouseUp:(NSEvent *)ev {
	mouseLoc = [self convertPoint:[ev locationInWindow] fromView:nil];
	[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_BUTTON1 param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
}

-(void)rightMouseDown:(NSEvent *)ev {
	mouseLoc = [self convertPoint:[ev locationInWindow] fromView:nil];
	[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_DOWN | MOUSE_FLAG_BUTTON2 param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
}

-(void)rightMouseUp:(NSEvent *)ev {
	mouseLoc = [self convertPoint:[ev locationInWindow] fromView:nil];
	[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_BUTTON2 param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
}

-(void)scrollWheel:(NSEvent *)ev {
	if ([ev deltaY] > 0) {
		[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_DOWN | MOUSE_FLAG_BUTTON4 param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
	} else {
		[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_DOWN | MOUSE_FLAG_BUTTON5 param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
	}
}

/* 
-(void)otherMouseDown:(NSEvent *)ev {
	NSLog(@"other");
}

-(void)otherMouseUp:(NSEvent *)ev {
	NSLog(@"other");
} */

-(BOOL)checkMouseInBounds:(NSEvent *)ev {
	NSRect frame = [self frame];
	mouseLoc = [self convertPoint:[ev locationInWindow] fromView:nil];
	
	if ((mouseLoc.x < frame.origin.x) || (mouseLoc.x > frame.size.width) || 
		(mouseLoc.y < frame.origin.y) || (mouseLoc.y > frame.size.height)) {
		return NO;
	}
	return YES;
}

-(void)mouseDragged:(NSEvent *)ev {
	[self mouseMoved:ev];
}

-(void)mouseMoved:(NSEvent *)ev {
	if ([self checkMouseInBounds:ev]) {
		[controller sendInput:RDP_INPUT_MOUSE flags:MOUSE_FLAG_MOVE param1:(int)mouseLoc.x param2:(int)mouseLoc.y];
	}
}

#pragma mark Accessor Methods

-(void)setForeground:(NSColor *)color {
	[color retain];
	[foregroundColor release];
	foregroundColor = color;
}

-(void)setBackground:(NSColor *)color {
	[color retain];
	[backgroundColor release];
	backgroundColor = color;
}

-(int)bitsPerPixel {
	return [controller conn]->serverBpp;
}

-(void)setFrameSize:(NSSize)size {
	[back release];
	[save release];
	back = [[NSImage alloc] initWithSize:size];
	[super setFrameSize:size];
}

-(int)width {
	return [self frame].size.width;
}

-(int)height {
	return [self frame].size.height;
}

-(NSArray *)colorMap {
	return colorMap;
}

-(int)setColorMap:(NSArray *)map {
	[map retain];
	[colorMap release];
	colorMap = map;
	return 0;
}

-(void)swapRect:(NSRect)r {
	[back lockFocus];
	CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	CGContextSaveGState(context);
	CGContextSetBlendMode(context, kCGBlendModeDifference);
	CGContextSetRGBFillColor (context, 1.0, 1.0, 1.0, 1.0);
	CGContextFillRect (context, CGRectMake(r.origin.x, r.origin.y, r.size.width, r.size.height));
	CGContextRestoreGState (context);
	[back unlockFocus];
}
@end
