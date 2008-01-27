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
#import <sys/select.h>
#import <unistd.h>
#include <limits.h>		/* PATH_MAX */

#import <openssl/md5.h>
#import <openssl/sha.h>
#import <openssl/bn.h>
#import <openssl/x509v3.h>
#import <openssl/rc4.h>

#define VERSION "1.5.0"

//#define WITH_DEBUG 1
#ifdef WITH_DEBUG
	#define DEBUG(args)	printf args;
#else
	#define DEBUG(args)
#endif

//#define WITH_DEBUG_RDP5 1
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

//#define WITH_DEBUG_CHANNEL
#ifdef WITH_DEBUG_CHANNEL
	#define DEBUG_CHANNEL(args) printf args;
#else
	#define DEBUG_CHANNEL(args)
#endif

#define STRNCPY(dst,src,n)	{ strncpy(dst,src,n-1); dst[n-1] = 0; }

#ifndef MIN
	#define MIN(x,y)		(((x) < (y)) ? (x) : (y))
#endif

#ifndef MAX
	#define MAX(x,y)		(((x) > (y)) ? (x) : (y))
#endif

/* timeval macros */
#ifndef timerisset
	#define timerisset(tvp)\
         ((tvp)->tv_sec || (tvp)->tv_usec)
#endif
#ifndef timercmp
	#define timercmp(tvp, uvp, cmp)\
			((tvp)->tv_sec cmp (uvp)->tv_sec ||\
			(tvp)->tv_sec == (uvp)->tv_sec &&\
			(tvp)->tv_usec cmp (uvp)->tv_usec)
#endif
#ifndef timerclear
	#define timerclear(tvp)\
			((tvp)->tv_sec = (tvp)->tv_usec = 0)
#endif

#ifdef __LITTLE_ENDIAN__
	#define L_ENDIAN
#elif defined(__BIG_ENDIAN__)
	#define B_ENDIAN
#endif


#ifndef __i386__
	#define NEED_ALIGN
#endif

#import "constants.h"
#import "parse.h"
#import "types.h"
#import "proto.h"

