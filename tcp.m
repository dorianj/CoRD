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

#include <unistd.h>		/* select read write close */
#include <sys/socket.h>		/* socket connect setsockopt */
#include <sys/time.h>		/* timeval */
#include <netdb.h>		/* gethostbyname */
#include <netinet/in.h>		/* sockaddr_in */
#include <netinet/tcp.h>	/* TCP_NODELAY */
#include <arpa/inet.h>		/* inet_addr */
#include <errno.h>		/* errno */
#include "rdesktop.h"

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
	if (maxlen > conn->out.size)
	{
		conn->out.data = (uint8 *) xrealloc(conn->out.data, maxlen);
		conn->out.size = maxlen;
	}

	conn->out.p = conn->out.data;
	conn->out.end = conn->out.data + conn->out.size;
	return &conn->out;
}

/* Send TCP transport data packet */
void
tcp_send(rdcConnection conn, STREAM s)
{	
	NSOutputStream *os = conn->outputStream;
	
	int length = s->end - s->data;
	int sent, total = 0;
	while (total <length) {
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
		if (length > conn->in.size)
		{
			conn->in.data = (uint8 *) xrealloc(conn->in.data, length);
			conn->in.size = length;
		}
		conn->in.end = conn->in.p = conn->in.data;
		s = &conn->in;
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
		//rcvd = recv(sock, s->end, length, 0);
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
	
	//[cont setStatus:[NSString stringWithFormat:@"Looking up host '%s'", server]];
	host = [NSHost hostWithAddress:[NSString stringWithUTF8String:server]];
	if (!host) {
		host = [NSHost hostWithName:[NSString stringWithUTF8String:server]];
		if (!host) {
			//[cont setStatus:[NSString stringWithFormat:@"Error: Couldn't resolve '%s'", server]];
			return FALSE;
		}
	}
 
	//[cont setStatus:[NSString stringWithFormat:@"Connecting to %s", server]];
	[NSStream getStreamsToHost:host port:conn->tcpPort inputStream:&is outputStream:&os];
	if ((is == nil) || (os == nil)) {
		//[cont setStatus:[NSString stringWithFormat:@"Error: couldn't connect to '%s'", server]];
		return FALSE;
	}
	
	[is open];
	[os open];
	[is retain];
	[os retain];
	conn->host = host;
	conn->inputStream = is;
	conn->outputStream = os;
	

	conn->in.size = 4096;
	conn->in.data = (uint8 *) xmalloc(conn->in.size);

	conn->out.size = 4096;
	conn->out.data = (uint8 *) xmalloc(conn->out.size);

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
