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

#import "CRDSessionDeviceManager.h"

#import "rdesktop.h"
#import "disk.h" 

@implementation CRDSessionDeviceManager 



// 'handle' in the method name doesn't refer to an NTHandle. These simply either do the action or pass it off to printer
- (NTStatus)handleCreate:(RDRedirectedDeviceRef)device access:(unsigned)access shareMode:(unsigned)shareMode disposition:(unsigned)disposition flags:(unsigned)flags filename:(char *)filename handle:(NTHandle *)retHandle
{

	return STATUS_SUCCESS;
}

- (NTStatus)handleClose:(NTHandle)handle
{

	return STATUS_SUCCESS;
}

- (NTStatus)handleRead:(NTHandle)handle intoBuffer:(unsigned char *)buffer length:(unsigned)length offset:(unsigned)offset result:(unsigned *)retResult
{


	return STATUS_SUCCESS;
}

- (NTStatus)handleWrite:(NTHandle)handle data:(unsigned char *)toBeWritten length:(unsigned)length offset:(unsigned)offset result:(unsigned *)retResult
{

	return STATUS_SUCCESS;
}
	
	
// These two replace add_async_iorequest
- (BOOL)addAsynchronousRead:(RDRedirectedDeviceRef)device handle:(NTHandle)handle requestID:(unsigned)requestID fileOperation:(unsigned)op length:(unsigned)length offset:(unsigned)offset
{

	return YES;
}
	
- (BOOL)addAsynchronousRead:(RDRedirectedDeviceRef)device handle:(NTHandle)handle requestID:(unsigned)requestID fileOperation:(unsigned)op length:(unsigned)length offset:(unsigned)offset data:(unsigned char *)toBeWritten
{


	return YES;
}
	
	
// replaces rdpdr_handle_ok
- (BOOL)isValidHandle:(NTHandle)handle forDevice:(RDRedirectedDeviceRef)device
{
	if (device->deviceType == DEVICE_TYPE_DISK)
		return YES; // xxx: needs to check file table for handle
	else if (device->deviceType == DEVICE_TYPE_PRINTER)
		return device->rdpHandle == handle;
	else
		return NO;
}

// replaces disk_query_information
- (NTStatus)queryFileInformation:(NTHandle)handle infoType:(unsigned)infoType intoStream:(RDStreamRef)outputStream
{
	NSString *filePath = nil; // xxx: need to get path from handle
	NSDictionary *fileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:filePath traverseLink:YES],  *fileSystemAttributes;
	unsigned int fileFlags = 0, ft_high, ft_low; 
	
	if (fileAttributes == nil)
	{
		NSLog(@"Couldn't get file attributes for '%@'.", filePath);
		out_uint8(outputStream, 0);
		return STATUS_ACCESS_DENIED;
	}

	BOOL isDirectory = [[fileAttributes objectForKey:NSFileType] isEqual:NSFileTypeDirectory];

	if (isDirectory)
		fileFlags |= FILE_ATTRIBUTE_DIRECTORY;

	if (RDPathIsHidden(filePath))
		fileFlags |= FILE_ATTRIBUTE_HIDDEN;

	if (!fileFlags)
		fileFlags |= FILE_ATTRIBUTE_NORMAL;

	if ([[fileAttributes objectForKey:NSFileImmutable] boolValue])
		fileFlags |= FILE_ATTRIBUTE_READONLY;


	/* Return requested data */
	switch (infoType)
	{
		case FileBasicInformation:
			RDMakeFileTimeFromDate([fileAttributes objectForKey:NSFileCreationDate], &ft_high, &ft_low);
			out_uint32_le(outputStream, ft_low);	/* create_access_time */
			out_uint32_le(outputStream, ft_high);

			// xxx: unfinished: currently using modification time for everything
			RDMakeFileTimeFromDate([fileAttributes objectForKey:NSFileModificationDate], &ft_high, &ft_low);
			out_uint32_le(outputStream, ft_low);	/* last_access_time */
			out_uint32_le(outputStream, ft_high);

			out_uint32_le(outputStream, ft_low);	/* last_write_time */
			out_uint32_le(outputStream, ft_high);
			
			out_uint32_le(outputStream, ft_low);	/* last_change_time */
			out_uint32_le(outputStream, ft_high);

			out_uint32_le(outputStream, fileFlags);
			break;

		case FileStandardInformation:
			fileSystemAttributes = [[NSFileManager defaultManager] fileSystemAttributesAtPath:filePath];
			
			out_nsnumber_uint32_le(outputStream, [fileSystemAttributes objectForKey:NSFileSystemSize]);	/* Allocation size */
			out_uint32_le(outputStream, 0);
			out_nsnumber_uint32_le(outputStream, [fileSystemAttributes objectForKey:NSFileSystemSize]);	/* End of file */
			out_uint32_le(outputStream, 0);
			out_uint32_le(outputStream, 0);	/* Number of links - xxx: unimpl, was filestat.st_nlink */
			out_uint8(outputStream, 0);	/* Delete pending */
			out_uint8(outputStream, isDirectory ? 1 : 0);	/* Directory */
			break;

		case FileObjectIdInformation:

			out_uint32_le(outputStream, fileFlags);	/* File Attributes */
			out_uint32_le(outputStream, 0);	/* Reparse Tag */
			break;

		default:

			unimpl("IRP Query (File) Information class: 0x%x\n", infoType);
			return STATUS_INVALID_PARAMETER;
	}
	return STATUS_SUCCESS;

}

// replaces disk_query_directory - UND
- (NTStatus)queryDirectory:(NTHandle)handle infoType:(unsigned)infoType filename:(unsigned char *)filename intoStream:(RDStreamRef)outputStream
{


	return STATUS_SUCCESS;
}

// replaces disk_set_information
- (NTStatus)setFileInformation:(NTHandle)handle infoType:(unsigned)infoType fromStream:(RDStreamRef)inputStream
{


	return STATUS_SUCCESS;
}

// replaces disk_query_volume_information
- (NTStatus)queryVolumeInformation:(NTHandle)file infoType:(unsigned)infoType intoStream:(RDStreamRef)outputStream
{

	return STATUS_SUCCESS;
}






@end
