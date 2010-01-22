/* -*- c-basic-offset: 8 -*-
   rdesktop: A Remote Desktop Protocol client.
   Protocol services - RDP layer
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

#import <time.h>
#import <errno.h>
#import <unistd.h>
#import "rdesktop.h"

#import "CRDSessionView.h"
#import "CRDShared.h"

#ifdef HAVE_ICONV
#ifdef HAVE_ICONV_H
#import <iconv.h>
#endif

#ifndef ICONV_CONST
#define ICONV_CONST ""
#endif
#endif

/* Receive an RDP packet */
RDStreamRef
rdp_recv(RDConnectionRef conn, uint8 * type)
{
	RDStreamRef rdp_s = conn->rdpStream;
	uint16 length, pdu_type;
	uint8 rdpver;

	if ((rdp_s == NULL) || (conn->nextPacket >= rdp_s->end) || (conn->nextPacket == NULL))
	{
		rdp_s = sec_recv(conn, &rdpver);
		if (rdp_s == NULL)
			return NULL;
		if (rdpver == 0xff)
		{
			conn->nextPacket = rdp_s->end;
			*type = 0;
			return rdp_s;
		}
		else if (rdpver != 3)
		{
			/* rdp5_process should move conn->nextPacket ok */
			rdp5_process(conn, rdp_s);
			*type = 0;
			return rdp_s;
		}

		conn->nextPacket = rdp_s->p;
	}
	else
	{
		rdp_s->p = conn->nextPacket;
	}

	in_uint16_le(rdp_s, length);
	/* 32k packets are really 8, keepalive fix */
	if (length == 0x8000)
	{
		conn->nextPacket += 8;
		*type = 0;
		return rdp_s;
	}
	in_uint16_le(rdp_s, pdu_type);
	in_uint8s(rdp_s, 2);	/* userid */
	*type = pdu_type & 0xf;

	conn->nextPacket += length;
	return rdp_s;
}

/* Initialise an RDP data packet */
static RDStreamRef
rdp_init_data(RDConnectionRef conn, int maxlen)
{
	RDStreamRef s;

	s = sec_init(conn, conn->useEncryption ? SEC_ENCRYPT : 0, maxlen + 18);
	s_push_layer(s, rdp_hdr, 18);

	return s;
}

/* Send an RDP data packet */
static void
rdp_send_data(RDConnectionRef conn, RDStreamRef s, uint8 data_pdu_type)
{
	uint16 length;

	s_pop_layer(s, rdp_hdr);
	length = s->end - s->p;

	out_uint16_le(s, length);
	out_uint16_le(s, (RDP_PDU_DATA | 0x10));
	out_uint16_le(s, (conn->mcsUserid + 1001));

	out_uint32_le(s, conn->shareID);
	out_uint8(s, 0);	/* pad */
	out_uint8(s, 1);	/* streamid */
	out_uint16_le(s, (length - 14));
	out_uint8(s, data_pdu_type);
	out_uint8(s, 0);	/* compress_type */
	out_uint16(s, 0);	/* compress_len */

	sec_send(conn, s, conn->useEncryption ? SEC_ENCRYPT : 0);
}

/* Output a string in Unicode */
void
rdp_out_unistr(RDStreamRef s, const char *string, int len)
{
	{
		int i = 0, j = 0;

		len += 2;

		while (i < len)
		{
			uint16_t word;
			uint16_t first;

			/* calculate UTF-8 to UTF-16 */
			first = (uint16_t)string[j++];
			if ((first & 0x80) == 0)
				word = first;
			else if ((first & 0xe0) == 0xc0)
				word = ((first & 0x1f) << 6) | ((uint16_t)string[j++] & 0x3f);
			else if ((first & 0xf0) == 0xe0)
			{
				uint16_t second = ((uint16_t)string[j++] & 0x3f) << 6;
				uint16_t third = (uint16_t)string[j++] & 0x3f;
				word = ((first & 0x0f) << 12) | second | third;
			}

			/* store as UTF-16LE */
			out_uint16_le(s, word);
			i += 2;
		}
	}
}

/* Input a string in Unicode
 *
 * Returns str_len of string
 */
int
rdp_in_unistr(RDStreamRef s, char *string, int uni_len)
{
	{
		int i = 0;

		while (i < uni_len / 2)
		{
			in_uint8a(s, &string[i++], 1);
			in_uint8s(s, 1);
		}

		return i - 1;
	}
}


/* Parse a logon info packet */
static void
rdp_send_logon_info(RDConnectionRef conn, uint32 flags, NSString *nsdomain, NSString *nsuser,
		    NSString *nspassword, const char *program, const char *directory)
{
	char *ipaddr = tcp_get_address(conn);
	int len_program = 2 * strlen(program);
	/* We now pass in strings as NSString instead of ASCII */
	const char *domain = (const char *)CRDMakeUTF16LEString(nsdomain);
	const char *user = (const char *)CRDMakeUTF16LEString(nsuser);
	const char *password = (const char *)CRDMakeUTF16LEString(nspassword);
	int len_domain = CRDGetUTF16LEStringLength(nsdomain);
	int len_user = CRDGetUTF16LEStringLength(nsuser);
	int len_password = CRDGetUTF16LEStringLength(nspassword);
	int len_directory = 2 * strlen(directory);
	int len_ip = 2 * strlen(ipaddr);
	int len_dll = 2 * strlen("C:\\WINNT\\System32\\mstscax.dll");
	int packetlen = 0;
	uint32 sec_flags = conn->useEncryption ? (SEC_LOGON_INFO | SEC_ENCRYPT) : SEC_LOGON_INFO;
	RDStreamRef s;
	time_t t = time(NULL);
	time_t tzone;

	if (!conn->useRdp5 || 1 == conn->serverRdpVersion)
	{
		DEBUG_RDP5(("Sending RDP4-style Logon packet\n"));

		s = sec_init(conn, sec_flags, 18 + len_domain + len_user + len_password
			     + len_program + len_directory + 10);

		out_uint32(s, 0);
		out_uint32_le(s, flags);
		out_uint16_le(s, len_domain);
		out_uint16_le(s, len_user);
		out_uint16_le(s, len_password);
		out_uint16_le(s, len_program);
		out_uint16_le(s, len_directory);
		out_uint8p(s, domain, len_domain);
		out_uint16_le(s,0);
		out_uint8p(s, user, len_user);
		out_uint16_le(s,0);
		out_uint8p(s, password, len_password);
		out_uint16_le(s,0);
		rdp_out_unistr(s, program, len_program);
		rdp_out_unistr(s, directory, len_directory);
	}
	else
	{

		flags |= RDP_LOGON_BLOB;
		DEBUG_RDP5(("Sending RDP5-style Logon packet\n"));
		packetlen = 4 +	/* codepage uint32 */
			4 +	/* flags */
			2 +	/* len_domain */
			2 +	/* len_user */
			(flags & RDP_LOGON_AUTO ? 2 : 0) +	/* len_password */
			(flags & RDP_LOGON_BLOB ? 2 : 0) +	/* Length of BLOB */
			2 +	/* len_program */
			2 +	/* len_directory */
			(0 < len_domain ? len_domain : 2) +	/* domain */
			len_user + (flags & RDP_LOGON_AUTO ? len_password : 0) + 0 +	/* We have no 512 byte BLOB. Perhaps we must? */
			(flags & RDP_LOGON_BLOB && !(flags & RDP_LOGON_AUTO) ? 2 : 0) +	/* After the BLOB is a unknown int16. If there is a BLOB, that is. */
			(0 < len_program ? len_program : 2) + (0 < len_directory ? len_directory : 2) + 2 +	/* Unknown (2) */
			2 +	/* Client ip length */
			len_ip +	/* Client ip */
			2 +	/* DLL string length */
			len_dll +	/* DLL string */
			2 +	/* Unknown */
			2 +	/* Unknown */
			64 +	/* Time zone #0 */
			2 +	/* Unknown */
			64 +	/* Time zone #1 */
			32;	/* Unknown */

		s = sec_init(conn, sec_flags, packetlen);
		DEBUG_RDP5(("Called sec_init with packetlen %d\n", packetlen));

		out_uint32(s, 0);	/* codepage uint32, TODO: for unicode set to windows input locale in low word */
		out_uint32_le(s, flags);
		out_uint16_le(s, len_domain);
		out_uint16_le(s, len_user);
		if (flags & RDP_LOGON_AUTO)
		{
			out_uint16_le(s, len_password);

		}
		if (flags & RDP_LOGON_BLOB && !(flags & RDP_LOGON_AUTO))
		{
			out_uint16_le(s, 0);
		}
		out_uint16_le(s, len_program);
		out_uint16_le(s, len_directory);
		if (0 < len_domain)
			out_uint8a(s, domain, len_domain);
		out_uint16_le(s, 0);
		out_uint8p(s, user, len_user);
		out_uint16_le(s,0);
		if (flags & RDP_LOGON_AUTO)
		{
			out_uint8a(s, password, len_password);
			out_uint16_le(s,0);
		}
		if (flags & RDP_LOGON_BLOB && !(flags & RDP_LOGON_AUTO))
		{
			out_uint16_le(s, 0);
		}
		if (0 < len_program)
		{
			rdp_out_unistr(s, program, len_program);

		}
		else
		{
			out_uint16_le(s, 0);
		}
		if (0 < len_directory)
		{
			rdp_out_unistr(s, directory, len_directory);
		}
		else
		{
			out_uint16_le(s, 0);
		}
		out_uint16_le(s, 2);
		out_uint16_le(s, len_ip + 2);	/* Length of client ip */
		rdp_out_unistr(s, ipaddr, len_ip);
		free(ipaddr);
		out_uint16_le(s, len_dll + 2);
		rdp_out_unistr(s, "C:\\WINNT\\System32\\mstscax.dll", len_dll);

		tzone = (mktime(gmtime(&t)) - mktime(localtime(&t))) / 60;
		out_uint32_le(s, tzone);

		rdp_out_unistr(s, "GTB, normaltid", 2 * strlen("GTB, normaltid"));
		out_uint8s(s, 62 - 2 * strlen("GTB, normaltid"));

		out_uint32_le(s, 0x0a0000);
		out_uint32_le(s, 0x050000);
		out_uint32_le(s, 3);
		out_uint32_le(s, 0);
		out_uint32_le(s, 0);

		rdp_out_unistr(s, "GTB, sommartid", 2 * strlen("GTB, sommartid"));
		out_uint8s(s, 62 - 2 * strlen("GTB, sommartid"));

		out_uint32_le(s, 0x30000);
		out_uint32_le(s, 0x050000);
		out_uint32_le(s, 2);
		out_uint32(s, 0);
		out_uint32_le(s, 0xffffffc4);
		out_uint32_le(s, 0xfffffffe);
		out_uint32_le(s, conn->rdp5PerformanceFlags);
		out_uint16(s, 0);


	}
	s_mark_end(s);
	sec_send(conn, s, sec_flags);
}

/* Send a control PDU */
static void
rdp_send_control(RDConnectionRef conn, uint16 action)
{
	RDStreamRef s;

	s = rdp_init_data(conn, 8);

	out_uint16_le(s, action);
	out_uint16(s, 0);	/* userid */
	out_uint32(s, 0);	/* control id */

	s_mark_end(s);
	rdp_send_data(conn, s, RDP_DATA_PDU_CONTROL);
}

/* Send a synchronisation PDU */
static void
rdp_send_synchronise(RDConnectionRef conn)
{
	RDStreamRef s;

	s = rdp_init_data(conn, 4);

	out_uint16_le(s, 1);	/* type */
	out_uint16_le(s, 1002);

	s_mark_end(s);
	rdp_send_data(conn, s, RDP_DATA_PDU_SYNCHRONISE);
}

/* Send a single input event */
void
rdp_send_input(RDConnectionRef conn, uint32 time, uint16 message_type, uint16 device_flags, uint16 param1, uint16 param2)
{
	RDStreamRef s;

	s = rdp_init_data(conn, 16);

	out_uint16_le(s, 1);	/* number of events */
	out_uint16(s, 0);	/* pad */

	out_uint32_le(s, time);
	out_uint16_le(s, message_type);
	out_uint16_le(s, device_flags);
	out_uint16_le(s, param1);
	out_uint16_le(s, param2);

	s_mark_end(s);
	rdp_send_data(conn, s, RDP_DATA_PDU_INPUT);
}

/* Send a client window information PDU */
void
rdp_send_client_window_status(RDConnectionRef conn, int status)
{
   RDStreamRef s;

   if (conn->currentStatus == status)
       return;

   s = rdp_init_data(conn, 12);

   out_uint32_le(s, status);

   switch (status)
   {
       case 0: /* shut the server up */
           break;

       case 1: /* receive data again */
           out_uint32_le(s, 0);    /* unknown */
           out_uint16_le(s, conn->screenWidth);
           out_uint16_le(s, conn->screenHeight);
           break;
   }

   s_mark_end(s);
   rdp_send_data(conn, s, RDP_DATA_PDU_CLIENT_WINDOW_STATUS);
   conn->currentStatus = status;
}

/* Inform the server on the contents of the persistent bitmap cache */
static void
rdp_enum_bmpcache2(RDConnectionRef conn)
{
	RDStreamRef s;
	RDHashKey keylist[BMPCACHE2_NUM_PSTCELLS];
	uint32 num_keys, offset, count, flags;

	offset = 0;
	num_keys = pstcache_enumerate(conn, 2, keylist);

	while (offset < num_keys)
	{
		count = MIN(num_keys - offset, 169);

		s = rdp_init_data(conn, 24 + count * sizeof(RDHashKey));

		flags = 0;
		if (offset == 0)
			flags |= PDU_FLAG_FIRST;
		if (num_keys - offset <= 169)
			flags |= PDU_FLAG_LAST;

		/* header */
		out_uint32_le(s, 0);
		out_uint16_le(s, count);
		out_uint16_le(s, 0);
		out_uint16_le(s, 0);
		out_uint16_le(s, 0);
		out_uint16_le(s, 0);
		out_uint16_le(s, num_keys);
		out_uint32_le(s, 0);
		out_uint32_le(s, flags);

		/* list */
		out_uint8a(s, keylist[offset], count * sizeof(RDHashKey));

		s_mark_end(s);
		rdp_send_data(conn, s, 0x2b);

		offset += 169;
	}
}

/* Send an (empty) font information PDU */
static void
rdp_send_fonts(RDConnectionRef conn, uint16 seq)
{
	RDStreamRef s;

	s = rdp_init_data(conn, 8);

	out_uint16(s, 0);	/* number of fonts */
	out_uint16_le(s, 0);	/* pad? */
	out_uint16_le(s, seq);	/* unknown */
	out_uint16_le(s, 0x32);	/* entry size */

	s_mark_end(s);
	rdp_send_data(conn, s, RDP_DATA_PDU_FONT2);
}

/* Output general capability set */
static void
rdp_out_general_caps(RDConnectionRef conn, RDStreamRef s)
{
	out_uint16_le(s, RDP_CAPSET_GENERAL);
	out_uint16_le(s, RDP_CAPLEN_GENERAL);

	out_uint16_le(s, 1);	/* OS major type */
	out_uint16_le(s, 3);	/* OS minor type */
	out_uint16_le(s, 0x200);	/* Protocol version */
	out_uint16(s, 0);	/* Pad */
	out_uint16(s, RDP_MPPC_COMPRESSED);	/* Compression types */
	out_uint16_le(s, conn->useRdp5 ? 0x40d : 0);
	/* Pad, according to T.128. 0x40d seems to 
	   trigger
	   the server to start sending RDP5 packets. 
	   However, the value is 0x1d04 with W2KTSK and
	   NT4MS. Hmm.. Anyway, thankyou, Microsoft,
	   for sending such information in a padding 
	   field.. */
	out_uint16(s, 0);	/* Update capability */
	out_uint16(s, 0);	/* Remote unshare capability */
	out_uint16(s, 0);	/* Compression level */
	out_uint16(s, 0);	/* Pad */
}

/* Output bitmap capability set */
static void
rdp_out_bitmap_caps(RDConnectionRef conn, RDStreamRef s)
{
	out_uint16_le(s, RDP_CAPSET_BITMAP);
	out_uint16_le(s, RDP_CAPLEN_BITMAP);

	out_uint16_le(s, conn->serverBpp);	/* Preferred BPP */
	out_uint16_le(s, 1);	/* Receive 1 BPP */
	out_uint16_le(s, 1);	/* Receive 4 BPP */
	out_uint16_le(s, 1);	/* Receive 8 BPP */
	out_uint16_le(s, conn->screenWidth);	/* Desktop width */
	out_uint16_le(s, conn->screenHeight);	/* Desktop height */
	out_uint16(s, 0);	/* Pad */
	out_uint16(s, 1);	/* Allow resize */
	out_uint16_le(s, conn->useBitmapCompression ? 1 : 0);	/* Support compression */
	out_uint16(s, 0);	/* Unknown */
	out_uint16_le(s, 1);	/* Unknown */
	out_uint16(s, 0);	/* Pad */
}

/* Output order capability set */
static void
rdp_out_order_caps(RDConnectionRef conn, RDStreamRef s)
{
	uint8 order_caps[32];

	memset(order_caps, 0, 32);
	order_caps[0] = 1;	/* dest blt */
	order_caps[1] = 1;	/* pat blt */
	order_caps[2] = 1;	/* screen blt */
	order_caps[3] = (conn->bitmapCache ? 1 : 0);	/* memblt */
	order_caps[4] = 0;	/* triblt */
	order_caps[8] = 1;	/* line */
	order_caps[9] = 1;	/* line */
	order_caps[10] = 1;	/* rect */
	order_caps[11] = (conn->desktopSave ? 1 : 0);	/* desksave */
	order_caps[13] = 1;	/* memblt */
	order_caps[14] = 1;	/* triblt */
	order_caps[20] = (conn->polygonEllipseOrders ? 1 : 0);	/* polygon */
	order_caps[21] = (conn->polygonEllipseOrders ? 1 : 0);	/* polygon2 */
	order_caps[22] = 1;	/* polyline */
	order_caps[25] = (conn->polygonEllipseOrders ? 1 : 0);	/* ellipse */
	order_caps[26] = (conn->polygonEllipseOrders ? 1 : 0);	/* ellipse2 */
	order_caps[27] = 1;	/* text2 */
	out_uint16_le(s, RDP_CAPSET_ORDER);
	out_uint16_le(s, RDP_CAPLEN_ORDER);

	out_uint8s(s, 20);	/* Terminal desc, pad */
	out_uint16_le(s, 1);	/* Cache X granularity */
	out_uint16_le(s, 20);	/* Cache Y granularity */
	out_uint16(s, 0);	/* Pad */
	out_uint16_le(s, 1);	/* Max order level */
	out_uint16_le(s, 0x147);	/* Number of fonts */
	out_uint16_le(s, 0x2a);	/* Capability flags */
	out_uint8p(s, order_caps, 32);	/* Orders supported */
	out_uint16_le(s, 0x6a1);	/* Text capability flags */
	out_uint8s(s, 6);	/* Pad */
	out_uint32_le(s, conn->desktopSave == False ? 0 : DESKTOP_CACHE_SIZE);	/* Desktop cache size */
	out_uint32(s, 0);	/* Unknown */
	out_uint32_le(s, 0x4e4);	/* Unknown */
}

/* Output bitmap cache capability set */
static void
rdp_out_bmpcache_caps(RDConnectionRef conn, RDStreamRef s)
{
	int Bpp;
	out_uint16_le(s, RDP_CAPSET_BMPCACHE);
	out_uint16_le(s, RDP_CAPLEN_BMPCACHE);

	Bpp = (conn->serverBpp + 7) / 8;
	out_uint8s(s, 24);	/* unused */
	out_uint16_le(s, 0x258);	/* entries */
	out_uint16_le(s, 0x100 * Bpp);	/* max cell size */
	out_uint16_le(s, 0x12c);	/* entries */
	out_uint16_le(s, 0x400 * Bpp);	/* max cell size */
	out_uint16_le(s, 0x106);	/* entries */
	out_uint16_le(s, 0x1000 * Bpp);	/* max cell size */
}

/* Output bitmap cache v2 capability set */
static void
rdp_out_bmpcache2_caps(RDConnectionRef conn, RDStreamRef s)
{
	out_uint16_le(s, RDP_CAPSET_BMPCACHE2);
	out_uint16_le(s, RDP_CAPLEN_BMPCACHE2);

	out_uint16_le(s, conn->bitmapCachePersist ? 2 : 0);	/* version */

	out_uint16_be(s, 3);	/* number of caches in this set */

	/* max cell size for cache 0 is 16x16, 1 = 32x32, 2 = 64x64, etc */
	out_uint32_le(s, BMPCACHE2_C0_CELLS);
	out_uint32_le(s, BMPCACHE2_C1_CELLS);
	if (pstcache_init(conn, 2))
	{
		out_uint32_le(s, BMPCACHE2_NUM_PSTCELLS | BMPCACHE2_FLAG_PERSIST);
	}
	else
	{
		out_uint32_le(s, BMPCACHE2_C2_CELLS);
	}
	out_uint8s(s, 20);	/* other bitmap caches not used */
}

/* Output control capability set */
static void
rdp_out_control_caps(RDStreamRef s)
{
	out_uint16_le(s, RDP_CAPSET_CONTROL);
	out_uint16_le(s, RDP_CAPLEN_CONTROL);

	out_uint16(s, 0);	/* Control capabilities */
	out_uint16(s, 0);	/* Remote detach */
	out_uint16_le(s, 2);	/* Control interest */
	out_uint16_le(s, 2);	/* Detach interest */
}

/* Output activation capability set */
static void
rdp_out_activate_caps(RDStreamRef s)
{
	out_uint16_le(s, RDP_CAPSET_ACTIVATE);
	out_uint16_le(s, RDP_CAPLEN_ACTIVATE);

	out_uint16(s, 0);	/* Help key */
	out_uint16(s, 0);	/* Help index key */
	out_uint16(s, 0);	/* Extended help key */
	out_uint16(s, 0);	/* Window activate */
}

/* Output pointer capability set */
static void
rdp_out_pointer_caps(RDStreamRef s)
{
	out_uint16_le(s, RDP_CAPSET_POINTER);
	out_uint16_le(s, RDP_CAPLEN_POINTER);

	out_uint16(s, 0);	/* Colour pointer */
	out_uint16_le(s, 20);	/* Cache size */
}

/* Output new pointer capability set */
static void
rdp_out_newpointer_caps(RDStreamRef s)
{
	out_uint16_le(s, RDP_CAPSET_POINTER);
	out_uint16_le(s, RDP_CAPLEN_NEWPOINTER);

	out_uint16_le(s, 1);	/* Colour pointer */
	out_uint16_le(s, 20);	/* Cache size */
	out_uint16_le(s, 20);	/* Cache size for new pointers */
}

/* Output share capability set */
static void
rdp_out_share_caps(RDStreamRef s)
{
	out_uint16_le(s, RDP_CAPSET_SHARE);
	out_uint16_le(s, RDP_CAPLEN_SHARE);

	out_uint16(s, 0);	/* userid */
	out_uint16(s, 0);	/* pad */
}

/* Output colour cache capability set */
static void
rdp_out_colcache_caps(RDStreamRef s)
{
	out_uint16_le(s, RDP_CAPSET_COLCACHE);
	out_uint16_le(s, RDP_CAPLEN_COLCACHE);

	out_uint16_le(s, 6);	/* cache size */
	out_uint16(s, 0);	/* pad */
}

/* Output brush cache capability set */
static void
rdp_out_brushcache_caps(RDStreamRef s)
{
	out_uint16_le(s, RDP_CAPSET_BRUSHCACHE);
	out_uint16_le(s, RDP_CAPLEN_BRUSHCACHE);
	out_uint32_le(s, 1);	/* cache type */
}

static const uint8 caps_0x0d[] = {
	0x01, 0x00, 0x00, 0x00, 0x09, 0x04, 0x00, 0x00,
	0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x0C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
	0x00, 0x00, 0x00, 0x00
};

static const uint8 caps_0x0c[] = { 0x01, 0x00, 0x00, 0x00 };

static const uint8 caps_0x0e[] = { 0x01, 0x00, 0x00, 0x00 };

static const uint8 caps_0x10[] = {
	0xFE, 0x00, 0x04, 0x00, 0xFE, 0x00, 0x04, 0x00,
	0xFE, 0x00, 0x08, 0x00, 0xFE, 0x00, 0x08, 0x00,
	0xFE, 0x00, 0x10, 0x00, 0xFE, 0x00, 0x20, 0x00,
	0xFE, 0x00, 0x40, 0x00, 0xFE, 0x00, 0x80, 0x00,
	0xFE, 0x00, 0x00, 0x01, 0x40, 0x00, 0x00, 0x08,
	0x00, 0x01, 0x00, 0x01, 0x02, 0x00, 0x00, 0x00
};

/* Output unknown capability sets */
static void
rdp_out_unknown_caps(RDStreamRef s, uint16 id, uint16 length, const uint8 * caps)
{
	out_uint16_le(s, id);
	out_uint16_le(s, length);

	out_uint8p(s, caps, length - 4);
}

#define RDP5_FLAG 0x0030
/* Send a confirm active PDU */
static void
rdp_send_confirm_active(RDConnectionRef conn)
{
	RDStreamRef s;
	uint32 sec_flags = conn->useEncryption ? (RDP5_FLAG | SEC_ENCRYPT) : RDP5_FLAG;
	uint16 caplen =
		RDP_CAPLEN_GENERAL + RDP_CAPLEN_BITMAP + RDP_CAPLEN_ORDER +
		RDP_CAPLEN_COLCACHE +
		RDP_CAPLEN_ACTIVATE + RDP_CAPLEN_CONTROL +
		RDP_CAPLEN_SHARE +
		RDP_CAPLEN_BRUSHCACHE + 0x58 + 0x08 + 0x08 + 0x34 /* unknown caps */  +
		4 /* w2k fix, why? */ ;

	if (conn->useRdp5)
	{
		caplen += RDP_CAPLEN_BMPCACHE2;
		caplen += RDP_CAPLEN_NEWPOINTER;
	}
	else
	{
		caplen += RDP_CAPLEN_BMPCACHE;
		caplen += RDP_CAPLEN_POINTER;
	}
	
	s = sec_init(conn, sec_flags, 6 + 14 + caplen + sizeof(RDP_SOURCE));

	out_uint16_le(s, 2 + 14 + caplen + sizeof(RDP_SOURCE));
	out_uint16_le(s, (RDP_PDU_CONFIRM_ACTIVE | 0x10));	/* Version 1 */
	out_uint16_le(s, (conn->mcsUserid + 1001));

	out_uint32_le(s, conn->shareID);
	out_uint16_le(s, 0x3ea);	/* userid */
	out_uint16_le(s, sizeof(RDP_SOURCE));
	out_uint16_le(s, caplen);

	out_uint8p(s, RDP_SOURCE, sizeof(RDP_SOURCE));
	out_uint16_le(s, 0xe);	/* num_caps */
	out_uint8s(s, 2);	/* pad */

	rdp_out_general_caps(conn, s);
	rdp_out_bitmap_caps(conn, s);
	rdp_out_order_caps(conn, s);
	if (conn->useRdp5)
	{
		rdp_out_bmpcache2_caps(conn, s);
		rdp_out_newpointer_caps(s);
	} else {
		rdp_out_bmpcache_caps(conn, s);
		rdp_out_pointer_caps(s);
	}
	rdp_out_colcache_caps(s);
	rdp_out_activate_caps(s);
	rdp_out_control_caps(s);
	rdp_out_share_caps(s);
	rdp_out_brushcache_caps(s);

	rdp_out_unknown_caps(s, 0x0d, 0x58, caps_0x0d);	/* CAPSTYPE_INPUT */
	rdp_out_unknown_caps(s, 0x0c, 0x08, caps_0x0c); /* CAPSTYPE_SOUND */
	rdp_out_unknown_caps(s, 0x0e, 0x08, caps_0x0e); /* CAPSTYPE_FONT */
	rdp_out_unknown_caps(s, 0x10, 0x34, caps_0x10);	/* CAPSTYPE_GLYPHCACHE */

	s_mark_end(s);
	sec_send(conn, s, sec_flags);
}

/* Process a general capability set */
static void
rdp_process_general_caps(RDConnectionRef conn, RDStreamRef s)
{
	uint16 pad2octetsB;	/* rdp5 flags? */

	in_uint8s(s, 10);
	in_uint16_le(s, pad2octetsB);

	if (!pad2octetsB)
		conn->useRdp5 = False;
}

/* Process a bitmap capability set */
static void
rdp_process_bitmap_caps(RDConnectionRef conn, RDStreamRef s)
{
	uint16 width, height, bpp;

	in_uint16_le(s, bpp);
	in_uint8s(s, 6);

	in_uint16_le(s, width);
	in_uint16_le(s, height);

	DEBUG(("setting desktop size and bpp to: %dx%dx%d\n", width, height, bpp));

	/*
	 * The server may limit bpp and change the size of the desktop (for
	 * example when shadowing another session).
	 */
	if (conn->serverBpp != bpp)
	{
		CRDSessionView *view = conn->ui;
		warning("colour depth changed from %d to %d\n", conn->serverBpp, bpp);
		[view setBitdepth:bpp];
		conn->serverBpp = bpp;
	}
	if (conn->screenWidth != width || conn->screenHeight != height)
	{
		warning("screen size changed from %dx%d to %dx%d\n", conn->screenWidth, conn->screenHeight,
			width, height);
		conn->screenWidth = width;
		conn->screenHeight = height;
		ui_resize_window(conn);
	}
}

/* Process server capabilities */
void
rdp_process_server_caps(RDConnectionRef conn, RDStreamRef s, uint16 length)
{
	int n;
	uint8 *next, *start;
	uint16 ncapsets, capset_type, capset_length;

	start = s->p;

	in_uint16_le(s, ncapsets);
	in_uint8s(s, 2);	/* pad */

	for (n = 0; n < ncapsets; n++)
	{
		if (s->p > start + length)
			return;

		in_uint16_le(s, capset_type);
		in_uint16_le(s, capset_length);

		next = s->p + capset_length - 4;

		switch (capset_type)
		{
			case RDP_CAPSET_GENERAL:
				rdp_process_general_caps(conn, s);
				break;

			case RDP_CAPSET_BITMAP:
				rdp_process_bitmap_caps(conn, s);
				break;
		}

		s->p = next;
	}
}

/* Respond to a  */
void
process_demand_active(RDConnectionRef conn, RDStreamRef s)
{
	uint8 type;
	uint16 len_src_descriptor, len_combined_caps;

	in_uint32_le(s, conn->shareID);
	in_uint16_le(s, len_src_descriptor);
	in_uint16_le(s, len_combined_caps);
	in_uint8s(s, len_src_descriptor);

	DEBUG(("DEMAND_ACTIVE(id=0x%x)\n", conn->shareID));
	rdp_process_server_caps(conn, s, len_combined_caps);

	rdp_send_confirm_active(conn);
	rdp_send_synchronise(conn);
	rdp_send_control(conn, RDP_CTL_COOPERATE);
	rdp_send_control(conn, RDP_CTL_REQUEST_CONTROL);
	rdp_recv(conn, &type);	/* RDP_PDU_SYNCHRONIZE */
	rdp_recv(conn, &type);	/* RDP_CTL_COOPERATE */
	rdp_recv(conn, &type);	/* RDP_CTL_GRANT_CONTROL */
	rdp_send_input(conn, 0, RDP_INPUT_SYNCHRONIZE, 0, ui_get_numlock_state(read_keyboard_state()), 0);

	if (conn->useRdp5)
	{
		rdp_enum_bmpcache2(conn);
		rdp_send_fonts(conn, 3);
	}
	else
	{
		rdp_send_fonts(conn, 1);
		rdp_send_fonts(conn, 2);
	}

	rdp_recv(conn, &type);	/* RDP_PDU_UNKNOWN 0x28 (Fonts?) */
	reset_order_state(conn);
}

/* Process a colour pointer PDU */
static void
process_colour_pointer_common(RDConnectionRef conn, RDStreamRef s, int bpp)
{
	uint16 width, height, cache_idx, masklen, datalen;
	sint16 x, y;
	uint8 *mask, *data;
	RDCursorRef cursor;

	in_uint16_le(s, cache_idx);
	in_uint16_le(s, x);
	in_uint16_le(s, y);
	in_uint16_le(s, width);
	in_uint16_le(s, height);
	in_uint16_le(s, masklen);
	in_uint16_le(s, datalen);
	in_uint8p(s, data, datalen);
	in_uint8p(s, mask, masklen);

	x = MAX(x,0);
	x = MIN(x, width - 1);
	y = MAX(y,0);
	y = MIN(y, height - 1);
	cursor = ui_create_cursor(conn, x, y, width, height, mask, data, bpp);
	ui_set_cursor(conn, cursor);
	cache_put_cursor(conn, cache_idx, cursor);
}

/* Process a colour pointer PDU */
void
process_colour_pointer_pdu(RDConnectionRef conn, RDStreamRef s)
{
	process_colour_pointer_common(conn, s, 24);
}

/* Process a New Pointer PDU - these pointers have variable bit depth */
void 
process_new_pointer_pdu(RDConnectionRef conn, RDStreamRef s)
{
	int xor_bpp;
	
	in_uint16_le(s, xor_bpp);
	process_colour_pointer_common(conn, s, xor_bpp);
}


/* Process a cached pointer PDU */
void
process_cached_pointer_pdu(RDConnectionRef conn, RDStreamRef s)
{
	uint16 cache_idx;

	in_uint16_le(s, cache_idx);
	ui_set_cursor(conn, cache_get_cursor(conn, cache_idx));
}

/* Process a system pointer PDU */
void
process_system_pointer_pdu(RDConnectionRef conn, RDStreamRef s)
{
	uint16 system_pointer_type;

	in_uint16_le(s, system_pointer_type);
	switch (system_pointer_type)
	{
		case RDP_NULL_POINTER:
			ui_set_null_cursor(conn);
			break;

		default:
			unimpl("System pointer message 0x%x\n", system_pointer_type);
	}
}

/* Process a pointer PDU */
static void
process_pointer_pdu(RDConnectionRef conn, RDStreamRef s)
{
	uint16 message_type;
	uint16 x, y;

	in_uint16_le(s, message_type);
	in_uint8s(s, 2);	/* pad */

	switch (message_type)
	{
		case RDP_POINTER_MOVE:
			in_uint16_le(s, x);
			in_uint16_le(s, y);
			if (s_check(s))
				ui_move_pointer(conn, x, y);
			break;

		case RDP_POINTER_COLOR:
			process_colour_pointer_pdu(conn, s);
			break;

		case RDP_POINTER_CACHED:
			process_cached_pointer_pdu(conn, s);
			break;

		case RDP_POINTER_SYSTEM:
			process_system_pointer_pdu(conn, s);
			break;
			
		case RDP_POINTER_NEW:
			process_new_pointer_pdu(conn, s);
			break;

		default:
			unimpl("Pointer message 0x%x\n", message_type);
	}
}

/* Process bitmap updates */
void
process_bitmap_updates(RDConnectionRef conn, RDStreamRef s)
{
	uint16 num_updates;
	uint16 left, top, right, bottom, width, height;
	uint16 cx, cy, bpp, Bpp, compress, bufsize, size;
	uint8 *data, *bmpdata;
	int i;

	in_uint16_le(s, num_updates);

	for (i = 0; i < num_updates; i++)
	{
		in_uint16_le(s, left);
		in_uint16_le(s, top);
		in_uint16_le(s, right);
		in_uint16_le(s, bottom);
		in_uint16_le(s, width);
		in_uint16_le(s, height);
		in_uint16_le(s, bpp);
		Bpp = (bpp + 7) / 8;
		in_uint16_le(s, compress);
		in_uint16_le(s, bufsize);

		cx = right - left + 1;
		cy = bottom - top + 1;

		DEBUG(("BITMAP_UPDATE(l=%d,t=%d,r=%d,b=%d,w=%d,h=%d,Bpp=%d,cmp=%d)\n",
		       left, top, right, bottom, width, height, Bpp, compress));

		if (!compress)
		{
			int y;
			bmpdata = (uint8 *) xmalloc(width * height * Bpp);
			for (y = 0; y < height; y++)
			{
				in_uint8a(s, &bmpdata[(height - y - 1) * (width * Bpp)],
					  width * Bpp);
			}
			ui_paint_bitmap(conn, left, top, cx, cy, width, height, bmpdata);
			xfree(bmpdata);
			continue;
		}


		if (compress & 0x400)
		{
			size = bufsize;
		}
		else
		{
			in_uint8s(s, 2);	/* pad */
			in_uint16_le(s, size);
			in_uint8s(s, 4);	/* line_size, final_size */
		}
		in_uint8p(s, data, size);
		bmpdata = (uint8 *) xmalloc(width * height * Bpp);
		if (bitmap_decompress(bmpdata, width, height, data, size, Bpp))
		{
			ui_paint_bitmap(conn, left, top, cx, cy, width, height, bmpdata);
		}
		else
		{
			DEBUG_RDP5(("Failed to decompress data\n"));
		}

		xfree(bmpdata);
	}
}

/* Process a palette update */
void
process_palette(RDConnectionRef conn, RDStreamRef s)
{
	RDColorEntry *entry;
	RDColorMap map;
	RDColorMapRef hmap;
	int i;

	in_uint8s(s, 2);	/* pad */
	in_uint16_le(s, map.ncolours);
	in_uint8s(s, 2);	/* pad */

	map.colours = (RDColorEntry *) xmalloc(sizeof(RDColorEntry) * map.ncolours);

	DEBUG(("PALETTE(c=%d)\n", map.ncolours));

	for (i = 0; i < map.ncolours; i++)
	{
		entry = &map.colours[i];
		in_uint8(s, entry->red);
		in_uint8(s, entry->green);
		in_uint8(s, entry->blue);
	}

	hmap = ui_create_colourmap(&map);
	ui_set_colourmap(conn, hmap);

	xfree(map.colours);
}

/* Process an update PDU */
static void
process_update_pdu(RDConnectionRef conn, RDStreamRef s)
{
	uint16 update_type, count;

	in_uint16_le(s, update_type);
	
	ui_begin_update(conn);
	
	switch (update_type)
	{
		case RDP_UPDATE_ORDERS:
			in_uint8s(s, 2);	/* pad */
			in_uint16_le(s, count);
			in_uint8s(s, 2);	/* pad */
			process_orders(conn, s, count);
			break;

		case RDP_UPDATE_BITMAP:
			process_bitmap_updates(conn, s);
			break;

		case RDP_UPDATE_PALETTE:
			process_palette(conn, s);
			break;

		case RDP_UPDATE_SYNCHRONIZE:
			break;

		default:
			unimpl("update %d\n", update_type);
	}
	
	ui_end_update(conn);
}

/* Process a disconnect PDU */
void
process_disconnect_pdu(RDConnectionRef conn, RDStreamRef s, uint32 * ext_disc_reason)
{
	in_uint32_le(s, *ext_disc_reason);

	DEBUG(("Received disconnect PDU\n"));
}

/* Process data PDU */
RD_BOOL
process_data_pdu(RDConnectionRef conn, RDStreamRef s, uint32 * ext_disc_reason)
{
	uint8 data_pdu_type;
	uint8 ctype;
	uint16 clen;
	uint32 len;

	uint32 roff, rlen;

	RDStream *ns = &(conn->mppcDict.ns);

	in_uint8s(s, 6);	/* shareid, pad, streamid */
	in_uint16_le(s, len);
	in_uint8(s, data_pdu_type);
	in_uint8(s, ctype);
	in_uint16_le(s, clen);
	clen -= 18;

	if (ctype & RDP_MPPC_COMPRESSED)
	{
		//fprintf(stderr, "RDP conn:%p stream:%s length:%d ctype:%d\n", conn, s, clen, ctype);
		if (len > RDP_MPPC_DICT_SIZE)
			error("error decompressed packet size exceeds max\n");
		if (mppc_expand(conn, s->p, clen, ctype, &roff, &rlen) == -1)
			error("error while decompressing packet\n");

		/* len -= 18; */

		/* allocate memory and copy the uncompressed data into the temporary stream */
		ns->data = (uint8 *) xrealloc(ns->data, rlen);

		memcpy((ns->data), (unsigned char *) (conn->mppcDict.hist + roff), rlen);

		ns->size = rlen;
		ns->end = (ns->data + ns->size);
		ns->p = ns->data;
		ns->rdp_hdr = ns->p;

		s = ns;
	}

	switch (data_pdu_type)
	{
		case RDP_DATA_PDU_UPDATE:
			process_update_pdu(conn, s);
			break;

		case RDP_DATA_PDU_CONTROL:
			DEBUG(("Received Control PDU\n"));
			break;

		case RDP_DATA_PDU_SYNCHRONISE:
			DEBUG(("Received Sync PDU\n"));
			break;

		case RDP_DATA_PDU_POINTER:
			process_pointer_pdu(conn, s);
			break;

		case RDP_DATA_PDU_BELL:
			ui_bell();
			break;

		case RDP_DATA_PDU_LOGON:
			DEBUG(("Received Logon PDU\n"));
			/* User logged on */
			break;

		case RDP_DATA_PDU_DISCONNECT:
			process_disconnect_pdu(conn, s, ext_disc_reason);

         /* We used to return true and disconnect immediately here, but
            * Windows Vista sends a disconnect PDU with reason 0 when
            * reconnecting to a disconnected session, and MSTSC doesn't
            * drop the connection.  I think we should just save the status.
            */
			break;

		default:
			unimpl("data PDU %d\n", data_pdu_type);
	}
	return False;
}

/* Process redirect PDU from Session Directory */
RD_BOOL
process_redirect_pdu(RDConnectionRef conn, RDStreamRef s /*, uint32 * ext_disc_reason */ )
{
	uint32 len;

	/* these 2 bytes are unknown, seem to be zeros */
	in_uint8s(s, 2);

	/* read connection flags */
	in_uint32_le(s, conn->sessionDirFlags);

	/* read length of ip string */
	in_uint32_le(s, len);

	/* read ip string */
	rdp_in_unistr(s, conn->sessionDirServer, len);

	/* read length of cookie string */
	in_uint32_le(s, len);

	/* read cookie string (plain ASCII) */
	in_uint8a(s, conn->sessionDirCookie, len);
	conn->sessionDirCookie[len] = '\0';

	/* read length of username string */
	in_uint32_le(s, len);

	/* read username string */
	rdp_in_unistr(s, conn->sessionDirUsername, len);

	/* read length of domain string */
	in_uint32_le(s, len);

	/* read domain string */
	rdp_in_unistr(s, conn->sessionDirDomain, len);

	/* read length of password string */
	in_uint32_le(s, len);

	/* read password string */
	rdp_in_unistr(s, conn->sessionDirPassword, len);

	conn->sessionDirRedirect = True;

	return True;
}

/* Establish a connection up to the RDP layer */
RD_BOOL
rdp_connect(RDConnectionRef conn, const char *server, uint32 flags, NSString *domain, NSString *username, NSString *password,
	    const char *command, const char *directory)
{
	if (!sec_connect(conn, server, conn->username))
		return False;

	rdp_send_logon_info(conn, flags, domain, username, password, command, directory);
	return True;
}

/* Establish a reconnection up to the RDP layer */
RD_BOOL
rdp_reconnect(RDConnectionRef conn, const char *server, uint32 flags, NSString *domain, NSString *username, NSString *password,
		const char *command, const char *directory, char *cookie)
{
	if (!sec_reconnect(conn, (char *)server))
		return False;
	
	rdp_send_logon_info(conn, flags, domain, username, password, command, directory);
	return True;
} 

/* Called during redirection to reset the state to support redirection */
void
rdp_reset_state(RDConnectionRef conn)
{
	conn->nextPacket = NULL;	/* reset the packet information */
	conn->shareID = 0;
	sec_reset_state(conn);
}

/* Disconnect from the RDP layer */
void
rdp_disconnect(RDConnectionRef conn)
{
	sec_disconnect(conn);
}
