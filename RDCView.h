//
//  RDCView.h
//  Xrdc
//
//  Created by Craig Dooley on 4/25/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RDCController.h"

@class RDInstance;
@class RDCBitmap;

@interface RDCView : NSView {
	RDInstance *controller;
	NSArray *colorMap;
	NSImage *back, *save;
	NSPoint mouseLoc;
	NSMutableDictionary *attributes;
	NSRect clipRect;
	NSColor *foregroundColor, *backgroundColor;
}

-(void)fillRect:(NSRect)r;
-(void)fillRect:(NSRect)rect withColor:(NSColor *) color;
-(void)fillRect:(NSRect)rect withColor:(NSColor *) color patternOrigin:(NSPoint)origin;
-(NSArray *)colorMap;
-(void)polyline:(POINT *)points npoints:(int)nPoints color:(NSColor *)c width:(int)w;
-(void)polygon:(POINT *)points npoints:(int)nPoints color:(NSColor *)c  winding:(NSWindingRule)winding;
-(int)setColorMap:(NSArray *)map;
-(void)saveDesktop;
-(void)restoreDesktop:(NSRect)size;
-(void)memblt:(NSRect)r from:(NSImage *)src withOrigin:(NSPoint)origin;
-(void)screenBlit:(NSRect)from to:(NSPoint)to;
-(void)drawLineFrom:(NSPoint)start to:(NSPoint)end color:(NSColor *)color width:(int)w;
-(int)width;
-(int)height;
-(void)drawGlyph:(RDCBitmap *)glyph at:(NSRect)r fg:(int)fgcolor bg:(int)bgcolor;
-(void)setClip:(NSRect)r;
-(void)resetClip;
-(int)bitsPerPixel;
-(NSColor *)translateColor:(int)col;
-(void)setForeground:(NSColor *)color;
-(void)setBackground:(NSColor *)color;
-(void)swapRect:(NSRect)r;
-(void)ellipse:(NSRect)r color:(NSColor *)c;
@end
