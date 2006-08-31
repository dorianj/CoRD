/*
   rdesktop: A Remote Desktop Protocol client.
   Common data types
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

#ifndef __ORDERS_H__
#define __ORDERS_H__

typedef int RDCRDCBOOL;
#ifndef True
#define True  (1)
#define False (0)
#endif

typedef unsigned char uint8;
typedef signed char sint8;
typedef unsigned short uint16;
typedef signed short sint16;
typedef unsigned int uint32;
typedef signed int sint32;

typedef void *HBITMAP;
typedef void *HGLYPH;
typedef void *HCOLOURMAP;
typedef void *HCURSOR;

typedef struct _POINT
{
	sint16 x, y;
}
POINT;

typedef struct _COLOURENTRY
{
	uint8 red;
	uint8 green;
	uint8 blue;

}
COLOURENTRY;

typedef struct _COLOURMAP
{
	uint16 ncolours;
	COLOURENTRY *colours;

}
COLOURMAP;

typedef struct _BOUNDS
{
	sint16 left;
	sint16 top;
	sint16 right;
	sint16 bottom;

}
BOUNDS;

typedef struct _PEN
{
	uint8 style;
	uint8 width;
	uint32 colour;

}
PEN;

typedef struct _BRUSH
{
	uint8 xorigin;
	uint8 yorigin;
	uint8 style;
	uint8 pattern[8];

}
BRUSH;

typedef struct _FONTGLYPH
{
	sint16 offset;
	sint16 baseline;
	uint16 width;
	uint16 height;
	HBITMAP pixmap;

}
FONTGLYPH;

typedef struct _DATABLOB
{
	void *data;
	int size;

}
DATABLOB;

typedef struct _key_translation
{
	uint8 scancode;
	uint16 modifiers;
}
key_translation;

typedef struct rdcConn * rdcConnection;

typedef struct _VCHANNEL
{
	uint16 mcs_id;
	char name[8];
	uint32 flags;
	struct stream in;
	void (*process) (rdcConnection, STREAM);
}
VCHANNEL;

typedef struct _RDPCOMP
{
	uint32 roff;
	uint8 hist[RDP_MPPC_DICT_SIZE];
	struct stream ns;
}
RDPCOMP;

/* RDPDR */
typedef uint32 NTSTATUS;
typedef uint32 NTHANDLE;

/* PSTCACHE */
typedef uint8 HASH_KEY[8];

/* Header for an entry in the persistent bitmap cache file */
typedef struct _PSTCACHE_CELLHEADER
{
	HASH_KEY key;
	uint8 width, height;
	uint16 length;
	uint32 stamp;
}
CELLHEADER;

#define MAX_CBSIZE 256

/* RDPSND */
typedef struct
{
	uint16 wFormatTag;
	uint16 nChannels;
	uint32 nSamplesPerSec;
	uint32 nAvgBytesPerSec;
	uint16 nBlockAlign;
	uint16 wBitsPerSample;
	uint16 cbSize;
	uint8 cb[MAX_CBSIZE];
} WAVEFORMATEX;

typedef struct rdpdr_device_info
{
	uint32 device_type;
	NTHANDLE handle;
	char name[8];
	char *local_path;
	void *pdevice_data;
}
RDPDR_DEVICE;

typedef struct rdpdr_serial_device_info
{
	int dtr;
	int rts;
	uint32 control, xonoff, onlimit, offlimit;
	uint32 baud_rate,
		queue_in_size,
		queue_out_size,
		wait_mask,
		read_interval_timeout,
		read_total_timeout_multiplier,
		read_total_timeout_constant,
		write_total_timeout_multiplier, write_total_timeout_constant, posix_wait_mask;
	uint8 stop_bits, parity, word_length;
	uint8 chars[6];
	struct termios *ptermios, *pold_termios;
	int event_txempty, event_cts, event_dsr, event_rlsd, event_pending;
}
SERIAL_DEVICE;

typedef struct rdpdr_parallel_device_info
{
	char *driver, *printer;
	uint32 queue_in_size,
		queue_out_size,
		wait_mask,
		read_interval_timeout,
		read_total_timeout_multiplier,
		read_total_timeout_constant,
		write_total_timeout_multiplier,
		write_total_timeout_constant, posix_wait_mask, bloblen;
	uint8 *blob;
}
PARALLEL_DEVICE;

typedef struct rdpdr_printer_info
{
	FILE *printer_fp;
	char *driver, *printer;
	uint32 bloblen;
	uint8 *blob;
	RDCRDCBOOL default_printer;
}
PRINTER;

typedef struct notify_data
{
	time_t modify_time;
	time_t status_time;
	time_t total_time;
	unsigned int num_entries;
}
NOTIFY;

typedef struct fileinfo
{
	uint32 device_id, flags_and_attributes, accessmask;
	char path[256];
	DIR *pdir;
	struct dirent *pdirent;
	char pattern[64];
	RDCRDCBOOL delete_on_close;
	NOTIFY notify;
	uint32 info_class;
}
FILEINFO;

typedef struct _DEVICE_FNS DEVICE_FNS;

/* Used to store incoming io request, until they are ready to be completed */
/* using a linked list ensures that they are processed in the right order, */
/* if multiple ios are being done on the same fd */
struct async_iorequest
{
	uint32 fd, major, minor, offset, device, id, length, partial_len;
	long timeout,		/* Total timeout */
		itv_timeout;		/* Interval timeout (between serial characters) */
	uint8 *buffer;
	DEVICE_FNS *fns;
	
	struct async_iorequest *next;	/* next element in list */
};

#include "orders.h"

struct bmpcache_entry
{
	HBITMAP bitmap;
	sint16 previous;
	sint16 next;
};



#include <openssl/md5.h>
#include <openssl/sha.h>
#include <openssl/bn.h>
#include <openssl/x509v3.h>

#include <openssl/rc4.h>

#define NBITMAPCACHE 3
#define NBITMAPCACHEENTRIES 0xa00
#define NOT_SET -1
struct rdcConn {
	// State flags
	int isConnected;
	int useRdp5;
	int useEncryption;
	int useBitmapCompression;
	int rdp5PerformanceFlags;
	int consoleSession;
	int bitmapCache;
	int bitmapCachePersist;
	int bitmapCachePrecache;
	int desktopSave;
	int polygonEllipseOrders;
	int licenseIssued;
	int notifyStamp;
	int pstcacheEnumerated;
	
	// Variables
	int tcpPort;
	int screenWidth;
	int screenHeight;
	int serverBpp;
	int shareID;
	int keyLayout;
	int serverRdpVersion;
	int packetNumber;
	int pstcacheBpp;
	int pstcacheFd[8];
	int bmpcacheCount[3];
	unsigned char licenseKey[16];
	unsigned char licenseSignKey[16];
	unsigned short mcsUserid;
	unsigned int numChannels;
	unsigned int numDevices;
	unsigned char deskCache[0x38400 * 4];
	char username[64];
	char hostname[64];
	char *rdpdrClientname;
	RDPCOMP mppcDict;
	NTHANDLE minTimeoutFd;
	FILEINFO fileInfo[0x100];	// MAX_OPEN_FILES taken from disk.h
	RDPDR_DEVICE rdpdrDevice[0x10]; //RDPDR_MAX_DEVICES taken from constants.h
	RDP_ORDER_STATE orderState;
	VCHANNEL channels[4];
	VCHANNEL *rdpdrChannel;
	VCHANNEL *cliprdrChannel;
	HBITMAP volatileBc[3];
	HCURSOR cursorCache[0x20];
	DATABLOB textCache[256];
	FONTGLYPH fontCache[12][256];
	struct async_iorequest *ioRequest;
	struct bmpcache_entry bmpcache[NBITMAPCACHE][NBITMAPCACHEENTRIES];
	
	int bmpcacheLru[3];
	int bmpcacheMru[3];
	
	// Network
	unsigned char *nextPacket;
	void *inputStream;
	void *outputStream;
	void *host;
	struct stream in, out;
	STREAM rdpStream;
	
	// Secure
	int rc4KeyLen;
	RC4_KEY rc4DecryptKey;
	RC4_KEY rc4EncryptKey;
	RSA *serverPublicKey;
	uint8 secSignKey[16];
	uint8 secDecryptKey[16];
	uint8 secEncryptKey[16];
	uint8 secDecryptUpdateKey[16];
	uint8 secEncryptUpdateKey[16];
	uint8 secCryptedRandom[SEC_MODULUS_SIZE];
	
	// UI
	void *ui;
};



struct _DEVICE_FNS
{
	NTSTATUS(*create) (rdcConnection conn, uint32 device, uint32 desired_access, uint32 share_mode,
					   uint32 create_disposition, uint32 flags_and_attributes, char *filename,
					   NTHANDLE * handle);
	NTSTATUS(*close) (rdcConnection conn, NTHANDLE handle);
	NTSTATUS(*read) (rdcConnection conn, NTHANDLE handle, uint8 * data, uint32 length, uint32 offset,
					 uint32 * result);
	NTSTATUS(*write) (rdcConnection conn, NTHANDLE handle, uint8 * data, uint32 length, uint32 offset,
					  uint32 * result);
	NTSTATUS(*device_control) (rdcConnection conn, NTHANDLE handle, uint32 request, STREAM in, STREAM out);
};

#endif