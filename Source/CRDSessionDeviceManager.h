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

/*	Terms: query.. methods indicate that they write their response into a passed RDStreamRef
*/

#import <Cocoa/Cocoa.h>


@class CRDSession;


@interface CRDSessionDeviceManager : NSObject 
{

}


- (NTStatus)handleCreate:(RDRedirectedDeviceRef)device access:(unsigned)access shareMode:(unsigned)shareMode disposition:(unsigned)disposition flags:(unsigned)flags filename:(char *)filename handle:(NTHandle *)retHandle;

- (NTStatus)handleClose:(NTHandle)handle;

- (NTStatus)handleRead:(NTHandle)handle intoBuffer:(unsigned char *)buffer length:(unsigned)length offset:(unsigned)offset result:(unsigned *)retResult;

- (NTStatus)handleWrite:(NTHandle)handle data:(unsigned char *)toBeWritten length:(unsigned)length offset:(unsigned)offset result:(unsigned *)retResult;
	
	
// These two replace add_async_iorequest
- (BOOL)addAsynchronousRead:(RDRedirectedDeviceRef)device handle:(NTHandle)handle requestID:(unsigned)requestID fileOperation:(unsigned)op length:(unsigned)length offset:(unsigned)offset;
	
- (BOOL)addAsynchronousRead:(RDRedirectedDeviceRef)device handle:(NTHandle)handle requestID:(unsigned)requestID fileOperation:(unsigned)op length:(unsigned)length offset:(unsigned)offset data:(unsigned char *)toBeWritten;
	
	
// replaces rdpdr_handle_ok
- (BOOL)isValidHandle: (NTHandle)handle forDevice:(RDRedirectedDeviceRef)device;

// replaces disk_query_information
- (NTStatus)queryFileInformation:(NTHandle)handle infoType:(unsigned)infoType intoStream:(RDStreamRef)outputStream;

// replaces disk_query_directory
- (NTStatus)queryDirectory:(NTHandle)handle infoType:(unsigned)infoType filename:(unsigned char *)filename intoStream:(RDStreamRef)outputStream;

// replaces disk_set_information
- (NTStatus)setFileInformation:(NTHandle)handle infoType:(unsigned)infoType fromStream:(RDStreamRef)inputStream;

// replaces disk_query_volume_information
- (NTStatus)queryVolumeInformation:(NTHandle)file infoType:(unsigned)infoType intoStream:(RDStreamRef)outputStream;

@end


// subject to much change
@protocol CRDRedirectedDevice
	- (id)initWithSession:(CRDSession *)ses;
	
	- (NTStatus)create:(RDRedirectedDeviceRef)device access:(unsigned)access shareMode:(unsigned)shareMode disposition:(unsigned)disposition flags:(unsigned)flags filename:(NSString *)filename handle:(NTHandle *)retHandle;
	- (NTStatus)close:(NTHandle)handle;
	- (NTStatus)read:(NTHandle)handle intoBuffer:(unsigned char *)buffer length:(unsigned)length offset:(unsigned)offset result:(unsigned *)retResult;
@end