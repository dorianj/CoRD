/*	Copyright (c) 2007 Dorian Johnson <arcadiclife@gmail.com>
	
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

// Replaces: rdpdr.c

#import "rdesktop.h"
#import "disk.h"
#import "CRDShared.h"
#import "CRDSessionDeviceManager.h"

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


static void rdpdr_process(RDConnectionRef conn, RDStreamRef s);

static void rdpdr_send_clientcapabilty(RDConnectionRef conn);
static void rdpdr_send_connect(RDConnectionRef conn);
static void rdpdr_send_name(RDConnectionRef conn);
static int announcedata_size(RDConnectionRef conn);
static void rdpdr_send_available(RDConnectionRef conn);
static void rdpdr_send_completion(RDConnectionRef conn, uint32 device, uint32 id, uint32 status, uint32 result, uint8 * buffer, uint32 length);
static void rdpdr_process_irp(RDConnectionRef conn, RDStreamRef s);

#pragma mark -

int rdpdr_init(RDConnectionRef conn)
{
	if (conn->numDevices > 0)
	{
		conn->rdpdrChannel = channel_register(conn, "rdpdr", CHANNEL_OPTION_INITIALIZED | CHANNEL_OPTION_COMPRESS_RDP, rdpdr_process);
	}

	return (conn->rdpdrChannel != NULL);
}

// Status: finished
static void rdpdr_process(RDConnectionRef conn, RDStreamRef s)
{
	uint32 handle;
	uint8 *magic;

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
			// connect to a specific resource
			in_uint32(s, handle);
			
			return;
		}
		if ((magic[2] == 'P') && (magic[3] == 'S'))
		{
			// server capability
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

// Status: finished
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


// Status: needs rewrite
int get_device_index(RDConnectionRef conn, NTHandle handle)
{


	return -1;
}

// Status: needs rewrite. use nsstring?
void convert_to_unix_filename(char *filename)
{

}


// Status: should be OK
static void rdpdr_send_connect(RDConnectionRef conn)
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

// Status: should be OK
static void rdpdr_send_name(RDConnectionRef conn)
{
	uint8 magic[4] = "rDNC";
	RDStreamRef s;
	uint32 hostlen;

	if (conn->rdpdrClientname == NULL)
		conn->rdpdrClientname = conn->hostname;

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

// Status: should be OK
static int announcedata_size(RDConnectionRef conn)
{
	int size, i;
	RDPrinterInfo *printerinfo;

	size = 8;
	size += conn->numDevices * 0x14;

	for (i = 0; i < conn->numDevices; i++)
	{
		if (conn->rdpdrDevice[i].deviceType == DEVICE_TYPE_PRINTER)
		{
			printerinfo = (RDPrinterInfo *) conn->rdpdrDevice[i].deviceSpecificInfo;
			printerinfo->bloblen = printercache_load_blob(printerinfo->printer, &(printerinfo->blob));

			size += 0x18;
			size += 2 * strlen(printerinfo->driver) + 2;
			size += 2 * strlen(printerinfo->printer) + 2;
			size += printerinfo->bloblen;
		}
	}

	return size;
}

// Status: should be ok
static void rdpdr_send_available(RDConnectionRef conn)
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
		out_uint32_le(s, conn->rdpdrDevice[i].deviceType);
		out_uint32_le(s, i);	/* RDP Device ID */

		out_uint8p(s, conn->rdpdrDevice[i].rdpName, 8);

		switch (conn->rdpdrDevice[i].deviceType)
		{
			case DEVICE_TYPE_PRINTER:
				printerinfo = (RDPrinterInfo *) conn->rdpdrDevice[i].deviceSpecificInfo;

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

// status: should be ok, will be used by steam: handler
static void rdpdr_send_completion(RDConnectionRef conn, uint32 device, uint32 id, uint32 status, uint32 result, uint8 * buffer, uint32 length)
{
	uint8 magic[4] = "rDCI";
	RDStreamRef s;

	s = channel_init(conn, conn->rdpdrChannel, 20 + length);
	out_uint8a(s, magic, 4);
	out_uint32_le(s, device);
	out_uint32_le(s, id);
	out_uint32_le(s, status);
	out_uint32_le(s, result);
	out_uint8p(s, buffer, length);
	s_mark_end(s);

	channel_send(conn, s, conn->rdpdrChannel);
}


// Needs big rewrite
static void rdpdr_process_irp(RDConnectionRef conn, RDStreamRef s)
{
	uint32 result = 0, length = 0, desired_access = 0, request, file, info_level, buffer_len, requestID, major, minor, deviceID, offset, bytes_in, bytes_out, error_mode, share_mode, disposition, total_timeout, interval_timeout, flags_and_attributes = 0;

	char filename[PATH_MAX];
	uint8 *buffer, *pst_buf;
	RDStream outputStream;
	BOOL useBlockingIO = YES;
	NTStatus status = STATUS_INVALID_DEVICE_REQUEST;

	in_uint32_le(s, deviceID);
	in_uint32_le(s, file);
	in_uint32_le(s, requestID);
	in_uint32_le(s, major);
	in_uint32_le(s, minor);

	buffer_len = 0;
	buffer = (uint8 *) xmalloc(1024);
	buffer[0] = '\0';

	switch (conn->rdpdrDevice[deviceID].deviceType)
	{
		case DEVICE_TYPE_PRINTER:
			break;

		case DEVICE_TYPE_DISK:
			useBlockingIO = NO;
			break;
			
		case DEVICE_TYPE_PARALLEL:
		case DEVICE_TYPE_SERIAL:
		case DEVICE_TYPE_SCARD:
		default:
			error("IRP for unsupported device %ld\n", deviceID);
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
				filename[0] = '\0';
			}
		
			status = [conn->deviceManager handleCreate:&(conn->rdpdrDevice[deviceID]) access:desired_access shareMode:share_mode disposition:disposition flags:flags_and_attributes filename:filename handle:&result];

			buffer_len = 1;
			break;

		case IRP_MJ_CLOSE:

			status = [conn->deviceManager handleClose:file];
			break;

		case IRP_MJ_READ:

			in_uint32_le(s, length);
			in_uint32_le(s, offset);
			
			#if WITH_DEBUG_RDP5
				DEBUG(("RDPDR IRP Read (length: %d, offset: %d)\n", length, offset));
			#endif
			
			if (![conn->deviceManager isValidHandle:file forDevice:&(conn->rdpdrDevice[deviceID])])
			{
				status = STATUS_INVALID_HANDLE;
				break;
			}

			if (useBlockingIO)	/* Complete read immediately */
			{
				buffer = (uint8 *) xrealloc((void *) buffer, length);
				if (!buffer)
				{
					status = STATUS_CANCELLED;
					break;
				}
				status = [conn->deviceManager handleRead:file intoBuffer:buffer length:length offset:offset result:&result];

				buffer_len = result;
				break;
			}

			// Defer the request
			if ([conn->deviceManager addAsynchronousRead:&(conn->rdpdrDevice[deviceID]) handle:file requestID:requestID fileOperation:major length:length offset:offset])
			{
				status = STATUS_PENDING;
				break;
			}
			
			status = STATUS_CANCELLED;
			break;
			
		case IRP_MJ_WRITE:

			buffer_len = 1;

			in_uint32_le(s, length);
			in_uint32_le(s, offset);
			in_uint8s(s, 0x18);
			
			#if WITH_DEBUG_RDP5
				DEBUG(("RDPDR IRP Write (length: %d)\n", result));
			#endif
			
			if (![conn->deviceManager isValidHandle:file forDevice:&(conn->rdpdrDevice[deviceID])])
			{
				status = STATUS_INVALID_HANDLE;
				break;
			}

			if (useBlockingIO)
			{
				status = [conn->deviceManager handleWrite:file data:s->p length:length offset:offset result:&result];
				break;
			}

			// Defer the request
			pst_buf = (uint8 *) xmalloc(length);
			if (!pst_buf)
			{
				status = STATUS_CANCELLED;
				break;
			}

			in_uint8a(s, pst_buf, length);
			
			if ([conn->deviceManager addAsynchronousWrite:conn->rdpdrDevice[deviceID] handle:file requestID:requestID fileOperation:major length:length offset:offset data:pst_buf])
			{
				status = STATUS_PENDING;
				break;
			}

			status = STATUS_CANCELLED;
			break;

		case IRP_MJ_QUERY_INFORMATION:

			if (conn->rdpdrDevice[deviceID].deviceType != DEVICE_TYPE_DISK)
			{
				status = STATUS_INVALID_HANDLE;
				break;
			}
			in_uint32_le(s, info_level);

			outputStream.data = outputStream.p = buffer;
			outputStream.size = sizeof(buffer);
			status = [conn->deviceManager queryFileInformation:file infoType:info_level intoStream:&outputStream];
			result = buffer_len = outputStream.p - outputStream.data;

			break;

		case IRP_MJ_SET_INFORMATION:

			if (conn->rdpdrDevice[deviceID].deviceType != DEVICE_TYPE_DISK)
			{
				status = STATUS_INVALID_HANDLE;
				break;
			}

			in_uint32_le(s, info_level);

			outputStream.data = outputStream.p = buffer;
			outputStream.size = sizeof(buffer);
			status = [conn->deviceManager setFileInformation:file infoType:info_level fromStream:s]; 
			
			result = buffer_len = outputStream.p - outputStream.data;
			break;

		case IRP_MJ_QUERY_VOLUME_INFORMATION:

			if (conn->rdpdrDevice[deviceID].deviceType != DEVICE_TYPE_DISK)
			{
				status = STATUS_INVALID_HANDLE;
				break;
			}

			in_uint32_le(s, info_level);

			outputStream.data = outputStream.p = buffer;
			outputStream.size = sizeof(buffer);
			status = [conn->deviceManager queryVolumeInformation:file infoType:info_level intoStream:&outputStream];

			result = buffer_len = outputStream.p - outputStream.data;
			break;

		case IRP_MJ_DIRECTORY_CONTROL:

			if (conn->rdpdrDevice[deviceID].deviceType != DEVICE_TYPE_DISK)
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
					outputStream.data = outputStream.p = buffer;
					outputStream.size = sizeof(buffer);
					status = [conn->deviceManager queryDirectory:file infoType:info_level filename:filename intoStream:&outputStream];
					result = buffer_len = outputStream.p - outputStream.data;
					if (!buffer_len)
						buffer_len++;
					break;

				case IRP_MN_NOTIFY_CHANGE_DIRECTORY:

					in_uint32_le(s, info_level);	/* notify mask */

					status = STATUS_NOT_SUPPORTED;
					
					/*conn->notifyStamp = True;

					status = disk_create_notify(file, info_level);
					result = 0;

					if (status == STATUS_PENDING)
						add_async_iorequest(device, file, requestID, major, length, fns, 0, 0, NULL, 0);
					*/
					break;

				default:

					status = STATUS_INVALID_PARAMETER;
					/* JIF */
					unimpl("IRP major=0x%x minor=0x%x\n", major, minor);
			}
			break;

		case IRP_MJ_DEVICE_CONTROL:
		
			status = STATUS_NOT_SUPPORTED;
			break;

		case IRP_MJ_LOCK_CONTROL:

			if (conn->rdpdrDevice[deviceID].deviceType != DEVICE_TYPE_DISK)
			{
				status = STATUS_INVALID_HANDLE;
				break;
			}

			in_uint32_le(s, info_level);

			outputStream.data = outputStream.p = buffer;
			outputStream.size = sizeof(buffer);
			
			/* FIXME: Perhaps consider actually *doing* something here :-) */
			
			status = STATUS_SUCCESS;
			result = buffer_len = outputStream.p - outputStream.data;
			break;

		default:
			unimpl("IRP major=0x%x minor=0x%x\n", major, minor);
			break;
	}

	if (status != STATUS_PENDING)
	{
		rdpdr_send_completion(conn, deviceID, requestID, status, result, buffer, buffer_len);
	}

	xfree(buffer);
	buffer = NULL;
}

// need an equivilant, but not this
/*void rdpdr_add_fds(RDConnectionRef conn, int *n, fd_set * rfds, fd_set * wfds, struct timeval *tv, RDBOOL * timeout)
{

}*/

// need an equivilant, but not this
/*struct async_iorequest * rdpdr_remove_iorequest(RDConnectionRef conn, struct async_iorequest *prev, struct async_iorequest *iorq)
{

	return NULL;
}*/

/*RDBOOL rdpdr_abort_io(RDConnectionRef conn, uint32 fd, uint32 major, NTStatus status)
{
	
	return True;
}*/

// don't need
//static void _rdpdr_check_fds(RDConnectionRef conn, fd_set * rfds, fd_set * wfds, RDBOOL timed_out)

// don't need
//void rdpdr_check_fds(RDConnectionRef conn, fd_set * rfds, fd_set * wfds, RDBOOL timed_out)



#pragma mark -
#pragma mark Shared


// These should be somewhere else, like a category of the related Cocoa class

inline void RDMakeFileTimeFromDate(NSDate *date, unsigned int *high, unsigned int *low)
{
	unsigned long long ticks = ([date timeIntervalSince1970] + 11644473600) * 10000000;
	
	*low = (uint32) ticks;
	*high = (uint32) (ticks >> 32);
} 



BOOL RDPathIsHidden(NSString *path) 
{
	CFURLRef fileURL = CFURLCreateWithString(NULL, (CFStringRef)[@"file://" stringByAppendingString:path], NULL);	
	if (fileURL)
	{
		LSItemInfoRecord itemInfo;
		LSCopyItemInfoForURL(fileURL, kLSRequestAllFlags, &itemInfo);
		CFRelease(fileURL);	
		return itemInfo.flags & kLSItemInfoIsInvisible;
	}

	return NO;
}






























