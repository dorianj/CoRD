//
//  RDCBitmap.h
//  Xrdc
//
//  Created by Craig Dooley on 8/28/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RDCView.h"

@interface RDCBitmap : NSObject {
	NSImage *image;
	NSBitmapImageRep *bitmap;
	NSData *data;
	NSCursor *cursor;
	unsigned char *planes[2];
	NSColor *color;
}

-(void)bitmapWithData:(const unsigned char *)d size:(NSSize)s view:(RDCView *)v;
-(void)glyphWithData:(const unsigned char *)d size:(NSSize)s view:(RDCView *)v;
-(void)cursorWithData:(const unsigned char *)d alpha:(const unsigned char *)a size:(NSSize)s hotspot:(NSPoint)hotspot view:(RDCView *)v;
-(NSImage *)image;
-(void)setColor:(NSColor *)color;
-(NSColor *)color;
-(NSCursor *)cursor;
@end
