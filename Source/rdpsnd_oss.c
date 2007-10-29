/*
   rdesktop: A Remote Desktop Protocol client.
   Sound Channel Process Functions - Open Sound System
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
#import <unistd.h>
#import <fcntl.h>
#import <errno.h>
#import <sys/time.h>
#import <sys/ioctl.h>
#import <sys/soundcard.h>

#define MAX_QUEUE	10

int g_dsp_fd;
RDCBOOL g_dsp_busy = False;
static int g_snd_rate;
static short g_samplewidth;
static RDCBOOL g_driver_broken = False;

static struct audio_packet
{
	struct stream s;
	uint16 tick;
	uint8 index;
} packet_queue[MAX_QUEUE];
static unsigned int queue_hi, queue_lo;

RDCBOOL
wave_out_open(void)
{
	char *dsp_dev = getenv("AUDIODEV");

	if (dsp_dev == NULL)
	{
		dsp_dev = strdup("/dev/dsp");
	}

	if ((g_dsp_fd = open(dsp_dev, O_WRONLY | O_NONBLOCK)) == -1)
	{
		perror(dsp_dev);
		return False;
	}

	/* Non-blocking so that user interface is responsive */
	fcntl(g_dsp_fd, F_SETFL, fcntl(g_dsp_fd, F_GETFL) | O_NONBLOCK);
	return True;
}

void
wave_out_close(void)
{
	close(g_dsp_fd);
}

RDCBOOL
wave_out_format_supported(WAVEFORMATEX * pwfx)
{
	if (pwfx->wFormatTag != WAVE_FORMAT_PCM)
		return False;
	if ((pwfx->nChannels != 1) && (pwfx->nChannels != 2))
		return False;
	if ((pwfx->wBitsPerSample != 8) && (pwfx->wBitsPerSample != 16))
		return False;

	return True;
}

RDCBOOL
wave_out_set_format(WAVEFORMATEX * pwfx)
{
	int stereo, format, fragments;

	ioctl(g_dsp_fd, SNDCTL_DSP_RESET, NULL);
	ioctl(g_dsp_fd, SNDCTL_DSP_SYNC, NULL);

	if (pwfx->wBitsPerSample == 8)
		format = AFMT_U8;
	else if (pwfx->wBitsPerSample == 16)
		format = AFMT_S16_LE;

	g_samplewidth = pwfx->wBitsPerSample / 8;

	if (ioctl(g_dsp_fd, SNDCTL_DSP_SETFMT, &format) == -1)
	{
		perror("SNDCTL_DSP_SETFMT");
		close(g_dsp_fd);
		return False;
	}

	if (pwfx->nChannels == 2)
	{
		stereo = 1;
		g_samplewidth *= 2;
	}
	else
	{
		stereo = 0;
	}

	if (ioctl(g_dsp_fd, SNDCTL_DSP_STEREO, &stereo) == -1)
	{
		perror("SNDCTL_DSP_CHANNELS");
		close(g_dsp_fd);
		return False;
	}

	g_snd_rate = pwfx->nSamplesPerSec;
	if (ioctl(g_dsp_fd, SNDCTL_DSP_SPEED, &g_snd_rate) == -1)
	{
		perror("SNDCTL_DSP_SPEED");
		close(g_dsp_fd);
		return False;
	}

	/* try to get 7 fragments of 2^12 bytes size */
	fragments = (7 << 16) + 12;
	ioctl(g_dsp_fd, SNDCTL_DSP_SETFRAGMENT, &fragments);

	if (!g_driver_broken)
	{
		audio_buf_info info;

		memset(&info, 0, sizeof(info));
		if (ioctl(g_dsp_fd, SNDCTL_DSP_GETOSPACE, &info) == -1)
		{
			perror("SNDCTL_DSP_GETOSPACE");
			close(g_dsp_fd);
			return False;
		}

		if (info.fragments == 0 || info.fragstotal == 0 || info.fragsize == 0)
		{
			fprintf(stderr,
				"Broken OSS-driver detected: fragments: %d, fragstotal: %d, fragsize: %d\n",
				info.fragments, info.fragstotal, info.fragsize);
			g_driver_broken = True;
		}
	}

	return True;
}

void
wave_out_volume(uint16 left, uint16 right)
{
	static RDCBOOL use_dev_mixer = False;
	uint32 volume;
	int fd_mix = -1;

	volume = left / (65536 / 100);
	volume |= right / (65536 / 100) << 8;

	if (use_dev_mixer)
	{
		if ((fd_mix = open("/dev/mixer", O_RDWR | O_NONBLOCK)) == -1)
		{
			perror("open /dev/mixer");
			return;
		}

		if (ioctl(fd_mix, MIXER_WRITE(SOUND_MIXER_PCM), &volume) == -1)
		{
			perror("MIXER_WRITE(SOUND_MIXER_PCM)");
			return;
		}

		close(fd_mix);
	}

	if (ioctl(g_dsp_fd, MIXER_WRITE(SOUND_MIXER_PCM), &volume) == -1)
	{
		perror("MIXER_WRITE(SOUND_MIXER_PCM)");
		use_dev_mixer = True;
		return;
	}
}

void
wave_out_write(STREAM s, uint16 tick, uint8 index)
{
	struct audio_packet *packet = &packet_queue[queue_hi];
	unsigned int next_hi = (queue_hi + 1) % MAX_QUEUE;

	if (next_hi == queue_lo)
	{
		error("No space to queue audio packet\n");
		return;
	}

	queue_hi = next_hi;

	packet->s = *s;
	packet->tick = tick;
	packet->index = index;
	packet->s.p += 4;

	/* we steal the data buffer from s, give it a new one */
	s->data = (uint8 *) malloc(s->size);

	if (!g_dsp_busy)
		wave_out_play();
}

void
wave_out_play(void)
{
	struct audio_packet *packet;
	ssize_t len;
	STREAM out;
	static long startedat_us;
	static long startedat_s;
	static RDCBOOL started = False;
	struct timeval tv;
	audio_buf_info info;

	while (1)
	{
		if (queue_lo == queue_hi)
		{
			g_dsp_busy = 0;
			return;
		}

		packet = &packet_queue[queue_lo];
		out = &packet->s;

		if (!started)
		{
			gettimeofday(&tv, NULL);
			startedat_us = tv.tv_usec;
			startedat_s = tv.tv_sec;
			started = True;
		}

		len = out->end - out->p;

		if (!g_driver_broken)
		{
			memset(&info, 0, sizeof(info));
			if (ioctl(g_dsp_fd, SNDCTL_DSP_GETOSPACE, &info) == -1)
			{
				perror("SNDCTL_DSP_GETOSPACE");
				return;
			}

			if (info.fragments == 0)
			{
				g_dsp_busy = 1;
				return;
			}

			if (info.fragments * info.fragsize < len
			    && info.fragments * info.fragsize > 0)
			{
				len = info.fragments * info.fragsize;
			}
		}


		len = write(g_dsp_fd, out->p, len);
		if (len == -1)
		{
			if (errno != EWOULDBLOCK)
				perror("write audio");
			g_dsp_busy = 1;
			return;
		}

		out->p += len;
		if (out->p == out->end)
		{
			long long duration;
			long elapsed;

			gettimeofday(&tv, NULL);
			duration = (out->size * (1000000 / (g_samplewidth * g_snd_rate)));
			elapsed = (tv.tv_sec - startedat_s) * 1000000 + (tv.tv_usec - startedat_us);

			if (elapsed >= (duration * 85) / 100)
			{
				rdpsnd_send_completion(packet->tick, packet->index);
				free(out->data);
				queue_lo = (queue_lo + 1) % MAX_QUEUE;
				started = False;
			}
			else
			{
				g_dsp_busy = 1;
				return;
			}
		}
	}
}
