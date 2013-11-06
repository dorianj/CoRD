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
#import "rdpsnd.h"

#define RDPSND_CLOSE        1
#define RDPSND_WRITE        2
#define RDPSND_SET_VOLUME   3
#define RDPSND_UNKNOWN4     4
#define RDPSND_COMPLETION   5
#define RDPSND_SERVERTICK   6
#define RDPSND_NEGOTIATE    7

#define MAX_QUEUE           10

RD_BOOL g_dsp_busy = False;
int g_dsp_fd;

static RDVirtualChannel *rdpsnd_channel;

static struct audio_driver *drivers = NULL;
struct audio_driver *current_driver = NULL;

static RD_BOOL device_open;
static RDWaveFormat formats[MAX_SOUND_FORMATS];
static unsigned int format_count;
static unsigned int current_format;
unsigned int queue_hi, queue_lo;
struct audio_packet packet_queue[MAX_QUEUE];

static RDStreamRef
rdpsnd_init_packet(RDConnectionRef conn, uint16 type, uint16 size)
{
	RDStreamRef s;

	s = channel_init(conn, rdpsnd_channel, size + 4);
	out_uint16_le(s, type);
	out_uint16_le(s, size);
	return s;
}

static void
rdpsnd_send(RDConnectionRef conn, RDStreamRef s)
{
#ifdef RDPSND_DEBUG
	printf("RDPSND send:\n");
	hexdump(s->channel_hdr + 8, s->end - s->channel_hdr - 8);
#endif

	channel_send(conn, s, rdpsnd_channel);
}

void
rdpsnd_send_completion(RDConnectionRef conn, uint16 tick, uint8 packet_index)
{
	RDStreamRef s;

	s = rdpsnd_init_packet(conn, RDPSND_COMPLETION, 4);
	out_uint16_le(s, tick);
	out_uint8(s, packet_index);
	out_uint8(s, 0);
	s_mark_end(s);
	rdpsnd_send(conn, s);
}

static void
rdpsnd_process_negotiate(RDConnectionRef conn, RDStreamRef in)
{
	unsigned int in_format_count, i;
	RDWaveFormat *format;
    RDStreamRef out;
	RDStreamRef outStream;
	RD_BOOL device_available = False;
	int readcnt;
	int discardcnt;

	in_uint8s(in, 14);	/* flags, volume, pitch, UDP port */
	in_uint16_le(in, in_format_count);
	in_uint8s(in, 4);	/* pad, status, pad */

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
				fprintf(stderr, "cbSize too large for buffer: %d\n", format->cbSize);
				readcnt = MAX_CBSIZE;
				discardcnt = format->cbSize - MAX_CBSIZE;
			}
			in_uint8a(in, format->cb, readcnt);
			in_uint8s(in, discardcnt);

			if (device_available)
			{
				format_count++;
				if (format_count == MAX_SOUND_FORMATS)
					break;
			}
		}
	}

	out = rdpsnd_init_packet(conn, RDPSND_NEGOTIATE | 0x200, 20 + 18 * format_count);
	s_mark_end(out);
	rdpsnd_send(conn, out);
}

static void
rdpsnd_process_servertick(RDConnectionRef conn, RDStreamRef in)
{
	uint16 tick1, tick2;
	RDStreamRef out;

	/* in_uint8s(in, 4); unknown */
	in_uint16_le(in, tick1);
	in_uint16_le(in, tick2);

	out = rdpsnd_init_packet(conn, RDPSND_SERVERTICK | 0x2300, 4);
	out_uint16_le(out, tick1);
	out_uint16_le(out, tick2);
	s_mark_end(out);
	rdpsnd_send(conn, out);
}

static void
rdpsnd_process(RDConnectionRef conn, RDStreamRef s)
{
	uint8 type;
	uint16 datalen;
	uint32 volume;
	static uint16 tick, format;
	static uint8 packet_index;
	static RD_BOOL awaiting_data_packet;

#ifdef RDPSND_DEBUG
	printf("RDPSND recv:\n");
	hexdump(s->p, s->end - s->p);
#endif

	if (awaiting_data_packet)
	{
		if (format >= MAX_SOUND_FORMATS)
		{
			error("RDPSND: Invalid format index\n");
			return;
		}

		if (!device_open || (format != current_format))
		{
			if (!device_open && !current_driver->wave_out_open())
			{
				rdpsnd_send_completion(conn, tick, packet_index);
				return;
			}
			device_open = True;
			current_format = format;
		}

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
			current_driver->wave_out_close();
			device_open = False;
			break;
		case RDPSND_NEGOTIATE:
			rdpsnd_process_negotiate(conn, s);
			break;
		case RDPSND_SERVERTICK:
			rdpsnd_process_servertick(conn, s);
			break;
		case RDPSND_SET_VOLUME:
			in_uint32(s, volume);
			if (device_open)
			{
				current_driver->wave_out_volume((volume & 0xffff),(volume & 0xffff0000) >> 16);
			}
			break;
		default:
			unimpl("RDPSND packet type %d\n", type);
			break;
	}
}

RD_BOOL
rdpsnd_init(RDConnectionRef conn)
{
	rdpsnd_channel =
		channel_register(conn, "rdpsnd", CHANNEL_OPTION_INITIALIZED | CHANNEL_OPTION_ENCRYPT_RDP,
				 rdpsnd_process);
	return (rdpsnd_channel != NULL);
}

inline struct audio_packet *
rdpsnd_queue_current_packet(void)
{
    return &packet_queue[queue_lo];
}

inline RD_BOOL
rdpsnd_queue_empty(void)
{
    return (queue_lo == queue_hi);
}

inline void
rdpsnd_queue_init(void)
{
    queue_lo = queue_hi = 0;
}

inline void
rdpsnd_queue_next(void)
{
    free(packet_queue[queue_lo].s.data);
    queue_lo = (queue_lo + 1) % MAX_QUEUE;
}

inline int
rdpsnd_queue_next_tick(void)
{
    if (((queue_lo + 1) % MAX_QUEUE) != queue_hi)
    {
        return packet_queue[(queue_lo + 1) % MAX_QUEUE].tick;
    }
    else
    {
        return (packet_queue[queue_lo].tick + 65535) % 65536;
    }
}