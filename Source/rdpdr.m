/* -*- c-basic-offset: 8 -*-
   rdesktop: A Remote Desktop Protocol client.
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

/*
  Here are some resources, for your IRP hacking pleasure:

  http://cvs.sourceforge.net/viewcvs.py/mingw/w32api/include/ddk/winddk.h?view=markup

  http://win32.mvps.org/ntfs/streams.cpp

  http://www.acc.umu.se/~bosse/ntifs.h

  http://undocumented.ntinternals.net/UserMode/Undocumented%20Functions/NT%20Objects/File/

  http://us1.samba.org/samba/ftp/specs/smb-nt01.txt

  http://www.osronline.com/
*/

#import "CRDShared.h"
#import "CRDSession.h"

#import <unistd.h>
#import <sys/types.h>
#import <sys/time.h>
#import <dirent.h>		/* opendir, closedir, readdir */
#import <time.h>
#import <errno.h>
#import "rdesktop.h"

#define IRP_MJ_CREATE			0x00
#define IRP_MJ_CLOSE			0x02
#define IRP_MJ_READ			0x03
#define IRP_MJ_WRITE			0x04
#define	IRP_MJ_QUERY_INFORMATION	0x05
#define IRP_MJ_SET_INFORMATION		0x06
#define IRP_MJ_QUERY_VOLUME_INFORMATION	0x0a
#define IRP_MJ_DIRECTORY_CONTROL	0x0c
#define IRP_MJ_DEVICE_CONTROL		0x0e
#define IRP_MJ_LOCK_CONTROL             0x11

#define IRP_MN_QUERY_DIRECTORY          0x01
#define IRP_MN_NOTIFY_CHANGE_DIRECTORY  0x02

extern DEVICE_FNS serial_fns;
extern DEVICE_FNS printer_fns;
extern DEVICE_FNS parallel_fns;
extern DEVICE_FNS disk_fns;

static RDBOOL add_async_iorequest(RDConnectionRef conn, uint32 device, uint32 file, uint32 fid, uint32 major, uint32 length, DEVICE_FNS * fns, uint8 * buffer, uint32 offset);


// Return device_id for a given handle
int
get_device_index(RDConnectionRef conn, NTHandle handle)
{
	int i;
	for (i = 0; i < RDPDR_MAX_DEVICES; i++)
	{
		if (conn->rdpdrDevice[i].handle == handle)
			return i;
	}
	return -1;
}

// Converts a windows path to a unix path
void convert_to_unix_filename(char *filename)
{
	char *p;

	while ((p = strchr(filename, '\\')))
	{
		*p = '/';
	}
}

static RDBOOL rdpdr_handle_ok(RDConnectionRef conn, int device, int handle)
{
	switch (conn->rdpdrDevice[device].device_type)
	{
		case DEVICE_TYPE_PARALLEL:
		case DEVICE_TYPE_SERIAL:
		case DEVICE_TYPE_PRINTER:
		case DEVICE_TYPE_SCARD:
			if (conn->rdpdrDevice[device].handle != handle)
				return False;
			break;
		case DEVICE_TYPE_DISK:
			if (conn->fileInfo[handle].device_id != device)
				return False;
			break;
	}
	return True;
}

static void
rdpdr_send_connect(RDConnectionRef conn)
{
	uint8 magic[4] = "rDCC";
	RDStreamRef s;

	s = channel_init(conn, conn->rdpdrChannel, 12);
	out_uint8a(s, magic, 4);
	out_uint16_le(s, 1);	/* unknown */
	out_uint16_le(s, 5);
	out_uint32_be(s, 0x815ed39d);	/* IP address (use 127.0.0.1) 0x815ed39d */
	s_mark_end(s);
	channel_send(conn, s, conn->rdpdrChannel);
}


static void
rdpdr_send_name(RDConnectionRef conn)
{
	uint8 magic[4] = "rDNC";
	RDStreamRef s;
	uint32 hostlen;

	if (NULL == conn->rdpdrClientname)
	{
		conn->rdpdrClientname = conn->hostname;
	}
	hostlen = (strlen(conn->rdpdrClientname) + 1) * 2;

	s = channel_init(conn, conn->rdpdrChannel, 16 + hostlen);
	out_uint8a(s, magic, 4);
	out_uint16_le(s, 0x63);	/* unknown */
	out_uint16_le(s, 0x72);
	out_uint32(s, 0);
	out_uint32_le(s, hostlen);
	rdp_out_unistr(s, conn->rdpdrClientname, hostlen - 2);
	s_mark_end(s);
	channel_send(conn, s, conn->rdpdrChannel);
}

/* Returns the size of the payload of the announce packet */
static int
announcedata_size(RDConnectionRef conn)
{
	int size, i;
	RDPrinterInfo *printerinfo;

	size = 8;
	size += conn->numDevices * 0x14;

	for (i = 0; i < conn->numDevices; i++)
	{
		if (conn->rdpdrDevice[i].device_type == DEVICE_TYPE_PRINTER)
		{
			printerinfo = (RDPrinterInfo *) conn->rdpdrDevice[i].pdevice_data;
			printerinfo->bloblen =
				printercache_load_blob(printerinfo->printer, &(printerinfo->blob));

			size += 0x18;
			size += 2 * strlen(printerinfo->driver) + 2;
			size += 2 * strlen(printerinfo->printer) + 2;
			size += printerinfo->bloblen;
		}
	}

	return size;
}

static void
rdpdr_send_available(RDConnectionRef conn)
{

	uint8 magic[4] = "rDAD";
	uint32 driverlen, printerlen, bloblen;
	int i;
	RDStreamRef s;
	RDPrinterInfo *printerinfo;

	s = channel_init(conn, conn->rdpdrChannel, announcedata_size(conn));
	out_uint8a(s, magic, 4);
	out_uint32_le(s, conn->numDevices);

	for (i = 0; i < conn->numDevices; i++)
	{
		out_uint32_le(s, conn->rdpdrDevice[i].device_type);
		out_uint32_le(s, i);	/* RDP Device ID */
		/* Is it possible to use share names longer than 8 chars?
		   /astrand */
		out_uint8p(s, conn->rdpdrDevice[i].name, 8);

		switch (conn->rdpdrDevice[i].device_type)
		{
			case DEVICE_TYPE_PRINTER:
				printerinfo = (RDPrinterInfo *) conn->rdpdrDevice[i].pdevice_data;

				driverlen = 2 * strlen(printerinfo->driver) + 2;
				printerlen = 2 * strlen(printerinfo->printer) + 2;
				bloblen = printerinfo->bloblen;

				out_uint32_le(s, 24 + driverlen + printerlen + bloblen);	/* length of extra info */
				out_uint32_le(s, printerinfo->default_printer ? 2 : 0);
				out_uint8s(s, 8);	/* unknown */
				out_uint32_le(s, driverlen);
				out_uint32_le(s, printerlen);
				out_uint32_le(s, bloblen);
				rdp_out_unistr(s, printerinfo->driver, driverlen - 2);
				rdp_out_unistr(s, printerinfo->printer, printerlen - 2);
				out_uint8a(s, printerinfo->blob, bloblen);

				if (printerinfo->blob)
					xfree(printerinfo->blob);	/* Blob is sent twice if reconnecting */
				break;
			default:
				out_uint32(s, 0);
		}
	}

	s_mark_end(s);
	channel_send(conn, s, conn->rdpdrChannel);
}

static void
rdpdr_send_completion(RDConnectionRef conn, uint32 device, uint32 requestID, uint32 status, uint32 result, uint8 * buffer,
		      uint32 length)
{
	uint8 magic[4] = "rDCI";
	RDStreamRef s;

	s = channel_init(conn, conn->rdpdrChannel, 20 + length);
	out_uint8a(s, magic, 4);
	out_uint32_le(s, device);
	out_uint32_le(s, requestID);
	out_uint32_le(s, status);
	out_uint32_le(s, result);
	out_uint8p(s, buffer, length);
	s_mark_end(s);

#ifdef WITH_DEBUG_RDP5
	printf("--> rdpdr_send_completion\n");
	/* hexdump(s->channel_hdr + 8, s->end - s->channel_hdr - 8); */
#endif
	channel_send(conn, s, conn->rdpdrChannel);
}

static void
rdpdr_process_irp(RDConnectionRef conn, RDStreamRef s)
{
	uint32 result = 0,
		length = 0,
		desired_access = 0,
		request,
		file,
		info_level,
		buffer_len,
		requestID,
		major,
		minor,
		device,
		offset,
		bytes_in,
		bytes_out,
		error_mode,
		share_mode, disposition, total_timeout, interval_timeout, flags_and_attributes = 0;

	char filename[PATH_MAX];
	uint8 *buffer, *pst_buf;
	RDStream outStream;
	DEVICE_FNS *fns;
	RDBOOL r_blocking = True, w_blocking = True;
	NTStatus status = STATUS_INVALID_DEVICE_REQUEST;

	in_uint32_le(s, device);
	in_uint32_le(s, file);
	in_uint32_le(s, requestID);
	in_uint32_le(s, major);
	in_uint32_le(s, minor);

	buffer_len = 0;
	buffer = (uint8 *) xmalloc(1024);
	buffer[0] = 0;

	switch (conn->rdpdrDevice[device].device_type)
	{
		case DEVICE_TYPE_PRINTER:

			fns = &printer_fns;
			break;

		case DEVICE_TYPE_DISK:

			fns = &disk_fns;
			break;
			
		case DEVICE_TYPE_PARALLEL:
		case DEVICE_TYPE_SERIAL:
		case DEVICE_TYPE_SCARD:
		default:
			
			error("IRP for bad/unsupported device %ld\n", device);
			return;
	}

	switch (major)
	{
		case IRP_MJ_CREATE:

			in_uint32_be(s, desired_access);
			in_uint8s(s, 0x08);	/* unknown */
			in_uint32_le(s, error_mode);
			in_uint32_le(s, share_mode);
			in_uint32_le(s, disposition);
			in_uint32_le(s, flags_and_attributes);
			in_uint32_le(s, length);

			if (length && (length / 2) < 256)
			{
				rdp_in_unistr(s, filename, length);
				convert_to_unix_filename(filename);
			}
			else
			{
				filename[0] = 0;
			}

			if (!fns->create)
			{
				status = STATUS_NOT_SUPPORTED;
				break;
			}

			status = fns->create(conn, device, desired_access, share_mode, disposition,
					     flags_and_attributes, filename, &result);
			buffer_len = 1;
			break;

		case IRP_MJ_CLOSE:
			if (!fns->close)
			{
				status = STATUS_NOT_SUPPORTED;
				break;
			}

			status = fns->close(conn, file);
			break;

		case IRP_MJ_READ:

			if (!fns->read)
			{
				status = STATUS_NOT_SUPPORTED;
				break;
			}

			in_uint32_le(s, length);
			in_uint32_le(s, offset);
#if WITH_DEBUG_RDP5
			DEBUG(("RDPDR IRP Read (length: %d, offset: %d)\n", length, offset));
#endif
			if (!rdpdr_handle_ok(conn, device, file))
			{
				status = STATUS_INVALID_HANDLE;
				break;
			}

			if (r_blocking)	/* Complete read immediately */
			{
				buffer = (uint8 *) xrealloc((void *) buffer, length);
				if (!buffer)
				{
					status = STATUS_CANCELLED;
					break;
				}
				status = fns->read(conn, file, buffer, length, offset, &result);
				buffer_len = result;
				break;
			}

			/* Add request to table */
			pst_buf = (uint8 *) xmalloc(length);
			if (!pst_buf)
			{
				status = STATUS_CANCELLED;
				break;
			}
			
			if (add_async_iorequest(conn, device, file, requestID, major, length, fns, pst_buf, offset))
			{
				status = STATUS_PENDING;
				break;
			}

			status = STATUS_CANCELLED;
			break;
		case IRP_MJ_WRITE:

			buffer_len = 1;

			if (!fns->write)
			{
				status = STATUS_NOT_SUPPORTED;
				break;
			}

			in_uint32_le(s, length);
			in_uint32_le(s, offset);
			in_uint8s(s, 0x18);
#if WITH_DEBUG_RDP5
			DEBUG(("RDPDR IRP Write (length: %d)\n", result));
#endif
			if (!rdpdr_handle_ok(conn, device, file))
			{
				status = STATUS_INVALID_HANDLE;
				break;
			}

			if (w_blocking)	/* Complete immediately */
			{
				status = fns->write(conn, file, s->p, length, offset, &result);
				break;
			}

			/* Add to table */
			pst_buf = (uint8 *) xmalloc(length);
			if (!pst_buf)
			{
				status = STATUS_CANCELLED;
				break;
			}

			in_uint8a(s, pst_buf, length);

			if (add_async_iorequest(conn, device, file, requestID, major, length, fns, pst_buf, offset))
			{
				status = STATUS_PENDING;
				break;
			}

			status = STATUS_CANCELLED;
			break;

		case IRP_MJ_QUERY_INFORMATION:

			if (conn->rdpdrDevice[device].device_type != DEVICE_TYPE_DISK)
			{
				status = STATUS_INVALID_HANDLE;
				break;
			}
			in_uint32_le(s, info_level);

			outStream.data = outStream.p = buffer;
			outStream.size = sizeof(buffer);
			status = disk_query_information(conn, file, info_level, &outStream);
			result = buffer_len = outStream.p - outStream.data;

			break;

		case IRP_MJ_SET_INFORMATION:

			if (conn->rdpdrDevice[device].device_type != DEVICE_TYPE_DISK)
			{
				status = STATUS_INVALID_HANDLE;
				break;
			}

			in_uint32_le(s, info_level);

			outStream.data = outStream.p = buffer;
			outStream.size = sizeof(buffer);
			status = disk_set_information(conn, file, info_level, s, &outStream);
			result = buffer_len = outStream.p - outStream.data;
			break;

		case IRP_MJ_QUERY_VOLUME_INFORMATION:

			if (conn->rdpdrDevice[device].device_type != DEVICE_TYPE_DISK)
			{
				status = STATUS_INVALID_HANDLE;
				break;
			}

			in_uint32_le(s, info_level);

			outStream.data = outStream.p = buffer;
			outStream.size = sizeof(buffer);
			status = disk_query_volume_information(conn, file, info_level, &outStream);
			result = buffer_len = outStream.p - outStream.data;
			break;

		case IRP_MJ_DIRECTORY_CONTROL:

			if (conn->rdpdrDevice[device].device_type != DEVICE_TYPE_DISK)
			{
				status = STATUS_INVALID_HANDLE;
				break;
			}

			switch (minor)
			{
				case IRP_MN_QUERY_DIRECTORY:
					
					in_uint32_le(s, info_level);
					in_uint8s(s, 1);
					in_uint32_le(s, length);
					in_uint8s(s, 0x17);
					if (length && length < 2 * 255)
					{
						rdp_in_unistr(s, filename, length);
						convert_to_unix_filename(filename);
					}
					else
					{
						filename[0] = 0;
					}
					outStream.data = outStream.p = buffer;
					outStream.size = sizeof(buffer);
					status = disk_query_directory(conn, file, info_level, filename, &outStream);
					result = buffer_len = outStream.p - outStream.data;
					if (!buffer_len)
						buffer_len++;
					break;

				case IRP_MN_NOTIFY_CHANGE_DIRECTORY:
					// Unsupported by CoRD
					status = STATUS_NOT_SUPPORTED;
					
					/*
					in_uint32_le(s, info_level);

					conn->notifyStamp = True;

					status = disk_create_notify(conn, file, info_level);
					result = 0;

					if (status == STATUS_PENDING)
						add_async_iorequest(conn, device, file, requestID, major, length, fns, NULL, 0);
					*/
					break;

				default:

					status = STATUS_INVALID_PARAMETER;
					/* JIF */
					unimpl("IRP major=0x%x minor=0x%x\n", major, minor);
			}
			break;

		case IRP_MJ_DEVICE_CONTROL:

			if (!fns->device_control)
			{
				status = STATUS_NOT_SUPPORTED;
				break;
			}

			in_uint32_le(s, bytes_out);
			in_uint32_le(s, bytes_in);
			in_uint32_le(s, request);
			in_uint8s(s, 0x14);

			buffer = (uint8 *) xrealloc((void *) buffer, bytes_out + 0x14);
			if (!buffer)
			{
				status = STATUS_CANCELLED;
				break;
			}

			outStream.data = outStream.p = buffer;
			outStream.size = sizeof(buffer);
			status = fns->device_control(conn, file, request, s, &outStream);
			result = buffer_len = outStream.p - outStream.data;

			/* Serial SERIAL_WAIT_ON_MASK */
			if (status == STATUS_PENDING)
			{
				if (add_async_iorequest (conn, device, file, requestID, major, length, fns, NULL, 0))
				{
					status = STATUS_PENDING;
					break;
				}
			}
			break;


		case IRP_MJ_LOCK_CONTROL:

			if (conn->rdpdrDevice[device].device_type != DEVICE_TYPE_DISK)
			{
				status = STATUS_INVALID_HANDLE;
				break;
			}

			in_uint32_le(s, info_level);

			outStream.data = outStream.p = buffer;
			outStream.size = sizeof(buffer);
			/* FIXME: Perhaps consider actually *do*
			   something here :-) */
			status = STATUS_SUCCESS;
			result = buffer_len = outStream.p - outStream.data;
			break;

		default:
			unimpl("IRP major=0x%x minor=0x%x\n", major, minor);
			break;
	}

	if (status != STATUS_PENDING)
	{
		rdpdr_send_completion(conn, device, requestID, status, result, buffer, buffer_len);
	}
	if (buffer)
		xfree(buffer);
	buffer = NULL;
}

// Status: Finished. Shouldn't need changes.
static void rdpdr_send_clientcapabilty(RDConnectionRef conn)
{
	uint8 magic[4] = "rDPC";
	RDStreamRef s;

	s = channel_init(conn, conn->rdpdrChannel, 0x50);
	out_uint8a(s, magic, 4);
	out_uint32_le(s, 5);	/* count */
	out_uint16_le(s, 1);	/* first */
	out_uint16_le(s, 0x28);	/* length */
	out_uint32_le(s, 1);
	out_uint32_le(s, 2);
	out_uint16_le(s, 2);
	out_uint16_le(s, 5);
	out_uint16_le(s, 1);
	out_uint16_le(s, 5);
	out_uint16_le(s, 0xFFFF);
	out_uint16_le(s, 0);
	out_uint32_le(s, 0);
	out_uint32_le(s, 3);
	out_uint32_le(s, 0);
	out_uint32_le(s, 0);
	out_uint16_le(s, 2);	/* second */
	out_uint16_le(s, 8);	/* length */
	out_uint32_le(s, 1);
	out_uint16_le(s, 3);	/* third */
	out_uint16_le(s, 8);	/* length */
	out_uint32_le(s, 1);
	out_uint16_le(s, 4);	/* fourth */
	out_uint16_le(s, 8);	/* length */
	out_uint32_le(s, 1);
	out_uint16_le(s, 5);	/* fifth */
	out_uint16_le(s, 8);	/* length */
	out_uint32_le(s, 1);

	s_mark_end(s);
	channel_send(conn, s, conn->rdpdrChannel);
}

static void
rdpdr_process(RDConnectionRef conn, RDStreamRef s)
{
	uint32 handle;
	uint8 *magic;

#if WITH_DEBUG_RDP5
	printf("--- rdpdr_process ---\n");
	hexdump(s->p, s->end - s->p);
#endif
	in_uint8p(s, magic, 4);

	if ((magic[0] == 'r') && (magic[1] == 'D'))
	{
		if ((magic[2] == 'R') && (magic[3] == 'I'))
		{
			rdpdr_process_irp(conn, s);
			return;
		}
		if ((magic[2] == 'n') && (magic[3] == 'I'))
		{
			rdpdr_send_connect(conn);
			rdpdr_send_name(conn);
			return;
		}
		if ((magic[2] == 'C') && (magic[3] == 'C'))
		{
			// connect from server
			rdpdr_send_clientcapabilty(conn);
			rdpdr_send_available(conn);
			return;
		}
		if ((magic[2] == 'r') && (magic[3] == 'd'))
		{
			/* connect to a specific resource */
			in_uint32(s, handle);
			
#if WITH_DEBUG_RDP5
			DEBUG(("RDPDR: Server connected to resource %d\n", handle));
#endif
			return;
		}
		if ((magic[2] == 'P') && (magic[3] == 'S'))
		{
			/* server capability */
			return;
		}
	}
	if ((magic[0] == 'R') && (magic[1] == 'P'))
	{
		if ((magic[2] == 'C') && (magic[3] == 'P'))
		{
			printercache_process(s);
			return;
		}
	}
	unimpl("RDPDR packet type %c%c%c%c\n", magic[0], magic[1], magic[2], magic[3]);
}

int
rdpdr_init(RDConnectionRef conn)
{
	if (conn->numDevices > 0)
	{
		conn->rdpdrChannel =
			channel_register(conn, "rdpdr",
					 CHANNEL_OPTION_INITIALIZED | CHANNEL_OPTION_COMPRESS_RDP,
					 rdpdr_process);
	}

	return (conn->rdpdrChannel != NULL);
}


#pragma mark -
#pragma mark Asynchronous IO

// I thought I would replace the select() async method with NSFileHandle, but NSFH doesn't all the things I needed, so this is all going to be reverted to use select (currently, none of this is used at all because non-blocking IO is disabled in process_irp). If I want to re-implement non-blocking IO, I'll use a new thread that simply spins on select() and sends a message to a mach port on the connection thread when it has new data

/* Add a new io request to the table containing pending io requests so it won't block rdesktop */
static RDBOOL
add_async_iorequest(RDConnectionRef conn, uint32 device, uint32 file, uint32 fid, uint32 major, uint32 length, DEVICE_FNS * fns, uint8 * buffer, uint32 offset) 
{
	NSLog(@"Adding IO-req for fd %d", file);
	
	RDAsynchronousIORequest *newRequest = calloc(1, sizeof(RDAsynchronousIORequest));
	newRequest->device = device;
	newRequest->fd = file;
	newRequest->fid = fid;
	newRequest->major = major;
	newRequest->length = length;
	newRequest->partial_len = 0;
	newRequest->fns = fns;
	newRequest->buffer = buffer;
	newRequest->offset = offset;
	newRequest->next = NULL;
	
	// Place it in the file info's request linked list
	RDAsynchronousIORequest *iorq = conn->fileInfo[file].firstIORequest;
	
	if (iorq == NULL)
		conn->fileInfo[file].firstIORequest = newRequest;
	else
	{
		while (iorq->next != NULL)
			iorq = iorq->next;
		
		iorq->next = newRequest;	
	}

	// Finally, schedule it with the session controller so it will alert rdpdr when data is avaialble to read
	//[conn->controller scheduleAsyncIO:iorq];
	
	return True;
}

RDAsynchronousIORequest *
rdpdr_remove_iorequest(RDConnectionRef conn, uint32 fd, RDAsynchronousIORequest *requestToRemove)
{
	NSLog(@"Removing IO-req for fd %d", fd);

	if (requestToRemove == NULL)
		return NULL;
		
	if (requestToRemove->buffer)
		xfree(requestToRemove->buffer);

	RDAsynchronousIORequest *iorq = conn->fileInfo[fd].firstIORequest, *prev;

	while (iorq != NULL)
	{
		if (iorq == requestToRemove)
		{
			prev->next = iorq->next;
			xfree(requestToRemove);
			return iorq->next;
		}
		
		prev = iorq;
		iorq = iorq->next;
	} 
	
	return NULL;
}

void 
rdpdr_io_available_event(RDConnectionRef conn, uint32 file, RDAsynchronousIORequest *iorq)
{
	NSLog(@"Data became available for fd %d", file);

	if (iorq == NULL)
	{
		iorq = conn->fileInfo[file].firstIORequest;
		
		while ( (iorq != NULL) && (iorq->major != IRP_MJ_READ))
			iorq = iorq->next;
	}
	
	if (iorq == NULL)
	{
		NSLog(@"Couldn't find a matching iorq for file %u", file);
		return;
	}	
	
		
	if (iorq->aborted)
	{
		rdpdr_remove_iorequest(conn, file, iorq);
		return;
	}
	
	uint32 result, req_size, status;
	

	DEVICE_FNS *fns = iorq->fns;
	switch (iorq->major)
	{
		case IRP_MJ_READ:
			req_size = ((iorq->length - iorq->partial_len) > 8192) ? 8192 : (iorq->length - iorq->partial_len);
			
			// Never read larger chunks than 8k - chances are that it will block
			status = fns->read(conn, iorq->fd, iorq->buffer + iorq->partial_len, req_size, iorq->offset, &result);

			if (result > 0)
			{
				iorq->partial_len += result;
				iorq->offset += result;
			}
			
			#if WITH_DEBUG_RDP5
				DEBUG(("RDPDR: %d bytes of data read\n", result));
			#endif
			
			// If all data was transfered or EOF was hit, complete the IO request
			if ((iorq->partial_len == iorq->length) || (result == 0))
			{
				#if WITH_DEBUG_RDP5
					DEBUG(("RDPDR: AIO total %u bytes read of %u\n", iorq->partial_len, iorq->length));
				#endif
				
				rdpdr_send_completion(conn, iorq->device, iorq->fid, status, iorq->partial_len, iorq->buffer, iorq->partial_len);
				rdpdr_remove_iorequest(conn, iorq->fd, iorq);
			}
			else
			{
			//	[conn->controller scheduleAsyncIO:iorq];
			}
			
			break;
		/*
		case IRP_MJ_WRITE:
			req_size = ((iorq->length - iorq->partial_len) > 8192) ? 8192 : (iorq->length - iorq->partial_len);

			// Never write larger chunks than 8k - chances are that it will block
			status = fns->write(conn, iorq->fd, iorq->buffer + iorq->partial_len, req_size, iorq->offset, &result);

			if (result > 0)
			{
				iorq->partial_len += result;
				iorq->offset += result;
			}

			#if WITH_DEBUG_RDP5
				DEBUG(("RDPDR: %d bytes of data written\n", result));
			#endif
			
			// If all data was transfered or write failed, complete the IO
			if ((iorq->partial_len == iorq->length) || (result == 0))
			{
				#if WITH_DEBUG_RDP5
					DEBUG(("RDPDR: AIO total %u bytes written of %u\n", iorq->partial_len, iorq->length));
				#endif
				
				rdpdr_send_completion(conn, iorq->device, iorq->fid, status, iorq->partial_len, (uint8 *) "", 1);
				rdpdr_remove_iorequest(conn, iorq->fd, iorq);
			}

			break;
		*/
		default:
			unimpl("IO completion for bad major command: 0x%x", iorq->major);
			break;
	}

	//	Disk change notifies aren't supported by CoRD

}



/* Abort a pending io request for a given handle and major */
RDBOOL
rdpdr_abort_io(RDConnectionRef conn, uint32 fd, uint32 major, NTStatus status)
{
	uint32 result;
	RDAsynchronousIORequest *iorq;

	iorq = conn->fileInfo[fd].firstIORequest;
	while (iorq != NULL)
	{
		// Only remove from table when major is not set, or when correct major is supplied. Abort read should not abort a write io request.
		if ((iorq->fd == fd) && (major == 0 || iorq->major == major))
		{
			result = 0;
			rdpdr_send_completion(conn, iorq->device, iorq->fid, status, result, (uint8 *) "", 1);

			iorq->aborted = 1;
			return True;
		}

		iorq = iorq->next;
	}
	
	return False;
}
