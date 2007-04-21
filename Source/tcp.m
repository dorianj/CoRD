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
STREAM
tcp_init(rdcConnection conn, uint32 maxlen)
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
tcp_send(rdcConnection conn, STREAM s)
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
STREAM
tcp_recv(rdcConnection conn, STREAM s, uint32 length)
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
		if (conn->numDevices > 0)
			ui_select(conn);
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
RDCBOOL
tcp_connect(rdcConnection conn, const char *server)
{
	NSInputStream *is = nil;
	NSOutputStream *os = nil;
	NSHost *host;
	AppController *cont = conn->controller;
	
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
	
	// Wait until the output socket can be written to (this is the alternative to
	//	letting NSOutputStream block later when we do the first write:)
	time_t start = time(NULL);
	int timedOut = False;
	while (![os hasSpaceAvailable] && !timedOut && conn->errorCode != ConnectionErrorCanceled)
	{
		usleep(1000); // sleep for a millisecond
		timedOut = (time(NULL) - start > TIMOUT_LENGTH);
	}
	
	if (timedOut == True)
	{
		conn->errorCode = ConnectionErrorTimeOut;
		return False;
	}
	
	[is retain];
	[os retain];
	
	
	
	conn->host = host;
	conn->inputStream = is;
	conn->outputStream = os;
	

	conn->inStream.size = 4096;
	conn->inStream.data = (uint8 *) xmalloc(conn->inStream.size);

	conn->outStream.size = 4096;
	conn->outStream.data = (uint8 *) xmalloc(conn->outStream.size);

	return True;
}

/* Disconnect on the TCP layer */
void
tcp_disconnect(rdcConnection conn)
{
	NSInputStream *is;
	NSOutputStream *os;
	is = conn->inputStream;
	os = conn->outputStream;
	
	[is close];
	[os close];
	[is release];
	[os release];
}

char *
tcp_get_address(rdcConnection conn)
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
