/* -*- c-basic-offset: 8 -*-
   rdesktop: A Remote Desktop Protocol client.
   Protocol services - RDP5 short form PDU processing
   Copyright (C) Matthew Chapman 1999-2008
   Copyright (C) Erik Forsberg 2003-208

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

#import "rdesktop.h"


void
rdp5_process(RDConnectionRef conn, RDStreamRef s)
{
	uint16 length, count, x, y;
	uint8 type, ctype;
	uint8 *next;

	uint32 roff, rlen;
	RDStream *ns = &(conn->mppcDict.ns);
	RDStream *ts;

#if 0
	printf("RDP5 data:\n");
	hexdump(s->p, s->end - s->p);
#endif

	ui_begin_update(conn);
	while (s->p < s->end)
	{	
		in_uint8(s, type);
		if (type & RDP5_COMPRESSED)
		{			
			in_uint8(s, ctype);
			in_uint16_le(s, length);
			type ^= RDP5_COMPRESSED;
		}
		else
		{
			ctype = 0;
			in_uint16_le(s, length);
		}
		conn->nextPacket = next = s->p + length;
			
		if (ctype & RDP_MPPC_COMPRESSED)
		{
			fprintf(stderr, "RDP5 conn:%p stream:%p length:%d ctype:%d\n", conn, s, length, ctype);
			if (mppc_expand(conn, s->p, length, ctype, &roff, &rlen) == -1)
				error("error while decompressing packet\n");

			/* allocate memory and copy the uncompressed data into the temporary stream */
			ns->data = (uint8 *) xrealloc(ns->data, rlen);

			memcpy((ns->data), (unsigned char *) (conn->mppcDict.hist + roff), rlen);

			ns->size = rlen;
			ns->end = (ns->data + ns->size);
			ns->p = ns->data;
			ns->rdp_hdr = ns->p;

			ts = ns;
		}
		else
			ts = s;

		switch (type)
		{
			case 0:	/* update orders */
				in_uint16_le(ts, count);
				process_orders(conn, ts, count);
				break;
			case 1:	/* update bitmap */
				in_uint8s(ts, 2);	/* part length */
				process_bitmap_updates(conn, ts);
				break;
			case 2:	/* update palette */
				in_uint8s(ts, 2);	/* uint16 = 2 */
				process_palette(conn, ts);
				break;
			case 3:	/* update synchronize */
				break;
			case 5: /* null pointer */
				ui_set_null_cursor(conn);
				break;
			case 6:	/* default pointer */
				break;
			case 8: /* pointer position */
				in_uint16_le(ts, x);
				in_uint16_le(ts, y);
				if (s_check(ts))
					ui_move_pointer(conn, x, y);
				break;
			case 9: /* color pointer */
				process_colour_pointer_pdu(conn, ts);
				break;
			case 10: /* cached pointer */
				process_cached_pointer_pdu(conn, ts);
				break;
			case 11: /* Win7/Server08R2 pointer */
				process_new_pointer_pdu(conn, ts);
				break;
			default:
				unimpl("RDP5 opcode %d\n", type);
		}

		s->p = next;
	}
	ui_end_update(conn);
}
