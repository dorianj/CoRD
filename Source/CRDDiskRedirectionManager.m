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

// Replaces: disk.c

#import "CRDDiskRedirectionManager.h"
#import "CRDSession.h"
#import "rdesktop.h"


@implementation CRDDiskRedirectionManager


- (id)initWithSession:(CRDSession *)ses
{
	if (![super init])
		return nil;
	
	associatedSession = ses;
	associatedConnection = [ses conn];
		 
	return self;
}

- (NTStatus)create:(RDRedirectedDeviceRef)device access:(unsigned)access shareMode:(unsigned)shareMode disposition:(unsigned)disposition flags:(unsigned)flags filename:(NSString *)filename handle:(NTHandle *)retHandle
{

	return STATUS_SUCCESS;
}

- (NTStatus)close:(NTHandle)handle
{

	return STATUS_SUCCESS;
}

- (NTStatus)read:(NTHandle)handle intoBuffer:(unsigned char *)buffer length:(unsigned)length offset:(unsigned)offset result:(unsigned *)retResult
{


	return STATUS_SUCCESS;
}
	
	
@end
