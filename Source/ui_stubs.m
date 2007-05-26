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
#import <Accelerate/Accelerate.h>

#import "rdesktop.h"

#import <sys/types.h>
#import <sys/time.h>
#import <dirent.h>
#import <stdio.h>

// for device redirection code in ui_select
#import <sys/stat.h>
#import <sys/times.h>

#import "RDCView.h"
#import "RDCBitmap.h"
#import "RDInstance.h"

#import "miscellany.h"

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

#define EXTRACT_USEFUL_VARS									\
	RDCView *v = (RDCView *)conn->ui;						\
	RDInstance *inst = (RDInstance *)conn->controller;
	

// For managing the current draw session (the time bracketed between ui_begin_update and ui_end_update)
static void schedule_display(rdcConnection conn);
static void schedule_display_in_rect(rdcConnection conn, NSRect r);

static RDCBitmap *nullCursor = nil;

#pragma mark -
#pragma mark Resizing the Connection Window

void ui_resize_window(rdcConnection conn)
{
	EXTRACT_USEFUL_VARS;
	
	[v setScreenSize:NSMakeSize(conn->screenWidth, conn->screenHeight)];
	
	// xxx: doesn't work with windowed mode
	[g_appController performSelectorOnMainThread:@selector(autosizeUnifiedWindow) withObject:nil waitUntilDone:NO];
}

#pragma mark -
#pragma mark Colormap 

RDColorMapRef ui_create_colourmap(COLOURMAP * colors)
{
	unsigned int *colorMap = malloc(colors->ncolours * sizeof(unsigned));
	
	for (int i = 0; i < colors->ncolours; i++)
	{
		COLOURENTRY colorEntry = colors->colours[i];
		colorMap[i] = (colorEntry.blue << 16) | (colorEntry.green << 8) | colorEntry.red;
	}
	
	return colorMap;
}

void ui_set_colourmap(rdcConnection conn, RDColorMapRef map)
{
	EXTRACT_USEFUL_VARS;
	[v setColorMap:(unsigned int *)map];
}


#pragma mark -
#pragma mark Bitmap

RDBitmapRef ui_create_bitmap(rdcConnection conn, int width, int height, uint8 *data)
{
	return [[RDCBitmap alloc] initWithBitmapData:data size:NSMakeSize(width, height) view:conn->ui];
}

void ui_paint_bitmap(rdcConnection conn, int x, int y, int cx, int cy, int width, int height, uint8 * data)
{
	RDCBitmap *bitmap = [[RDCBitmap alloc] initWithBitmapData:data size:NSMakeSize(width, height) view:conn->ui];
	ui_memblt(conn, 0, x, y, cx, cy, bitmap, 0, 0);
	[bitmap release];
}

void ui_memblt(rdcConnection conn, uint8 opcode, int x, int y, int cx, int cy, RDBitmapRef src, int srcx, int srcy)
{
	EXTRACT_USEFUL_VARS;
	
	RDCBitmap *bmp = (RDCBitmap *)src;
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
void ui_desktop_save(rdcConnection conn, uint32 offset, int x, int y, int w, int h)
{
	EXTRACT_USEFUL_VARS;
	
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
	
	vImage_Buffer outputBuffer, sourceBuffer;
	sourceBuffer.width = outputBuffer.width = w;
	sourceBuffer.height = outputBuffer.height = h;
	
	outputBuffer.data = output;
	outputBuffer.rowBytes = w * bytespp;
	
	sourceBuffer.data = (void *)screenDumpBytes;
	sourceBuffer.rowBytes = w * 4;
	
	if (conn->serverBpp == 16)
	{
		vImageConvert_ARGB8888toRGB565(&sourceBuffer, &outputBuffer, 0);		
	}
	else if (conn->serverBpp == 15)
	{
		vImageConvert_ARGB8888toARGB1555(&sourceBuffer, &outputBuffer, 0);			
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

void ui_desktop_restore(rdcConnection conn, uint32 offset, int x, int y, int w, int h)
{
	EXTRACT_USEFUL_VARS;
		
	offset *= (conn->serverBpp+7)/8;
	uint8 *data = cache_get_desktop(conn, offset, w, h, (conn->serverBpp+7)/8);
	
	if (data == NULL)
		return; 
	
	NSRect r = NSMakeRect(x, y, w, h);
	RDCBitmap *b = [[RDCBitmap alloc] initWithBitmapData:(const unsigned char *)data size:NSMakeSize(w, h) view:v];
	
	[[b image] setFlipped:NO];
	[v focusBackingStore];
	[b drawInRect:r fromRect:NSMakeRect(0,0,w,h) operation:NSCompositeCopy];
	[v releaseBackingStore];
	
	schedule_display_in_rect(conn, r);
	[b release];
}


#pragma mark -
#pragma mark Managing Draw Session

void ui_begin_update(rdcConnection conn)
{
	conn->updateEntireScreen = NO;
}

void ui_end_update(rdcConnection conn)
{
	EXTRACT_USEFUL_VARS;
	
	if (conn->updateEntireScreen)
	{
		[v performSelectorOnMainThread:@selector(setNeedsDisplay:)
			withObject:[NSNumber numberWithBool:YES] waitUntilDone:NO];
	}
	
	conn->updateEntireScreen = NO;
}

static void schedule_display(rdcConnection conn)
{
	conn->updateEntireScreen = YES;
}

static void schedule_display_in_rect(rdcConnection conn, NSRect r)
{
	// Since RDCView simply flushes its entire buffer to view on draw, it's simpler
	//	and quicker to simply update the entire view. This remains from the non-OpenGL
	//	implementation but may be useful in the future.
	conn->updateEntireScreen = YES;
}


#pragma mark -
#pragma mark General Drawing

void ui_rect(rdcConnection conn, int x, int y, int cx, int cy, int colour)
{
	EXTRACT_USEFUL_VARS;
	NSRect r = NSMakeRect(x , y, cx, cy);
	[v fillRect:r withRDColor:colour];
	schedule_display_in_rect(conn, r);
}

void ui_line(rdcConnection conn, uint8 opcode, int startx, int starty, int endx, int endy, PEN * pen)
{
	EXTRACT_USEFUL_VARS;
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
	// xxx: this should work quicker, but I haven't been able to test it (never called by rdesktop in use)
	//schedule_display_in_rect(conn, NSMakeRect(startx, starty, endx, endy));
}

void ui_screenblt(rdcConnection conn, uint8 opcode, int x, int y, int cx, int cy, int srcx, int srcy)
{
	EXTRACT_USEFUL_VARS;
	NSRect src = NSMakeRect(srcx, srcy, cx, cy);
	NSPoint dest = NSMakePoint(x, y);
	
	CHECKOPCODE(opcode);
	[v screenBlit:src to:dest];
	schedule_display_in_rect(conn, NSMakeRect(x, y, cx, cy));
}

void ui_destblt(rdcConnection conn, uint8 opcode, int x, int y, int cx, int cy)
{
	EXTRACT_USEFUL_VARS;
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

void ui_polyline(rdcConnection conn, uint8 opcode, POINT * points, int npoints, PEN *pen)
{
	EXTRACT_USEFUL_VARS;
	CHECKOPCODE(opcode);
	[v polyline:points npoints:npoints color:[v nscolorForRDCColor:pen->colour] width:pen->width];
	schedule_display(conn);
}

void ui_polygon(rdcConnection conn, uint8 opcode, uint8 fillmode, POINT * point, int npoints, BRUSH *brush, int bgcolour, int fgcolour)
{
	EXTRACT_USEFUL_VARS;
	
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
void ui_patblt(rdcConnection conn, uint8 opcode, int x, int y, int cx, int cy, BRUSH * brush, int bgcolor, int fgcolor)
{
	EXTRACT_USEFUL_VARS;
	NSRect dest = NSMakeRect(x, y, cx, cy);
	NSRect glyphSize;
	RDCBitmap *bitmap;
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
			   BRUSH *brush, int bgcolour, int fgcolour)
{
	CHECKOPCODE(opcode);
	UNIMPL;
}

void ui_ellipse(rdcConnection conn, uint8 opcode, uint8 fillmode, int x, int y, int cx, int cy,
				BRUSH *brush, int bgcolour, int fgcolour)
{
	EXTRACT_USEFUL_VARS;
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

RDGlyphRef ui_create_glyph(rdcConnection conn, int width, int height, const uint8 *data)
{
	return [[RDCBitmap alloc] initWithGlyphData:data size:NSMakeSize(width, height) view:conn->ui];
}

void ui_destroy_glyph(RDGlyphRef glyph)
{
	id image = glyph;
	[image release];
}

void ui_drawglyph(rdcConnection conn, int x, int y, int w, int h, RDCBitmap *glyph, NSColor *fgcolor, NSColor *bgcolor);

void ui_drawglyph(rdcConnection conn, int x, int y, int w, int h, RDCBitmap *glyph, NSColor *fgcolor, NSColor *bgcolor)
{
	EXTRACT_USEFUL_VARS;
	NSRect r = NSMakeRect(x, y, w, h);
	[v drawGlyph:glyph at:r fg:fgcolor bg:bgcolor];
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

void ui_draw_text(rdcConnection conn, uint8 font, uint8 flags, uint8 opcode, int mixmode, int x, int y, int clipx, int clipy,
				  int clipcx, int clipcy, int boxx, int boxy, int boxcx, int boxcy, BRUSH * brush, int bgcolour,
				  int fgcolour, uint8 * text, uint8 length)
{
	EXTRACT_USEFUL_VARS;
	int i = 0, j;
	int xyoffset;
	int x1, y1;
	FONTGLYPH *glyph;
	DATABLOB *entry;
	NSRect box;
	NSColor *foregroundColor = [v nscolorForRDCColor:fgcolour];
	NSColor *backgroundColor = [v nscolorForRDCColor:bgcolour];
	
	CHECKOPCODE(opcode);
	
	if (boxx + boxcx >= [v width])
		boxcx = [v width] - boxx;
	
	// Paint background
	box = (boxcx > 1) ? NSMakeRect(boxx, boxy, boxcx, boxcy) : NSMakeRect(clipx, clipy, clipcx, clipcy);
	
	if (boxcx > 1 || mixmode == MIX_OPAQUE)
		[v fillRect:box withColor:backgroundColor];
	
	[v startUpdate];
	
	/* Paint text, character by character */
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
				} /* this will move pointer from start to first character after FF command */ 

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
				/* this will move pointer from start to first character after FE command */
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

void ui_set_clip(rdcConnection conn, int x, int y, int cx, int cy)
{
	EXTRACT_USEFUL_VARS;
	[v setClip:NSMakeRect(x, y, cx, cy)];
}

void ui_reset_clip(rdcConnection conn)
{
	EXTRACT_USEFUL_VARS;
	[v resetClip];
}

void ui_bell(void)
{
	NSBeep();
}


#pragma mark -
#pragma mark Cursors and Pointers

RDCursorRef ui_create_cursor(rdcConnection conn, unsigned int x, unsigned int y, int width, int height,
						 uint8 * andmask, uint8 * xormask)
{
	return  [[RDCBitmap alloc] initWithCursorData:andmask alpha:xormask 
			size:NSMakeSize(width, height) hotspot:NSMakePoint(x, y) view:conn->ui];
}

void ui_set_null_cursor(rdcConnection conn)
{
	if (nullCursor == nil)
		nullCursor = ui_create_cursor(conn, 0, 0, 0, 0, NULL, NULL);
		
	ui_set_cursor(conn, nullCursor);
}

void ui_set_cursor(rdcConnection conn, RDCursorRef cursor)
{
	EXTRACT_USEFUL_VARS;
	id c = (RDCBitmap *)cursor;
	[v performSelectorOnMainThread:@selector(setCursor:) withObject:[c cursor] waitUntilDone:YES];
}

void ui_destroy_cursor(RDCursorRef cursor)
{
	id c = (RDCBitmap *)cursor;
	[c release];
}

void ui_move_pointer(rdcConnection conn, int x, int y)
{
	EXTRACT_USEFUL_VARS;
	//xxx: check if this conn is active
	
	NSPoint windowPoint = [v convertPoint:NSMakePoint(x,y) toView:nil];
	NSPoint windowOrigin = [[v window] frame].origin;
	
	NSLog(@"Setting point to remote (%d, %d), or local screen %@", x, y, NSStringFromPoint(NSMakePoint(windowPoint.x+windowOrigin.x, windowPoint.y+windowPoint.y)));
	CGWarpMouseCursorPosition(CGPointMake(windowPoint.x+windowOrigin.x, windowPoint.y+windowPoint.y));
	
	//NSLog(@"Should move mouse to %d, %d", x, y);
}


#pragma mark -
#pragma mark Non-UI
char *
next_arg(char *src, char needle)
{
	char *nextval;
	char *p;
	char *mvp = 0;

	/* EOS */
	if (*src == (char) 0x00)
		return 0;

	p = src;
	/*  skip escaped needles */
	while ((nextval = strchr(p, needle)))
	{
		mvp = nextval - 1;
		/* found backslashed needle */
		if (*mvp == '\\' && (mvp > src))
		{
			/* move string one to the left */
			while (*(mvp + 1) != (char) 0x00)
			{
				*mvp = *(mvp + 1);
				*mvp++;
			}
			*mvp = (char) 0x00;
			p = nextval;
		}
		else
		{
			p = nextval + 1;
			break;
		}
	}

	/* more args available */
	if (nextval)
	{
		*nextval = (char) 0x00;
		return ++nextval;
	}

	/* no more args after this, jump to EOS */
	nextval = src + strlen(src);
	return nextval;
}

void toupper_str(char *p)    
{
	while (*p)
	{
		if ((*p >= 'a') && (*p <= 'z'))
			*p = toupper((int) *p);
		p++;
	}
}

void * xmalloc(int size)
{
    void *mem = malloc(size);
    if (mem == NULL)
    {
        error("xmalloc %d\n", size);
		Debugger();
        exit(1);
    }
    return mem;
}

/* realloc; exit if out of memory */
void * xrealloc(void *oldmem, int size)
{
    void *mem;
	
    if (size < 1)
        size = 1;
	
    mem = realloc(oldmem, size);
    if (mem == NULL)
    {
        error("xrealloc %d\n", size);
		Debugger();
        exit(1);
    }
    return mem;
}

void xfree(void *mem)
{
    free(mem);
}

/* report an error */
void error(char *format, ...)
{
    va_list ap;
	
    fprintf(stderr, "ERROR: ");
	
    va_start(ap, format);
    vfprintf(stderr, format, ap);
    va_end(ap);
}

/* report a warning */
void warning(char *format, ...)
{
    va_list ap;
	
    fprintf(stderr, "WARNING: ");
	
    va_start(ap, format);
    vfprintf(stderr, format, ap);
    va_end(ap);
}

/* report an unimplemented protocol feature */
void unimpl(char *format, ...)
{
    va_list ap;
	
    fprintf(stderr, "NOT IMPLEMENTED: ");
	
    va_start(ap, format);
    vfprintf(stderr, format, ap);
    va_end(ap);
}

/* produce a hex dump */
void hexdump(unsigned char *p, unsigned int len)
{
    unsigned char *line = p;
    int i, thisline, offset = 0;
	
    while (offset < len)
    {
        printf("%04x ", offset);
        thisline = len - offset;
        if (thisline > 16)
            thisline = 16;
		
        for (i = 0; i < thisline; i++)
            printf("%02x ", line[i]);
		
        for (; i < 16; i++)
            printf("   ");
		
        for (i = 0; i < thisline; i++)
            printf("%c", (line[i] >= 0x20 && line[i] < 0x7f) ? line[i] : '.');
		
        printf("\n");
        offset += thisline;
        line += thisline;
    }
}

/* Generate a 32-byte random for the secure transport code. */
void generate_random(uint8 *randomValue)
{
    int fd, n;
    if ( (fd = open("/dev/urandom", O_RDONLY)) != -1)
    {
        n = read(fd, randomValue, 32);
        close(fd);
		return;
    }
}

/* Create the bitmap cache directory */
int rd_pstcache_mkdir(void)
{
    char *home;
    char bmpcache_dir[256];
	
    home = getenv("HOME");
	
    if (home == NULL)
        return False;
	
    sprintf(bmpcache_dir, "%s/%s", home, ".rdesktop");
	
    if ((mkdir(bmpcache_dir, S_IRWXU) == -1) && errno != EEXIST)
    {
        perror(bmpcache_dir);
        return False;
    }
	
    sprintf(bmpcache_dir, "%s/%s", home, ".rdesktop/cache");
	
    if ((mkdir(bmpcache_dir, S_IRWXU) == -1) && errno != EEXIST)
    {
        perror(bmpcache_dir);
        return False;
    }
	
    return True;
}

/* open a file in the .rdesktop directory */
int rd_open_file(char *filename)
{
    char *home;
    char fn[256];
    int fd;
	
    home = getenv("HOME");
    if (home == NULL)
        return -1;
    sprintf(fn, "%s/.rdesktop/%s", home, filename);
    fd = open(fn, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR);
    if (fd == -1)
        perror(fn);
    return fd;
}

/* close file */
void rd_close_file(int fd)
{
    close(fd);
}

/* read from file*/
int rd_read_file(int fd, void *ptr, int len)
{
    return read(fd, ptr, len);
}

/* write to file */
int rd_write_file(int fd, void *ptr, int len)
{
    return write(fd, ptr, len);
}

/* move file pointer */
int rd_lseek_file(int fd, int offset)
{
    return lseek(fd, offset, SEEK_SET);
}

/* do a write lock on a file */
int rd_lock_file(int fd, int start, int len)
{
    struct flock lock;
	
    lock.l_type = F_WRLCK;
    lock.l_whence = SEEK_SET;
    lock.l_start = start;
    lock.l_len = len;
    if (fcntl(fd, F_SETLK, &lock) == -1)
        return False;
    return True;
}

#define LTOA_BUFSIZE (sizeof(long) * 8 + 1)
char *l_to_a(long N, int base)
{
    char *ret;
    
	ret = malloc(LTOA_BUFSIZE);
	
    char *head = ret, buf[LTOA_BUFSIZE], *tail = buf + sizeof(buf);

    register int divrem;

    if (base < 36 || 2 > base)
        base = 10;

    if (N < 0)
    {
        *head++ = '-';
        N = -N;
    }

    tail = buf + sizeof(buf);
    *--tail = 0;

    do
    {
        divrem = N % base;
        *--tail = (divrem <= 9) ? divrem + '0' : divrem + 'a' - 10;
        N /= base;
    }
    while (N);

    strcpy(head, tail);
    return ret;
}

void save_licence(unsigned char *data, int length)
{
	UNIMPL;
}

int load_licence(unsigned char **data)
{
	UNIMPL;
	return 0;
}

#pragma mark Disk forwarding
int ui_select(rdcConnection conn)
{
	int n = 0;
	fd_set rfds, wfds;
	struct timeval tv;
	RDBOOL s_timeout = False;
	
	// If there are no pending IO requests, no need to check any files
	if (!conn->ioRequest)
		return 1;
	
	FD_ZERO(&rfds);
	FD_ZERO(&wfds);	

	rdpdr_add_fds(conn, &n, &rfds, &wfds, &tv, &s_timeout);
	
	struct timeval noTimeout;
	noTimeout.tv_sec = 0;
	noTimeout.tv_usec = 500; // one millisecond is 1000

	switch (select(n, &rfds, &wfds, NULL, &noTimeout))
	{
		case -1:
			error("select: %s\n", strerror(errno));
			break;
		case 0:
			rdpdr_check_fds(conn, &rfds, &wfds, 1);
			break;
		default:
			rdpdr_check_fds(conn, &rfds, &wfds, 0);
			break;
	}
	
	return 1;
}


#pragma mark Numlock

unsigned int read_keyboard_state()
{
	return 0;
}

unsigned short ui_get_numlock_state(unsigned int state)
{
	return 0;
}


#pragma mark -
#pragma mark Clipboard

void ui_clip_format_announce(rdcConnection conn, uint8 *data, uint32 length) 
{
	RDInstance *inst = (RDInstance *)conn->controller;
	[inst gotNewRemoteClipboardData];
}

void ui_clip_handle_data(rdcConnection conn, uint8 *data, uint32 length) 
{	
	RDInstance *inst = (RDInstance *)conn->controller;
	[inst setLocalClipboard:[NSData dataWithBytes:data length:length] format:conn->clipboardRequestType];
}

void ui_clip_request_data(rdcConnection conn, uint32 format) 
{	
	RDInstance *inst = (RDInstance *)conn->controller;
	 
	if ( (format == CF_UNICODETEXT) || (format == CF_TEXT) )
		[inst setRemoteClipboard:format];
}

void ui_clip_sync(rdcConnection conn) 
{
	RDInstance *inst = (RDInstance *)conn->controller;
	[inst informServerOfPasteboardType];
}

void ui_clip_request_failed(rdcConnection conn)
{

	
}

void ui_clip_set_mode(rdcConnection conn, const char *optarg)
{

}


