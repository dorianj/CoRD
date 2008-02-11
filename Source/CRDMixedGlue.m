/*	Copyright (c) 2007-2008 Dorian Johnson <arcadiclife@gmail.com>
	
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

#import "rdesktop.h"

// Replaces: xclip.c

#import "CRDShared.h"
#import "CRDSession.h"


#pragma mark -
#pragma mark Clipboard

void ui_clip_format_announce(RDConnectionRef conn, uint8 *data, uint32 length) 
{
	CRDSession *inst = (CRDSession *)conn->controller;
	[inst gotNewRemoteClipboardData];
}

void ui_clip_handle_data(RDConnectionRef conn, uint8 *data, uint32 length) 
{	
	CRDSession *inst = (CRDSession *)conn->controller;
	[inst setLocalClipboard:[NSData dataWithBytes:data length:length] format:conn->clipboardRequestType];
}

void ui_clip_request_data(RDConnectionRef conn, uint32 format) 
{	
	CRDSession *inst = (CRDSession *)conn->controller;
	 
	if ( (format == CF_UNICODETEXT) || (format == CF_TEXT) )
		[inst setRemoteClipboard:format];
}

void ui_clip_sync(RDConnectionRef conn) 
{
	CRDSession *inst = (CRDSession *)conn->controller;
	[inst informServerOfPasteboardType];
}

void ui_clip_request_failed(RDConnectionRef conn)
{

	
}

void ui_clip_set_mode(RDConnectionRef conn, const char *optarg)
{

}



