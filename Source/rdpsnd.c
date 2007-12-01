/* 
   rdesktop: A Remote Desktop Protocol client.
   Sound Channel Process Functions
   Copyright (C) Matthew Chapman 2003
   Copyright (C) GuoJunBo guojunbo@ict.ac.cn 2003

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

#define RDPSND_CLOSE		1
#define RDPSND_WRITE		2
#define RDPSND_SET_VOLUME	3
#define RDPSND_UNKNOWN4		4
#define RDPSND_COMPLETION	5
#define RDPSND_UNKNOWN6		6
#define RDPSND_NEGOTIATE	7

#define MAX_FORMATS		10

static VCHANNEL *rdpsnd_channel;

static RDCBOOL device_open;
static WAVEFORMATEX formats[MAX_FORMATS];
static unsigned int format_count;
static unsigned int current_format;

static STREAM
rdpsnd_init_packet(uint16 type, uint16 size)
{
	STREAM s;

	s = channel_init(rdpsnd_channel, size + 4);
	out_uint16_le(s, type);
	out_uint16_le(s, size);
	return s;
}

static void
rdpsnd_send(STREAM s)
{
#ifdef RDPSND_DEBUG
	printf("RDPSND send:\n");
	hexdump(s->channel_hdr + 8, s->end - s->channel_hdr - 8);
#endif

	channel_send(s, rdpsnd_channel);
}

void
rdpsnd_send_completion(uint16 tick, uint8 packet_index)
{
	STREAM s;

	s = rdpsnd_init_packet(RDPSND_COMPLETION, 4);
	out_uint16_le(s, tick + 50);
	out_uint8(s, packet_index);
	out_uint8(s, 0);
	s_mark_end(s);
	rdpsnd_send(s);
}

static void
rdpsnd_process_negotiate(STREAM in)
{
	unsigned int in_format_count, i;
	WAVEFORMATEX *format;
	STREAM out;
	RDCBOOL device_available = False;
	int readcnt;
	int discardcnt;

	in_uint8s(in, 14);	/* flags, volume, pitch, UDP port */
	in_uint16_le(in, in_format_count);
	in_uint8s(in, 4);	/* pad, status, pad */

	if (wave_out_open())
	{
		wave_out_close();
		device_available = True;
	}

	format_count = 0;
	if (s_check_rem(in, 18 * in_format_count))
	{
		for (i = 0; i < in_format_count; i++)
		{
			format = &formats[format_count];
			in_uint16_le(in, format->wFormatTag);
			in_uint16_le(in, format->nChannels);
			in_uint32_le(in, format->nSamplesPerSec);
			in_uint32_le(in, format->nAvgBytesPerSec);
			in_uint16_le(in, format->nBlockAlign);
			in_uint16_le(in, format->wBitsPerSample);
			in_uint16_le(in, format->cbSize);

			/* read in the buffer of unknown use */
			readcnt = format->cbSize;
			discardcnt = 0;
			if (format->cbSize > MAX_CBSIZE)
			{
				fprintf(stderr, "cbSize too large for buffer: %d\n",
					format->cbSize);
				readcnt = MAX_CBSIZE;
				discardcnt = format->cbSize - MAX_CBSIZE;
			}
			in_uint8a(in, format->cb, readcnt);
			in_uint8s(in, discardcnt);

			if (device_available && wave_out_format_supported(format))
			{
				format_count++;
				if (format_count == MAX_FORMATS)
					break;
			}
		}
	}

	out = rdpsnd_init_packet(RDPSND_NEGOTIATE | 0x200, 20 + 18 * format_count);
	out_uint32_le(out, 3);	/* flags */
	out_uint32(out, 0xffffffff);	/* volume */
	out_uint32(out, 0);	/* pitch */
	out_uint16(out, 0);	/* UDP port */

	out_uint16_le(out, format_count);
	out_uint8(out, 0x95);	/* pad? */
	out_uint16_le(out, 2);	/* status */
	out_uint8(out, 0x77);	/* pad? */

	for (i = 0; i < format_count; i++)
	{
		format = &formats[i];
		out_uint16_le(out, format->wFormatTag);
		out_uint16_le(out, format->nChannels);
		out_uint32_le(out, format->nSamplesPerSec);
		out_uint32_le(out, format->nAvgBytesPerSec);
		out_uint16_le(out, format->nBlockAlign);
		out_uint16_le(out, format->wBitsPerSample);
		out_uint16(out, 0);	/* cbSize */
	}

	s_mark_end(out);
	rdpsnd_send(out);
}

static void
rdpsnd_process_unknown6(STREAM in)
{
	uint16 unknown1, unknown2;
	STREAM out;

	/* in_uint8s(in, 4); unknown */
	in_uint16_le(in, unknown1);
	in_uint16_le(in, unknown2);

	out = rdpsnd_init_packet(RDPSND_UNKNOWN6 | 0x2300, 4);
	out_uint16_le(out, unknown1);
	out_uint16_le(out, unknown2);
	s_mark_end(out);
	rdpsnd_send(out);
}

static void
rdpsnd_process(STREAM s)
{
	uint8 type;
	uint16 datalen;
	uint32 volume;
	static uint16 tick, format;
	static uint8 packet_index;
	static RDCBOOL awaiting_data_packet;

#ifdef RDPSND_DEBUG
	printf("RDPSND recv:\n");
	hexdump(s->p, s->end - s->p);
#endif

	if (awaiting_data_packet)
	{
		if (format >= MAX_FORMATS)
		{
			error("RDPSND: Invalid format index\n");
			return;
		}

		if (!device_open || (format != current_format))
		{
			if (!device_open && !wave_out_open())
			{
				rdpsnd_send_completion(tick, packet_index);
				return;
			}
			if (!wave_out_set_format(&formats[format]))
			{
				rdpsnd_send_completion(tick, packet_index);
				wave_out_close();
				device_open = False;
				return;
			}
			device_open = True;
			current_format = format;
		}

		wave_out_write(s, tick, packet_index);
		awaiting_data_packet = False;
		return;
	}

	in_uint8(s, type);
	in_uint8s(s, 1);	/* unknown? */
	in_uint16_le(s, datalen);

	switch (type)
	{
		case RDPSND_WRITE:
			in_uint16_le(s, tick);
			in_uint16_le(s, format);
			in_uint8(s, packet_index);
			awaiting_data_packet = True;
			break;
		case RDPSND_CLOSE:
			wave_out_close();
			device_open = False;
			break;
		case RDPSND_NEGOTIATE:
			rdpsnd_process_negotiate(s);
			break;
		case RDPSND_UNKNOWN6:
			rdpsnd_process_unknown6(s);
			break;
		case RDPSND_SET_VOLUME:
			in_uint32(s, volume);
			if (device_open)
			{
				wave_out_volume((volume & 0xffff), (volume & 0xffff0000) >> 16);
			}
			break;
		default:
			unimpl("RDPSND packet type %d\n", type);
			break;
	}
}

RDCBOOL
rdpsnd_init(void)
{
	rdpsnd_channel =
		channel_register("rdpsnd", CHANNEL_OPTION_INITIALIZED | CHANNEL_OPTION_ENCRYPT_RDP,
				 rdpsnd_process);
	return (rdpsnd_channel != NULL);
}
