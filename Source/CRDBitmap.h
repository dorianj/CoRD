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

#import <Cocoa/Cocoa.h>

@class CRDSessionView;

@interface CRDBitmap : NSObject
{
	NSImage *image;
	NSData *data;
	NSCursor *cursor;
	NSColor *color;
}

- (id)initWithBitmapData:(const unsigned char *)d size:(NSSize)s view:(CRDSessionView *)v;
- (id)initWithGlyphData:(const unsigned char *)d size:(NSSize)s view:(CRDSessionView *)v;
- (id)initWithCursorData:(const unsigned char *)d alpha:(const unsigned char *)a size:(NSSize)s hotspot:(NSPoint)hotspot view:(CRDSessionView *)v;

- (void)drawInRect:(NSRect)dstRect fromRect:(NSRect)srcRect operation:(NSCompositingOperation)op;

- (void)overlayColor:(NSColor *)c;

- (NSImage *)image;
- (void)setColor:(NSColor *)color;
- (NSColor *)color;
- (NSCursor *)cursor;
@end
