/*	Copyright (c) 2007 Dorian Johnson <arcadiclife@gmail.com>
	
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

//	Replaces: xwin.c


#import <Cocoa/Cocoa.h>

#import "rdesktop.h"

#import "CRDShared.h"
#import "CRDSession.h"
#import "CRDSessionView.h"
#import "CRDBitmap.h"


/* Opcodes
    GXclear,			0  0
    GXnor,				1  !src & !dst
    GXandInverted,		2  !src & dst
    GXcopyInverted,		3  !src
    GXandReverse,		4  src & !dst
    GXinvert,			5  !dst
    GXxor,				6  src ^ dst
    GXnand,				7  !src | !dst
    GXand,				8  src & dst
    GXequiv,			9  !src ^ dst
    GXnoop,				10 dst
    GXorInverted,		11 !src | dst
    GXcopy,				12 src
    GXorReverse,		13 src | !dst
    GXor,				14 src or dst
    GXset				15 1
*/
	

// For managing the current draw session (the time bracketed between ui_begin_update and ui_end_update)
static void schedule_display(RDConnectionRef conn);
static void schedule_display_in_rect(RDConnectionRef conn, NSRect r);

static CRDBitmap *nullCursor = nil;

#pragma mark -
#pragma mark Resizing the Connection Window

void ui_resize_window(RDConnectionRef conn)
{
	LOCALS_FROM_CONN;
	
	[v setScreenSize:NSMakeSize(conn->screenWidth, conn->screenHeight)];
	
	// xxx: doesn't work with windowed mode
	[g_appController performSelectorOnMainThread:@selector(autosizeUnifiedWindow) withObject:nil waitUntilDone:NO];
}

#pragma mark -
#pragma mark Colormap 

RDColorMapRef ui_create_colourmap(RDColorMap * colors)
{
	unsigned int *colorMap = malloc(colors->ncolours * sizeof(unsigned));
	
	for (int i = 0; i < colors->ncolours; i++)
	{
		RDColorEntry colorEntry = colors->colours[i];
		colorMap[i] = (colorEntry.blue << 16) | (colorEntry.green << 8) | colorEntry.red;
	}
	
	return colorMap;
}

void ui_set_colourmap(RDConnectionRef conn, RDColorMapRef map)
{
	LOCALS_FROM_CONN;
	[v setColorMap:(unsigned int *)map];
}


#pragma mark -
#pragma mark Bitmap

RDBitmapRef ui_create_bitmap(RDConnectionRef conn, int width, int height, uint8 *data)
{
	return [[CRDBitmap alloc] initWithBitmapData:data size:NSMakeSize(width, height) view:conn->ui];
}

void ui_paint_bitmap(RDConnectionRef conn, int x, int y, int cx, int cy, int width, int height, uint8 * data)
{
	CRDBitmap *bitmap = [[CRDBitmap alloc] initWithBitmapData:data size:NSMakeSize(width, height) view:conn->ui];
	ui_memblt(conn, 0, x, y, cx, cy, bitmap, 0, 0);
	[bitmap release];
}

void ui_memblt(RDConnectionRef conn, uint8 opcode, int x, int y, int cx, int cy, RDBitmapRef src, int srcx, int srcy)
{
	LOCALS_FROM_CONN;
	
	CRDBitmap *bmp = (CRDBitmap *)src;
	NSRect r = NSMakeRect(x, y, cx, cy);
	NSPoint p = NSMakePoint(srcx, srcy);
	NSCompositingOperation compositingOp;
	switch (opcode)
	{
		case 0:
		case 12:
			compositingOp = NSCompositeCopy;
			break;
		
		case 6:
			compositingOp = NSCompositeCopy;
			break;
		
		default:
			CHECKOPCODE(opcode);
			compositingOp = NSCompositeCopy;
	}
	
	[v drawBitmap:bmp inRect:r from:p operation:compositingOp];

	schedule_display_in_rect(conn, r);
}

void ui_destroy_bitmap(RDBitmapRef bmp)
{
	id image = bmp;
	[image release];
}


#pragma mark -
#pragma mark Desktop Cache

// Takes a section of the desktop cache (backing store) and stores it into the 
//	rdesktop bitmap cache (using RDP colors). Adequately optimized, not critical.
void ui_desktop_save(RDConnectionRef conn, uint32 offset, int x, int y, int w, int h)
{
	LOCALS_FROM_CONN;
	
	unsigned char *screenDumpBytes = malloc(w*h*4);
	CGContextRef screenDumpContext = CGBitmapContextCreate(screenDumpBytes, w, h, 8, w*4, CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB), kCGImageAlphaPremultipliedFirst); 
	
	CGContextSaveGState(screenDumpContext); {
		CGImageRef backingStoreImage = CGBitmapContextCreateImage([v rdBufferContext]);
		CGContextDrawImage(screenDumpContext, CGRectMake(-x, -y, conn->screenWidth, conn->screenHeight), backingStoreImage);
		CGImageRelease(backingStoreImage);
	} CGContextRestoreGState(screenDumpContext);
	
		
	// Translate the 32-bit RGBA screen dump into RDP colors, using vImage if possible
	uint8 *output, *o, *p;
	int i=0, len=w*h, bytespp = (conn->serverBpp+7)/8;
	
	p = screenDumpBytes;
	output = o = malloc(len*bytespp);
	unsigned int *colorMap = [v colorMap], j, q;
	
	if (conn->serverBpp == 16)
	{
		while (i++ < len)
		{
			unsigned short c =	( ((p[1] * 31 + 127) / 255) << 11) |
								( ((p[2] * 63 + 127) / 255) << 5) |
								( (p[3] * 31 + 127) / 255);

			o[0] = c & 0xff;
			o[1] = (c >> 8) & 0xff;
			
			p += 4;
			o += bytespp;
		}
	}
	else if (conn->serverBpp == 15)
	{
		while (i++ < len)
		{
			unsigned short c =	(1 << 15) |
								(((p[1] * 31 + 127) / 255) << 10) |
								(((p[2] * 31 + 127) / 255) << 5) |
								((p[3] * 31 + 127) / 255);
								
			o[0] = c & 0xff;
			o[1] = (c >> 8) & 0xff;
			
			p += 4;
			o += bytespp;
		}		
	}
	else if (conn->serverBpp == 8)
	{
		// Find color's index on colormap, use it as color
		while (i++ < len)
		{
			j = (p[3] << 16) | (p[2] << 8) | p[1];
			o[0] = 0;
			for (q = 0; q <= 0xff; q++) {
				if (colorMap[q] == j) {
					o[0] = q;
					break;
				}
			}
				
			p += 4;
			o += bytespp;
		}
	}
	else // 24
	{
		while (i++ < len)
		{
			o[2] = p[1];
			o[1] = p[2];
			o[0] = p[3];
			
			p += 4;
			o += bytespp;
		}
	}
	
	// Put the translated screen dump into the rdesktop bitmap cache
	offset *= bytespp;
	cache_put_desktop(conn, offset, w, h, w*bytespp, bytespp, output);
	
	free(screenDumpBytes);
	free(output);
}

void ui_desktop_restore(RDConnectionRef conn, uint32 offset, int x, int y, int w, int h)
{
	LOCALS_FROM_CONN;
		
	offset *= (conn->serverBpp+7)/8;
	uint8 *data = cache_get_desktop(conn, offset, w, h, (conn->serverBpp+7)/8);
	
	if (data == NULL)
		return; 
	
	NSRect r = NSMakeRect(x, y, w, h);
	CRDBitmap *b = [[CRDBitmap alloc] initWithBitmapData:(const unsigned char *)data size:NSMakeSize(w, h) view:v];
	
	[[b image] setFlipped:NO];
	[v focusBackingStore];
	[b drawInRect:r fromRect:NSMakeRect(0,0,w,h) operation:NSCompositeCopy];
	[v releaseBackingStore];
	
	schedule_display_in_rect(conn, r);
	[b release];
}


#pragma mark -
#pragma mark Managing Draw Session

void ui_begin_update(RDConnectionRef conn)
{
	conn->updateEntireScreen = NO;
}

void ui_end_update(RDConnectionRef conn)
{
	LOCALS_FROM_CONN;
	
	if (conn->updateEntireScreen)
	{
		[v performSelectorOnMainThread:@selector(setNeedsDisplay:)
			withObject:[NSNumber numberWithBool:YES] waitUntilDone:NO];
	}
	
	conn->updateEntireScreen = NO;
}

static void schedule_display(RDConnectionRef conn)
{
	conn->updateEntireScreen = YES;
}

static void schedule_display_in_rect(RDConnectionRef conn, NSRect r)
{
	// Since CRDSessionView simply flushes its entire buffer to view on draw, it's simpler
	//	and quicker to simply update the entire view. This remains from the non-OpenGL
	//	implementation but may be useful in the future.
	conn->updateEntireScreen = YES;
}


#pragma mark -
#pragma mark General Drawing

void ui_rect(RDConnectionRef conn, int x, int y, int cx, int cy, int colour)
{
	LOCALS_FROM_CONN;
	NSRect r = NSMakeRect(x , y, cx, cy);
	[v fillRect:r withRDColor:colour];
	schedule_display_in_rect(conn, r);
}

void ui_line(RDConnectionRef conn, uint8 opcode, int startx, int starty, int endx, int endy, RDPen * pen)
{
	LOCALS_FROM_CONN;
	NSPoint start = NSMakePoint(startx + 0.5, starty + 0.5);
	NSPoint end = NSMakePoint(endx + 0.5, endy + 0.5);
	
	if (opcode == 15)
	{
		[v drawLineFrom:start to:end color:[NSColor whiteColor] width:pen->width];
		return;
	}
	
	CHECKOPCODE(opcode);
	[v drawLineFrom:start to:end color:[v nscolorForRDCColor:pen->colour] width:pen->width];
	schedule_display(conn);
}

void ui_screenblt(RDConnectionRef conn, uint8 opcode, int x, int y, int cx, int cy, int srcx, int srcy)
{
	LOCALS_FROM_CONN;
	NSRect src = NSMakeRect(srcx, srcy, cx, cy);
	NSPoint dest = NSMakePoint(x, y);
	
	CHECKOPCODE(opcode);
	[v screenBlit:src to:dest];
	schedule_display_in_rect(conn, NSMakeRect(x, y, cx, cy));
}

void ui_destblt(RDConnectionRef conn, uint8 opcode, int x, int y, int cx, int cy)
{
	LOCALS_FROM_CONN;
	NSRect r = NSMakeRect(x, y, cx, cy);
	/* XXX */
	switch (opcode)
	{
		case 0:
			[v fillRect:r withColor:[NSColor blackColor]];
			break;
		case 5:
			[v swapRect:r];
			break;
		case 15:
			[v fillRect:r withColor:[NSColor whiteColor]];
			break;
		default:
			CHECKOPCODE(opcode);
			break;
	}
	
	schedule_display_in_rect(conn, r);
}

void ui_polyline(RDConnectionRef conn, uint8 opcode, RDPoint* points, int npoints, RDPen *pen)
{
	LOCALS_FROM_CONN;
	CHECKOPCODE(opcode);
	[v polyline:points npoints:npoints color:[v nscolorForRDCColor:pen->colour] width:pen->width];
	schedule_display(conn);
}

void ui_polygon(RDConnectionRef conn, uint8 opcode, uint8 fillmode, RDPoint* point, int npoints, RDBrush *brush, int bgcolour, int fgcolour)
{
	LOCALS_FROM_CONN;
	
	NSWindingRule r;
	int style;
	CHECKOPCODE(opcode);
	
	switch (fillmode)
	{
		case ALTERNATE:
			r = NSEvenOddWindingRule;
			break;
		case WINDING:
			r = NSNonZeroWindingRule;
			break;
		default:
			UNIMPL;
			return;
	}
	
	style = brush != NULL ? brush->style : 0;
	
	switch (style)
	{
		case 0:
			[v polygon:point npoints:npoints color:[v nscolorForRDCColor:fgcolour] winding:r];
			break;
		default:
			UNIMPL;
			break;
	}
	
	schedule_display(conn);
}



static const uint8 hatch_patterns[] =
{
    0x00, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00, 0x00, /* 0 - bsHorizontal */
    0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, /* 1 - bsVertical */
    0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01, /* 2 - bsFDiagonal */
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, /* 3 - bsBDiagonal */
    0x08, 0x08, 0x08, 0xff, 0x08, 0x08, 0x08, 0x08, /* 4 - bsCross */
    0x81, 0x42, 0x24, 0x18, 0x18, 0x24, 0x42, 0x81  /* 5 - bsDiagCross */
};

/* XXX Still needs origins */
void ui_patblt(RDConnectionRef conn, uint8 opcode, int x, int y, int cx, int cy, RDBrush * brush, int bgcolor, int fgcolor)
{
	LOCALS_FROM_CONN;
	NSRect dest = NSMakeRect(x, y, cx, cy);
	NSRect glyphSize;
	CRDBitmap *bitmap;
	NSImage *fill;
	NSColor *fillColor;
	uint8 i, ipattern[8];
	
	if (opcode == 6)
	{
		[v swapRect:dest];
		schedule_display_in_rect(conn, dest);
		return;
	}
	
	CHECKOPCODE(opcode);
	
	switch (brush->style)
	{
		case 0: /* Solid */
			[v fillRect:dest withColor:[v nscolorForRDCColor:fgcolor]];
			schedule_display_in_rect(conn, dest);
			break;
		case 2: /* Hatch */

			glyphSize = NSMakeRect(0, 0, 8, 8);
            bitmap = ui_create_glyph(conn, 8, 8, hatch_patterns + brush->pattern[0] * 8);
			fill = [bitmap image];
			[fill lockFocus];
			
			[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeSourceAtop];
			[[v nscolorForRDCColor:fgcolor] set];
			[NSBezierPath fillRect:glyphSize];
			
			[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeDestinationAtop];
			[[v nscolorForRDCColor:bgcolor] set];
			[NSBezierPath fillRect:glyphSize];
			
			[fill unlockFocus];
			
			fillColor = [NSColor colorWithPatternImage:fill];
			[v fillRect:dest withColor:fillColor patternOrigin:NSMakePoint(brush->xorigin, brush->yorigin)];
            ui_destroy_glyph(bitmap);
            break;
		case 3: /* Pattern */
			for (i = 0; i != 8; i++)
				ipattern[7 - i] = brush->pattern[i];
			
			glyphSize = NSMakeRect(0, 0, 8, 8);
            bitmap = ui_create_glyph(conn, 8, 8, ipattern);
			fill = [bitmap image];
			[fill lockFocus];
			
			[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeSourceAtop];
			[[v nscolorForRDCColor:fgcolor] set];
			[NSBezierPath fillRect:glyphSize];
			
			[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeDestinationAtop];
			[[v nscolorForRDCColor:bgcolor] set];
			[NSBezierPath fillRect:glyphSize];
			
			[fill unlockFocus];
			
			fillColor = [NSColor colorWithPatternImage:fill];
			[v fillRect:dest withColor:fillColor patternOrigin:NSMakePoint(brush->xorigin, brush->yorigin)];
            ui_destroy_glyph(bitmap);
			break;
		default:
			unimpl("brush %d\n", brush->style);
			break;
	}
	schedule_display_in_rect(conn, dest);
}

void ui_triblt(uint8 opcode, 
			   int x, int y, int cx, int cy,
			   RDBitmapRef src, int srcx, int srcy,
			   RDBrush *brush, int bgcolour, int fgcolour)
{
	CHECKOPCODE(opcode);
	UNIMPL;
}

void ui_ellipse(RDConnectionRef conn, uint8 opcode, uint8 fillmode, int x, int y, int cx, int cy,
				RDBrush *brush, int bgcolour, int fgcolour)
{
	LOCALS_FROM_CONN;
	NSRect r = NSMakeRect(x + 0.5, y + 0.5, cx, cy);
	int style;
	CHECKOPCODE(opcode);
	
	style = brush != NULL ? brush->style : 0;
	
	switch (style)
	{
		case 0:
			[v ellipse:r color:[v nscolorForRDCColor:fgcolour]];
			break;
		default:
			UNIMPL;
			return;
	}
	schedule_display_in_rect(conn, r);
}

#pragma mark -
#pragma mark Text drawing

RDGlyphRef ui_create_glyph(RDConnectionRef conn, int width, int height, const uint8 *data)
{
	return [[CRDBitmap alloc] initWithGlyphData:data size:NSMakeSize(width, height) view:conn->ui];
}

void ui_destroy_glyph(RDGlyphRef glyph)
{
	[glyph release];
}

void ui_drawglyph(RDConnectionRef conn, int x, int y, int w, int h, CRDBitmap *glyph, NSColor *fgcolor, NSColor *bgcolor);

void ui_drawglyph(RDConnectionRef conn, int x, int y, int w, int h, CRDBitmap *glyph, NSColor *fgcolor, NSColor *bgcolor)
{
	LOCALS_FROM_CONN;
	[v drawGlyph:glyph at:NSMakeRect(x, y, w, h) foregroundColor:fgcolor];
}

#define DO_GLYPH(ttext,idx) \
{\
	glyph = cache_get_font (conn, font, ttext[idx]);\
	if (!(flags & TEXT2_IMPLICIT_X))\
	{\
		xyoffset = ttext[++idx];\
		if ((xyoffset & 0x80))\
		{\
			if (flags & TEXT2_VERTICAL)\
				y += ttext[idx+1] | (ttext[idx+2] << 8);\
			else\
				x += ttext[idx+1] | (ttext[idx+2] << 8);\
			idx += 2;\
		}\
		else\
		{\
			if (flags & TEXT2_VERTICAL)\
				y += xyoffset;\
			else\
				x += xyoffset;\
		}\
	}\
	if (glyph != NULL)\
	{\
		x1 = x + glyph->offset;\
		y1 = y + glyph->baseline;\
		ui_drawglyph(conn, x1, y1, glyph->width, glyph->height, glyph->pixmap, foregroundColor, backgroundColor); \
		if (flags & TEXT2_IMPLICIT_X)\
			x += glyph->width;\
	}\
}

void ui_draw_text(RDConnectionRef conn, uint8 font, uint8 flags, uint8 opcode, int mixmode, int x, int y, int clipx, int clipy,
				  int clipcx, int clipcy, int boxx, int boxy, int boxcx, int boxcy, RDBrush * brush, int bgcolour,
				  int fgcolour, uint8 * text, uint8 length)
{
	LOCALS_FROM_CONN;
	int i = 0, j, xyoffset, x1, y1;
	RDFontGlyph *glyph;
	RDDataBlob *entry;
	NSRect box;
	NSColor *foregroundColor = [v nscolorForRDCColor:fgcolour], *backgroundColor = [v nscolorForRDCColor:bgcolour];
	
	CHECKOPCODE(opcode);
	
	if (boxx + boxcx >= [v width])
		boxcx = [v width] - boxx;
	
	// Paint background
	box = (boxcx > 1) ? NSMakeRect(boxx, boxy, boxcx, boxcy) : NSMakeRect(clipx, clipy, clipcx, clipcy);
	
	if (boxcx > 1 || mixmode == MIX_OPAQUE)
		[v fillRect:box withColor:backgroundColor];
	
	[v startUpdate];
	
	// Paint text character by character
	for (i = 0; i < length;)
	{                       
		switch (text[i])
		{           
			case 0xff:  
				if (i + 2 < length)
				{
					cache_put_text(conn, text[i + 1], text, text[i + 2]);
				} 
				else
				{
					error("this shouldn't be happening\n");
					exit(1);
				} 
				
				// After FF command, move pointer to first character 

				length -= i + 3;
				text = &(text[i + 3]);
				i = 0;
				break;

			case 0xfe:
				entry = cache_get_text(conn, text[i + 1]);
				if (entry != NULL)
				{
					if ((((uint8 *) (entry->data))[1] == 0) && (!(flags & TEXT2_IMPLICIT_X)))
					{
						if (flags & TEXT2_VERTICAL)
							y += text[i + 2];
						else
							x += text[i + 2]; 
					}
					
					for (j = 0; j < entry->size; j++)
						DO_GLYPH(((uint8 *) (entry->data)), j);
				} 

				i += (i + 2 < length) ? 3 : 2;
				length -= i;
				// After FE command, move pointer to first character
				text = &(text[i]);
				i = 0;
				break;

			default:
				DO_GLYPH(text, i);
				i++;
				break;
		}
	}  
	
	[v stopUpdate];
	schedule_display_in_rect(conn, box);
}


#pragma mark -
#pragma mark Clipping drawing

void ui_set_clip(RDConnectionRef conn, int x, int y, int cx, int cy)
{
	LOCALS_FROM_CONN;
	[v setClip:NSMakeRect(x, y, cx, cy)];
}

void ui_reset_clip(RDConnectionRef conn)
{
	LOCALS_FROM_CONN;
	[v resetClip];
}

void ui_bell(void)
{
	NSBeep();
}


#pragma mark -
#pragma mark Cursors and Pointers

RDCursorRef ui_create_cursor(RDConnectionRef conn, unsigned int x, unsigned int y, int width, int height,
						 uint8 * andmask, uint8 * xormask)
{
	return  [[CRDBitmap alloc] initWithCursorData:andmask alpha:xormask 
			size:NSMakeSize(width, height) hotspot:NSMakePoint(x, y) view:conn->ui];
}

void ui_set_null_cursor(RDConnectionRef conn)
{
	if (nullCursor == nil)
		nullCursor = ui_create_cursor(conn, 0, 0, 0, 0, NULL, NULL);
		
	ui_set_cursor(conn, nullCursor);
}

void ui_set_cursor(RDConnectionRef conn, RDCursorRef cursor)
{
	LOCALS_FROM_CONN;
	id c = (CRDBitmap *)cursor;
	[v performSelectorOnMainThread:@selector(setCursor:) withObject:[c cursor] waitUntilDone:YES];
}

void ui_destroy_cursor(RDCursorRef cursor)
{
	id c = (CRDBitmap *)cursor;
	[c release];
}

void ui_move_pointer(RDConnectionRef conn, int x, int y)
{
	LOCALS_FROM_CONN;
	//xxx: check if this conn is active
	
	NSPoint windowPoint = [v convertPoint:NSMakePoint(x,y) toView:nil];
	NSPoint windowOrigin = [[v window] frame].origin;
	
	NSLog(@"Setting point to remote (%d, %d), or local screen %@", x, y, NSStringFromPoint(NSMakePoint(windowPoint.x+windowOrigin.x, windowPoint.y+windowPoint.y)));
	// xxx: wrong function
	//CGWarpMouseCursorPosition(CGPointMake(windowPoint.x+windowOrigin.x, windowPoint.y+windowPoint.y));
	
	//NSLog(@"Should move mouse to %d, %d", x, y);
}
