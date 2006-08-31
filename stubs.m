/*
 *  stubs.c
 *  Xrdc
 *
 *  Created by Craig Dooley on 5/10/06.
 *  Copyright 2006 __MyCompanyName__. All rights reserved.
 *
 */

#import <Cocoa/Cocoa.h>

#import <sys/types.h>
#import <sys/time.h>
#import <dirent.h>
#import <stdio.h>

#import "constants.h"
#import "parse.h"
#import "types.h"
#import "proto.h"

#import "RDCController.h"
#import "RDCView.h"
#import "RDCBitmap.h"

#import <openssl/md5.h>
#import <sys/stat.h>
#import <sys/types.h>
#import <sys/times.h>

#define UNIMPL NSLog(@"Unimplemented: %s", __func__)
#define CHECKOPCODE(x) if ((x != 0) && (x != 12) && (x != 6) && (x != 255)) {NSLog(@"Unimplemented opcode %d in function %s", x, __func__);}
	
int ui_select(int socket) {
	return 1;
}

/* Tells whether numlock is on or off */
unsigned int read_keyboard_state() {
	return 0;
}

unsigned short ui_get_numlock_state(unsigned int state) {
	return 0;
}

HCOLOURMAP ui_create_colourmap(COLOURMAP * colors) {
	NSMutableArray *array;
	NSColor *color;
	int i;
	
	array = [[NSMutableArray alloc] init];
	for (i = 0; i < colors->ncolours; i++) {
		COLOURENTRY centry = colors->colours[i];
		color = [NSColor colorWithDeviceRed:(centry.red / 255.0)
									  green:(centry.green / 255.0)
									   blue:(centry.blue / 255.0)
									  alpha:1.0];
		[array insertObject:color atIndex:i];
	}
	return array;
}

void ui_set_colourmap(rdcConnection conn, HCOLOURMAP map) {
	RDCView *v = conn->ui;
	[v setColorMap:(NSArray *)map];
}

HBITMAP ui_create_bitmap(rdcConnection conn, int width, int height, uint8 *data) {
	RDCBitmap *bitmap = [[RDCBitmap alloc] init];
	[bitmap bitmapWithData:data size:NSMakeSize(width, height) view:conn->ui];
	return bitmap;
}

void ui_rect(rdcConnection conn, int x, int y, int cx, int cy, int colour) {
	RDCView *v = conn->ui;
	NSRect r = NSMakeRect(x , y, cx, cy);
	[v setForeground:[v translateColor:colour]];
	[v fillRect:r];
	[v setNeedsDisplay:TRUE];
	
}

void ui_paint_bitmap(rdcConnection conn, int x, int y, int cx, int cy, int width, int height, uint8 * data) {
	RDCBitmap *bitmap = [[RDCBitmap alloc] init];
	[bitmap bitmapWithData:data size:NSMakeSize(width, height) view:conn->ui];
	ui_memblt(conn, 0, x, y, cx, cy, bitmap, 0, 0);
	[bitmap release];
}

void ui_memblt(rdcConnection conn, uint8 opcode, int x, int y, int cx, int cy, HBITMAP src, int srcx, int srcy) {
	RDCView *v = conn->ui;
	RDCBitmap *bmp = (RDCBitmap *)src;
	NSRect r = NSMakeRect(x, y, cx, cy);
	NSPoint p = NSMakePoint(srcx, srcy);
	
	CHECKOPCODE(opcode);
	[v memblt:r from:[bmp image] withOrigin:p];
	[v setNeedsDisplayInRect:r];
}

void ui_desktop_save(rdcConnection conn, uint32 offset, int x, int y, int cx, int cy) {
	RDCView *v = conn->ui;
	[v saveDesktop];
}

#pragma mark Text functions

HGLYPH ui_create_glyph(rdcConnection conn, int width, int height, const uint8 *data) {
	RDCBitmap *image = [[RDCBitmap alloc] init];
	[image glyphWithData:data size:NSMakeSize(width, height) view:conn->ui];
	
	return image;
}

void ui_destroy_glyph(HGLYPH glyph) {
	id image = glyph;
	[image release];
}

void ui_drawglyph(rdcConnection conn, int x, int y, int w, int h, RDCBitmap *glyph, int fgcolor, int bgcolor) {
	RDCView *v = conn->ui;
	NSRect r = NSMakeRect(x, y, w, h);
	[v drawGlyph:glyph at:r fg:fgcolor bg:bgcolor];
	[v setNeedsDisplayInRect:r];
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
	ui_drawglyph(conn, x1, y1, glyph->width, glyph->height, glyph->pixmap, fgcolour, bgcolour); \
    if (flags & TEXT2_IMPLICIT_X)\
      x += glyph->width;\
  }\
}

void ui_draw_text(rdcConnection conn, uint8 font, uint8 flags, uint8 opcode, int mixmode, int x, int y, int clipx, int clipy,
				  int clipcx, int clipcy, int boxx, int boxy, int boxcx, int boxcy, BRUSH * brush, int bgcolour,
				  int fgcolour, uint8 * text, uint8 length) {
	int i = 0, j;
	int xyoffset;
	int x1, y1;
	FONTGLYPH *glyph;
	DATABLOB *entry;
	RDCView *v = conn->ui;
	NSRect box;
	
	CHECKOPCODE(opcode);
	
	if (boxx + boxcx >= [v width]) {
		boxcx = [v width] - boxx;
	}
	
	[v setForeground:[v translateColor:bgcolour]];
	if (boxcx > 1) {
			box = NSMakeRect(boxx, boxy, boxcx, boxcy);
			[v fillRect:box];
			[v setNeedsDisplayInRect:box];
	} else if (mixmode == MIX_OPAQUE) {
			box = NSMakeRect(clipx, clipy, clipcx, clipcy);
			[v fillRect:box];
			[v setNeedsDisplayInRect:box];
	}
	
	[v setForeground:[v translateColor:fgcolour]];
	[v setBackground:[v translateColor:bgcolour]];
		
	/* Paint text, character by character */
    for (i = 0; i < length;) {                       
        switch (text[i]) {           
            case 0xff:  
                if (i + 2 < length) {
                    cache_put_text(conn, text[i + 1], text, text[i + 2]);
                } else {
                    error("this shouldn't be happening\n");
                    exit(1);
                }                /* this will move pointer from start to first character after FF command */            
				length -= i + 3;
                text = &(text[i + 3]);
                i = 0;
                break;
                
            case 0xfe:
                entry = cache_get_text(conn, text[i + 1]);
                if (entry != NULL) {
                    if ((((uint8 *) (entry->data))[1] == 0) && (!(flags & TEXT2_IMPLICIT_X))) {
                        if (flags & TEXT2_VERTICAL) {
                            y += text[i + 2];
                        } else {
                            x += text[i + 2]; 
						}
                    }
                    for (j = 0; j < entry->size; j++) {
                        DO_GLYPH(((uint8 *) (entry->data)), j);
					}
                } 
				
				if (i + 2 < length) {
					i += 3;
                } else {
                    i += 2;
				}
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
}

#pragma mark Clipping functions

void ui_set_clip(rdcConnection conn, int x, int y, int cx, int cy) {
	RDCView *v = conn->ui;
	[v setClip:NSMakeRect(x, y, cx, cy)];
}

void ui_reset_clip(rdcConnection conn) {
	RDCView *v = conn->ui;
	[v resetClip];
}

void ui_bell(void) {
	NSBeep();
}

#pragma mark Cursor functions


HCURSOR ui_create_cursor(rdcConnection conn, unsigned int x, unsigned int y, int width, int height, uint8 * andmask, uint8 * xormask) {
	RDCBitmap *cursor = [[RDCBitmap alloc] init];
	[cursor cursorWithData:andmask 
					 alpha:xormask 
					  size:NSMakeSize(width, height) 
				   hotspot:NSMakePoint(x, y) 
					  view:conn->ui];
	return cursor;
}

void ui_set_null_cursor(void) {
	UNIMPL;
}

void ui_set_cursor(HCURSOR cursor) {
	id c = (RDCBitmap *)cursor;
	[[c cursor] set];
}

void ui_destroy_cursor(HCURSOR cursor) {
	id c = (RDCBitmap *)cursor;
	[c release];
}



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

void ui_desktop_restore(rdcConnection conn, uint32 offset, int x, int y, int cx, int cy) {
	RDCView *v = conn->ui;
	[v restoreDesktop:NSMakeRect(x, y, cx, cy)];
	[v setNeedsDisplayInRect:NSMakeRect(x, y, cx, cy)];
}


void ui_screenblt(rdcConnection conn, uint8 opcode, int x, int y, int cx, int cy, int srcx, int srcy) {
	RDCView *v = conn->ui;
	NSRect src = NSMakeRect(srcx, srcy, cx, cy);
	NSPoint dest = NSMakePoint(x, y);
	
	CHECKOPCODE(opcode);
	[v screenBlit:src to:dest];
	[v setNeedsDisplayInRect:NSMakeRect(x, y, cx, cy)];
}

void ui_destroy_bitmap(HBITMAP bmp) {
	id image = bmp;
	[image release];
}

void ui_line(rdcConnection conn, uint8 opcode, int startx, int starty, 
						   int endx, int endy, PEN * pen) {
	RDCView *v = conn->ui;
	NSPoint start = NSMakePoint(startx + 0.5, starty + 0.5);
	NSPoint end = NSMakePoint(endx + 0.5, endy + 0.5);
	
	CHECKOPCODE(opcode);
	/* XXX better rectangle finding for setneedsdisplay */
	[v setForeground:[v translateColor:pen->colour]];
	[v drawLineFrom:start to:end color:[v translateColor:pen->colour] width:pen->width];
	[v setNeedsDisplay:YES];

}

void ui_destblt(rdcConnection conn, uint8 opcode, int x, int y, int cx, int cy) {
	RDCView *v = conn->ui;
	NSRect r = NSMakeRect(x, y, cx, cy);
	/* XXX */
	if (opcode == 5) {
		[v swapRect:r];
		[v setNeedsDisplayInRect:r];
		return;
	}
	
	CHECKOPCODE(opcode);
	
	[v fillRect:r];
	[v setNeedsDisplayInRect:r];
}

void ui_polyline(rdcConnection conn, uint8 opcode, POINT * points, int npoints, PEN *pen) {
	RDCView *v = conn->ui;
	CHECKOPCODE(opcode);
	[v polyline:points npoints:npoints color:[v translateColor:pen->colour] width:pen->width];
	[v setNeedsDisplay:YES];
}

void ui_polygon(rdcConnection conn, uint8 opcode, uint8 fillmode, POINT * point, int npoints, BRUSH *brush, int bgcolour, int fgcolour) {
	RDCView *v = conn->ui;
	NSWindingRule r;
	int style;
	CHECKOPCODE(opcode);
	
	switch (fillmode) {
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
	
	if (brush) {
		style = brush->style;
	} else {
		style = 0;
	}
	
	switch(style) {
		case 0:
			[v polygon:point npoints:npoints color:[v translateColor:fgcolour]  winding:r];
			break;
		default:
			UNIMPL;
			break;
	}
	
	[v setNeedsDisplay:YES];
}

void ui_move_pointer(int x, int y) {
	UNIMPL;
}

static const uint8 hatch_patterns[] = {
    0x00, 0x00, 0x00, 0xff, 0x00, 0x00, 0x00, 0x00, /* 0 - bsHorizontal */
    0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, /* 1 - bsVertical */
    0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01, /* 2 - bsFDiagonal */
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, /* 3 - bsBDiagonal */
    0x08, 0x08, 0x08, 0xff, 0x08, 0x08, 0x08, 0x08, /* 4 - bsCross */
    0x81, 0x42, 0x24, 0x18, 0x18, 0x24, 0x42, 0x81  /* 5 - bsDiagCross */
};

/* XXX Still needs origins */
void ui_patblt(rdcConnection conn, uint8 opcode, int x, int y, int cx, int cy, BRUSH * brush, int bgcolor, int fgcolor) {
	RDCView *v = conn->ui;
	NSRect dest = NSMakeRect(x, y, cx, cy);
	NSRect glyphSize;
	RDCBitmap *bitmap;
	NSImage *fill;
	NSColor *fillColor;
	uint8 i, ipattern[8];
	
	CHECKOPCODE(opcode);
	if(opcode == 6) {
		[v swapRect:dest];
		[v setNeedsDisplayInRect:dest];
		return;
	}
	
	switch (brush->style) {
		case 0: /* Solid */
			NSLog(@"fg %d bg %d opcode %d", fgcolor, bgcolor, opcode);
			[v fillRect:dest withColor:[v translateColor:fgcolor]];
			break;
		case 2: /* Hatch */

			glyphSize = NSMakeRect(0, 0, 8, 8);
            bitmap = ui_create_glyph(conn, 8, 8, hatch_patterns + brush->pattern[0] * 8);
			fill = [bitmap image];
			[fill lockFocus];
			
			[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeSourceAtop];
			[[v translateColor:fgcolor] set];
			[NSBezierPath fillRect:glyphSize];
			
			[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeDestinationAtop];
			[[v translateColor:bgcolor] set];
			[NSBezierPath fillRect:glyphSize];
			
			[fill unlockFocus];
			
			fillColor = [NSColor colorWithPatternImage:fill];
			[v fillRect:dest withColor:fillColor patternOrigin:NSMakePoint(brush->xorigin, brush->yorigin)];
            ui_destroy_glyph(bitmap);
            break;
		case 3: /* Pattern */
			for (i = 0; i != 8; i++) {
				ipattern[7 - i] = brush->pattern[i];
			}
			
			glyphSize = NSMakeRect(0, 0, 8, 8);
            bitmap = ui_create_glyph(conn, 8, 8, ipattern);
			fill = [bitmap image];
			[fill lockFocus];
			
			[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeSourceAtop];
			[[v translateColor:fgcolor] set];
			[NSBezierPath fillRect:glyphSize];
			
			[[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeDestinationAtop];
			[[v translateColor:bgcolor] set];
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
	[v setNeedsDisplayInRect:dest];
}


void *
xmalloc(int size)
{
    void *mem = malloc(size);
    if (mem == NULL)
    {
        error("xmalloc %d\n", size);
        exit(1);
    }
    return mem;
}

/* realloc; exit if out of memory */
void *
xrealloc(void *oldmem, int size)
{
    void *mem;
	
    if (size < 1)
        size = 1;
    mem = realloc(oldmem, size);
    if (mem == NULL)
    {
        error("xrealloc %d\n", size);
        exit(1);
    }
    return mem;
}

/* free */
void
xfree(void *mem)
{
    free(mem);
}

/* report an error */
void
error(char *format, ...)
{
    va_list ap;
	
    fprintf(stderr, "ERROR: ");
	
    va_start(ap, format);
    vfprintf(stderr, format, ap);
    va_end(ap);
}

/* report a warning */
void
warning(char *format, ...)
{
    va_list ap;
	
    fprintf(stderr, "WARNING: ");
	
    va_start(ap, format);
    vfprintf(stderr, format, ap);
    va_end(ap);
}

/* report an unimplemented protocol feature */
void
unimpl(char *format, ...)
{
    va_list ap;
	
    fprintf(stderr, "NOT IMPLEMENTED: ");
	
    va_start(ap, format);
    vfprintf(stderr, format, ap);
    va_end(ap);
}

/* produce a hex dump */
void
hexdump(unsigned char *p, unsigned int len)
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
void
generate_random(uint8 * random)
{
    struct stat st;    struct tms tmsbuf;
    MD5_CTX md5;
    uint32 *r;
    int fd, n;
	
    /* If we have a kernel random device, try that first */
    if (((fd = open("/dev/urandom", O_RDONLY)) != -1)
        || ((fd = open("/dev/random", O_RDONLY)) != -1))
    {
        n = read(fd, random, 32);
        close(fd);
        if (n == 32)
            return;
    }
	
#ifdef EGD_SOCKET
    /* As a second preference use an EGD */
    if (generate_random_egd(random))
        return;
#endif
	
    /* Otherwise use whatever entropy we can gather - ideas welcome. */
    r = (uint32 *) random;
    r[0] = (getpid()) | (getppid() << 16);
    r[1] = (getuid()) | (getgid() << 16);
    r[2] = times(&tmsbuf);  /* system uptime (clocks) */
    gettimeofday((struct timeval *) &r[3], NULL);   /* sec and usec */
    stat("/tmp", &st);
    r[5] = st.st_atime;
    r[6] = st.st_mtime;
    r[7] = st.st_ctime;
	
    /* Hash both halves with MD5 to obscure possible patterns */
    MD5_Init(&md5);
    MD5_Update(&md5, random, 16);
    MD5_Final(random, &md5);
    MD5_Update(&md5, random + 16, 16);
    MD5_Final(random + 16, &md5);
}

/* Create the bitmap cache directory */
int
rd_pstcache_mkdir(void)
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
int 
rd_open_file(char *filename)
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
void
rd_close_file(int fd)
{
    close(fd);
}

/* read from file*/
int
rd_read_file(int fd, void *ptr, int len)
{
    return read(fd, ptr, len);
}

/* write to file */
int
rd_write_file(int fd, void *ptr, int len)
{
    return write(fd, ptr, len);
}

/* move file pointer */
int
rd_lseek_file(int fd, int offset)
{
    return lseek(fd, offset, SEEK_SET);
}

/* do a write lock on a file */
int
rd_lock_file(int fd, int start, int len)
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

void fillDefaultConnection(rdcConnection conn) {
	NSString *host = [[NSProcessInfo processInfo] hostName];
	
	conn->tcpPort		= TCP_PORT_RDP;
	conn->screenWidth	= 1024;
	conn->screenHeight	= 768;
	conn->isConnected	= 0;
	conn->useEncryption	= 1;
	conn->useBitmapCompression	= 1;
	conn->useRdp5		= 1;
	conn->serverBpp		= 16;
	conn->consoleSession	= 0;
	conn->bitmapCache	= 1;
	conn->bitmapCachePersist	= 0;
	conn->bitmapCachePrecache	= 1;
	conn->polygonEllipseOrders	= 1;
	conn->desktopSave	= 1;
	conn->serverRdpVersion	= 1;
	conn->keyLayout		= 0x409;
	conn->packetNumber	= 0;
	conn->licenseIssued	= 0;
	conn->pstcacheEnumerated	= 0;
	conn->rdpdrClientname	= NULL;
	conn->ioRequest	= NULL;
	conn->bmpcacheLru[0] = conn->bmpcacheLru[1] = conn->bmpcacheLru[2] = NOT_SET;
	conn->bmpcacheMru[0] = conn->bmpcacheMru[1] = conn->bmpcacheMru[2] = NOT_SET;
	memcpy(conn->hostname, [host UTF8String], [host length] + 1);
	conn->rdp5PerformanceFlags	= RDP5_NO_WALLPAPER | RDP5_NO_FULLWINDOWDRAG | RDP5_NO_MENUANIMATIONS;
}


void ui_resize_window(void) {
	UNIMPL;
}

#define LTOA_BUFSIZE (sizeof(long) * 8 + 1)
char *
l_to_a(long N, int base)
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

void ui_triblt(uint8 opcode, 
			   int x, int y, int cx, int cy,
			   HBITMAP src, int srcx, int srcy,
			   BRUSH *brush, int bgcolour, int fgcolour) {
	CHECKOPCODE(opcode);
	UNIMPL;
}

void ui_ellipse(uint8 opcode,
				uint8 fillmode,
				int x, int y, int cx, int cy,
				BRUSH *brush, int bgcolour, int fgcolour) {
	CHECKOPCODE(opcode);
	UNIMPL;
}

void save_licence(unsigned char *data, int length) {
	UNIMPL;
}

int load_licence(unsigned char **data) {
	UNIMPL;
	return 0;
}

void ui_clip_format_announce(uint8 *data, uint32 length) {
	UNIMPL;
}

void ui_clip_handle_data(uint8 *data, uint32 length) {
	UNIMPL;
}

void ui_clip_request_data(uint32 format) {
	UNIMPL;
}

void ui_clip_sync(void) {
	UNIMPL;
}