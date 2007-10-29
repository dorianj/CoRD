/*
   rdesktop: A Remote Desktop Protocol client.
   Master include file
   Copyright (C) Matthew Chapman 1999-2005
   
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <stdlib.h>
#import <stdio.h>
#import <string.h>
#import <dirent.h>
#import <sys/time.h>
#import <dirent.h>
#ifdef HAVE_SYS_SELECT_H
#import <sys/select.h>
#else
#import <sys/types.h>
#import <unistd.h>
#endif

#define VERSION "1.4.1"

#ifdef WITH_DEBUG
#define DEBUG(args)	printf args;
#else
#define DEBUG(args)
#endif

#ifdef WITH_DEBUG_RDP5
#define DEBUG_RDP5(args) printf args;
#else
#define DEBUG_RDP5(args)
#endif

//#define WITH_DEBUG_CLIPBOARD
#ifdef WITH_DEBUG_CLIPBOARD
#define DEBUG_CLIPBOARD(args) printf args;
#else
#define DEBUG_CLIPBOARD(args)
#endif

#define STRNCPY(dst,src,n)	{ strncpy(dst,src,n-1); dst[n-1] = 0; }

#ifndef MIN
#define MIN(x,y)		(((x) < (y)) ? (x) : (y))
#endif

#ifndef MAX
#define MAX(x,y)		(((x) > (y)) ? (x) : (y))
#endif

/* If configure does not define the endianess, try
   to find it out */
#if !defined(L_ENDIAN) && !defined(B_ENDIAN)
#if __BYTE_ORDER == __LITTLE_ENDIAN
#define L_ENDIAN
#elif __BYTE_ORDER == __BIG_ENDIAN
#define B_ENDIAN
#else
#error Unknown endianness. Edit rdesktop.h.
#endif
#endif /* B_ENDIAN, L_ENDIAN from configure */

/* No need for alignment on x86 and amd64 */
#if !defined(NEED_ALIGN)
#if !(defined(__x86__) || defined(__x86_64__) || \
      defined(__AMD64__) || defined(_M_IX86) || \
      defined(__i386__))
#define NEED_ALIGN
#endif
#endif

#import "parse.h"
#import "constants.h"
#import "types.h"
#import "proto.h"

