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

#import "rdesktop.h"

#import "miscellany.h"
#import "CRDSession.h"

// only for ui_select
#import <sys/stat.h>
#import <sys/times.h>


#pragma mark -
#pragma mark Disk forwarding
// XXX: this won't be used at all with new disk redir solution
int ui_select(rdcConnection conn)
{
	int n = 0;
	fd_set rfds, wfds;
	struct timeval tv;
	RDBOOL s_timeout = False;
	
	// If there are no pending IO requests, no need to check any files
	if (!conn->ioRequest)
		return 1;
	
	FD_ZERO(&rfds);
	FD_ZERO(&wfds);	

	rdpdr_add_fds(conn, &n, &rfds, &wfds, &tv, &s_timeout);
	
	struct timeval noTimeout;
	noTimeout.tv_sec = 0;
	noTimeout.tv_usec = 500; // one millisecond is 1000

	switch (select(n, &rfds, &wfds, NULL, &noTimeout))
	{
		case -1:
			error("select: %s\n", strerror(errno));
			break;
		case 0:
			rdpdr_check_fds(conn, &rfds, &wfds, 1);
			break;
		default:
			rdpdr_check_fds(conn, &rfds, &wfds, 0);
			break;
	}
	
	return 1;
}


#pragma mark -
#pragma mark Clipboard

void ui_clip_format_announce(rdcConnection conn, uint8 *data, uint32 length) 
{
	CRDSession *inst = (CRDSession *)conn->controller;
	[inst gotNewRemoteClipboardData];
}

void ui_clip_handle_data(rdcConnection conn, uint8 *data, uint32 length) 
{	
	CRDSession *inst = (CRDSession *)conn->controller;
	[inst setLocalClipboard:[NSData dataWithBytes:data length:length] format:conn->clipboardRequestType];
}

void ui_clip_request_data(rdcConnection conn, uint32 format) 
{	
	CRDSession *inst = (CRDSession *)conn->controller;
	 
	if ( (format == CF_UNICODETEXT) || (format == CF_TEXT) )
		[inst setRemoteClipboard:format];
}

void ui_clip_sync(rdcConnection conn) 
{
	CRDSession *inst = (CRDSession *)conn->controller;
	[inst informServerOfPasteboardType];
}

void ui_clip_request_failed(rdcConnection conn)
{

	
}

void ui_clip_set_mode(rdcConnection conn, const char *optarg)
{

}

