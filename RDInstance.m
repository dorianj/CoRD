//
//  RDInstance.m
//  Remote Desktop
//
//  Created by Craig Dooley on 8/28/06.

//  Copyright (c) 2006 Craig Dooley <xlnxminusx@gmail.com>
//  Permission is hereby granted, free of charge, to any person obtaining a 
//  copy of this software and associated documentation files (the "Software"), 
//  to deal in the Software without restriction, including without limitation 
//  the rights to use, copy, modify, merge, publish, distribute, sublicense, 
//  and/or sell copies of the Software, and to permit persons to whom the 
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in 
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, 
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN 
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "RDInstance.h"
#import "RDCKeyboard.h"

@implementation RDInstance
- (id)init {
	if ((self = [super init])) {
		cDomain = cCommand = cDirectory = @"";
		fillDefaultConnection(&conn);
	}
	
	return self;
}
- (void) dealloc {
	if (connected)
		[self disconnect];

	[super dealloc];
}


- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)streamEvent {
    uint8 type;
    BOOL disc = False;  /* True when a disconnect PDU was received */
    BOOL cont = True;
    STREAM s;
	unsigned int ext_disc_reason;
	
    while (cont)
    {
        s = rdp_recv(&conn, &type);
        if (s == NULL) {
			[appController removeItem:self];
			[self disconnect];
			return;
		}
        switch (type)
        {
            case RDP_PDU_DEMAND_ACTIVE:
                process_demand_active(&conn, s);
                break;
            case RDP_PDU_DEACTIVATE:
                DEBUG(("RDP_PDU_DEACTIVATE\n"));
                break;
            case RDP_PDU_DATA:
                disc = process_data_pdu(&conn, s, &ext_disc_reason);
                break;
            case 0:
                break;
            default:
                unimpl("PDU %d\n", type);
        }
        if (disc) {
			//NSLog(@"Disconnection");
			[appController removeItem:self];
			[self disconnect];
			return;
		}
        cont = conn.nextPacket < s->end;
    }
    return;
}

- (int) connect {
	if (!displayName) displayName = [hostName copy];

	conn.bitmapCache = cacheBitmaps;
	conn.serverBpp = screenDepth;	
	conn.controller = appController;
	
	int performanceFlags = RDP5_DISABLE_NOTHING;
	if (!windowDrags)
		performanceFlags |= RDP5_NO_FULLWINDOWDRAG;
	
	if (!themes)
		performanceFlags |= RDP5_NO_THEMING;
	
	if (!drawDesktop)
		performanceFlags |= RDP5_NO_WALLPAPER;
	
	if (!windowAnimation)
		performanceFlags |= RDP5_NO_MENUANIMATIONS;
	
	int logonFlags = RDP_LOGON_NORMAL;
	if (password && username)
		logonFlags |= RDP_LOGON_AUTO;

	conn.rdp5PerformanceFlags = performanceFlags;

	conn.screenWidth = screenWidth;
	conn.screenHeight = screenHeight;
	
	conn.tcpPort = (port==0) ? 3389 : port;

	rdpdr_init(&conn);
	
	const char *transformedPassword = (password) ? [password UTF8String] : "";

	memcpy(&conn.username, [username UTF8String], [username length] + 1);
	connected = rdp_connect(&conn, [hostName UTF8String], 
							logonFlags, 
							[cDomain UTF8String], 
							transformedPassword, 
							[cCommand UTF8String], 
							[cDirectory UTF8String]);
	if (!connected) {
		//NSLog(@"failed to connect");
		//[appController setStatus:[NSString stringWithFormat:@"Couldn't connect to '%@'", displayName]];
	} else {
		NSStream *is = conn.inputStream;
		[is setDelegate:self];
		[is scheduleInRunLoop:runLoop forMode:NSDefaultRunLoopMode];
		
		view = [[RDCView alloc] initWithFrame:NSMakeRect(0, 0, conn.screenWidth, conn.screenHeight)];
		[view setController:self];
		[view performSelectorOnMainThread:@selector(setNeedsDisplay:)
						withObject:[NSNumber numberWithBool:YES] waitUntilDone:NO];
		conn.ui = view;
	}
	
	return connected;
}

- (int) disconnect {
	NSStream *is = conn.inputStream;
	[is removeFromRunLoop:runLoop forMode:NSDefaultRunLoopMode];
	tcp_disconnect(&conn);
	
	connected = NO;
	return connected;
}

- (void) sendInput:(uint16) type flags:(uint16)flags param1:(uint16)param1 param2:(uint16)param2 {
	if (connected)
		rdp_send_input(&conn, time(NULL), type, flags, param1, param2);
}

- (rdcConnection)conn {
	return &conn;
}


@end
