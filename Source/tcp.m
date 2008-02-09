/*
   rdesktop: A Remote Desktop Protocol client.
   Protocol services - TCP layer
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

#import <unistd.h>		/* select read write close */
#import <sys/socket.h>		/* socket connect setsockopt */
#import <sys/time.h>		/* timeval */
#import <netdb.h>		/* gethostbyname */
#import <netinet/in.h>		/* sockaddr_in */
#import <netinet/tcp.h>	/* TCP_NODELAY */
#import <arpa/inet.h>		/* inet_addr */
#import <errno.h>		/* errno */
#import "rdesktop.h"

#import <Foundation/NSStream.h>
#import <Foundation/NSString.h>
#import <Foundation/NSHost.h>

#import <CoreFoundation/CoreFoundation.h>

@class AppController;

#ifndef INADDR_NONE
#define INADDR_NONE ((unsigned long) -1)
#endif

/* Initialise TCP transport data packet */
RDStreamRef
tcp_init(RDConnectionRef conn, uint32 maxlen)
{
	if (maxlen > conn->outStream.size)
	{
		conn->outStream.data = (uint8 *) xrealloc(conn->outStream.data, maxlen);
		conn->outStream.size = maxlen;
	}

	conn->outStream.p = conn->outStream.data;
	conn->outStream.end = conn->outStream.data + conn->outStream.size;
	return &conn->outStream;
}

/* Send TCP transport data packet */
void
tcp_send(RDConnectionRef conn, RDStreamRef s)
{	
	NSOutputStream *os = conn->outputStream;
	
	int length = s->end - s->data;
	int sent, total = 0;
	while (total < length) {
		sent = [os write:s->data + total  maxLength:length - total];
		if (sent < 0) {
			error("send: %s\n", strerror(errno));
			return;
		}
		total += sent;
	}
}

/* Receive a message on the TCP layer */
RDStreamRef
tcp_recv(RDConnectionRef conn, RDStreamRef s, uint32 length)
{
	NSInputStream *is = conn->inputStream;
	unsigned int new_length, end_offset, p_offset;
	int rcvd = 0;

	if (s == NULL)
	{
		/* read into "new" stream */
		if (length > conn->inStream.size)
		{
			conn->inStream.data = (uint8 *) xrealloc(conn->inStream.data, length);
			conn->inStream.size = length;
		}
		conn->inStream.end = conn->inStream.p = conn->inStream.data;
		s = &conn->inStream;
	}
	else
	{
		/* append to existing stream */
		new_length = (s->end - s->data) + length;
		if (new_length > s->size)
		{
			p_offset = s->p - s->data;
			end_offset = s->end - s->data;
			s->data = (uint8 *) xrealloc(s->data, new_length);
			s->size = new_length;
			s->p = s->data + p_offset;
			s->end = s->data + end_offset;
		}
	}

	while (length > 0)
	{
		rcvd = [is read:s->end maxLength:length];
		if (rcvd < 0)
		{
			error("recv: %s\n", strerror(errno));
			return NULL;
		}
		else if (rcvd == 0)
		{
			error("Connection closed\n");
			return NULL;
		}

		s->end += rcvd;
		length -= rcvd;
	}

	return s;
}

/* Establish a connection on the TCP layer */
RDBOOL
tcp_connect(RDConnectionRef conn, const char *server)
{
	NSInputStream *is = nil;
	NSOutputStream *os = nil;
	NSHost *host;
	
	if ( (host = [NSHost hostWithAddress:[NSString stringWithUTF8String:server]]) == nil)
	{
		if ( (host = [NSHost hostWithName:[NSString stringWithUTF8String:server]]) == nil)
		{
			conn->errorCode = ConnectionErrorHostResolution;
			return False;
		}
	}
	
 	[NSStream getStreamsToHost:host port:conn->tcpPort inputStream:&is outputStream:&os];
	
	if (is == nil || os == nil)
	{
		conn->errorCode = ConnectionErrorGeneral;
		return False;
	}
	
	[is open];
	[os open];
	
	// Wait until the output socket can be written to (this is the alternative to letting NSOutputStream block later when we do the first write:)
	time_t start = time(NULL);
	int timedOut = False;
	while (![os hasSpaceAvailable] && !timedOut && (conn->errorCode != ConnectionErrorCanceled) )
	{
		usleep(1000); // one millisecond
		timedOut = (time(NULL) - start > TIMEOUT_LENGTH);
	}
	
	if (timedOut)
	{
		conn->errorCode = ConnectionErrorTimeOut;
		return False;
	}
	else if (conn->errorCode == ConnectionErrorCanceled)
	{
		return False;
	}
	
	conn->inputStream = [is retain];
	conn->outputStream = [os retain];
	

	conn->inStream.size = 4096;
	conn->inStream.data = xmalloc(conn->inStream.size);

	conn->outStream.size = 4096;
	conn->outStream.data = xmalloc(conn->outStream.size);

	return True;
}

/* Disconnect on the TCP layer */
void
tcp_disconnect(RDConnectionRef conn)
{
	[conn->inputStream release];
	[conn->outputStream release];
	conn->inputStream = NULL;
	conn->outputStream = NULL;
	[conn->inputStream close];
	[conn->outputStream close];
}

char *
tcp_get_address(RDConnectionRef conn)
{
	NSOutputStream *os = conn->outputStream;
	CFWriteStreamRef stream;
	CFSocketNativeHandle socket;
	CFDataRef data;
	
	stream = (CFWriteStreamRef) os;
	data = CFWriteStreamCopyProperty(stream, kCFStreamPropertySocketNativeHandle);
	socket = *(CFSocketNativeHandle *) CFDataGetBytePtr(data);

	char *ipaddr = malloc(32);
    struct sockaddr_in sockaddr;
    socklen_t len = sizeof(sockaddr);
    if (getsockname(socket, (struct sockaddr *) &sockaddr, &len) == 0)
    {
        unsigned char *ip = (unsigned char *) &sockaddr.sin_addr;
        sprintf(ipaddr, "%d.%d.%d.%d", ip[0], ip[1], ip[2], ip[3]);
    }
    else
        strcpy(ipaddr, "127.0.0.1");
    return ipaddr;
}

/* reset the state of the tcp layer */
/* Support for Session Directory */
void
tcp_reset_state(RDConnectionRef conn)
{
	/* Clear the incoming stream */
	[(id)conn->inputStream release];
	conn->inputStream = NULL;
	if (conn->inStream.data != NULL)
		xfree(conn->inStream.data);
	conn->inStream.p = NULL;
	conn->inStream.end = NULL;
	conn->inStream.data = NULL;
	conn->inStream.size = 0;
	conn->inStream.iso_hdr = NULL;
	conn->inStream.mcs_hdr = NULL;
	conn->inStream.sec_hdr = NULL;
	conn->inStream.rdp_hdr = NULL;
	conn->inStream.channel_hdr = NULL;

	/* Clear the outgoing stream */
	[(id)conn->outputStream release];
	conn->outputStream = NULL;
	if (conn->outStream.data != NULL)
		xfree(conn->outStream.data);
	conn->outStream.p = NULL;
	conn->outStream.end = NULL;
	conn->outStream.data = NULL;
	conn->outStream.size = 0;
	conn->outStream.iso_hdr = NULL;
	conn->outStream.mcs_hdr = NULL;
	conn->outStream.sec_hdr = NULL;
	conn->outStream.rdp_hdr = NULL;
	conn->outStream.channel_hdr = NULL;
}
