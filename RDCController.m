//
//  RDCController.m
//  Remote Desktop
//
//  Created by Craig Dooley on 4/27/06.

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

#import "RDCController.h"
#import "RDCKeyboard.h"

@implementation RDCController
- (id) init {
	self = [super initWithWindowNibName:@"RDCWindow"];
	if (self) {
		cDomain = cPassword = cCommand = cDirectory = cHost = @"";
		[[RDCKeyboard alloc] init];
		fillDefaultConnection(&conn);
	}
	
	return self;
}

- (void)windowDidLoad {
	[[self window] setAcceptsMouseMovedEvents:YES];
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)streamEvent {
    uint8 type;
    BOOL disc = False;  /* True when a disconnect PDU was received */
    BOOL cont = True;
    STREAM s;
	int ext_disc_reason;

    while (cont)
    {
        s = rdp_recv(&conn, &type);
        if (s == NULL) {
			[[self window] close];
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
                disc = process_data_pdu(&conn, s, ext_disc_reason);
                break;
            case 0:
                break;
            default:
                unimpl("PDU %d\n", type);
        }
        if (disc) {
			[[self window] close];
			return;
		}
        cont = conn.nextPacket < s->end;
    }
    return;
}
																

- (int) setHost:(NSString *)host {
	[host retain];
	[cHost release];
	cHost = host;
	return 0;
}

- (int) connect {
	if (cHost == nil) {
		NSLog(@"WTF");
		return -1;
	}

	rdpdr_init(&conn);
	memcpy(&conn.username,"cdooley",8);
	connected = rdp_connect(&conn, [cHost UTF8String], 
				0x00000133, /* XXX */ 
				[cDomain UTF8String], 
				[cPassword UTF8String], 
				[cCommand UTF8String], 
				[cDirectory UTF8String]);
	if (!connected) {
		NSLog(@"failed to connect");
		return connected;
	}

	NSStream *is = conn.inputStream;
	[is setDelegate:self];
	[is scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	
	NSWindow *win = [self window];
	[win setDelegate:self];
	[win setContentSize:NSMakeSize(conn.screenWidth, conn.screenHeight)];
	[win setTitle:cHost];
	
	[view setFrameSize:NSMakeSize(conn.screenWidth, conn.screenHeight)];
	[view setNeedsDisplay:YES];
	[self showWindow:nil];
	conn.ui = view;
	
	// rdp_main_loop()
	return connected;
}

- (void) windowWillClose:(NSNotification *)note {
	[self disconnect];
}

- (RDCView *)view {
	return view;
}

- (int) disconnect {
	NSStream *is = conn.inputStream;
	NSLog(@"disconnect");
	[is removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	tcp_disconnect(&conn);
	connected = NO;
	
	return connected;
}

- (rdcConnection) conn {
	return &conn;
}

- (void) sendInput:(uint16) type flags:(uint16)flags param1:(uint16)param1 param2:(uint16)param2 {
	if (connected)
		rdp_send_input(&conn, time(NULL), type, flags, param1, param2);
}

- (void)dealloc {
	[[self window] close];
	
	[super dealloc];
}
@end
