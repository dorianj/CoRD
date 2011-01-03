/*	Copyright (c) 2007-2011 Dorian Johnson <2011@dorianj.net>
	
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

// Replaces: rdesktop.c

#import "rdesktop.h"

#include <string.h>
#include <sys/uio.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <ctype.h>
#include <sys/types.h>
#include <stdarg.h>
#include <sys/stat.h>
#include <stdlib.h>

char * next_arg(char *src, char needle)
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

}

int load_licence(unsigned char **data)
{
	return 0;
}

unsigned int read_keyboard_state()
{
	return 0;
}

unsigned short ui_get_numlock_state(unsigned int state)
{
	return KBD_FLAG_NUMLOCK;
}


