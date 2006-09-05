//
//  RDInstance.m
//  Remote Desktop
//
//  Created by Craig Dooley on 8/28/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "RDInstance.h"
#import "RDCKeyboard.h"

@implementation RDInstance
- (id)init {
	if (self = [super init]) {
		cDomain = cPassword = cCommand = cDirectory = cHost = @"";
		[[RDCKeyboard alloc] init];
		fillDefaultConnection(&conn);
	}
	
	return self;
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
			[self disconnect];
			return;
		}
        cont = conn.nextPacket < s->end;
    }
    return;
}

- (int) connect {
	if (name == nil) {
		NSLog(@"WTF");
		return -1;
	}
	
	conn.bitmapCache = cacheBitmaps;
	if ([colorDepth compare:@"256"] == 0) {
		conn.serverBpp = 8;
	} else if ([colorDepth compare:@"Thousands"] == 0) {
		conn.serverBpp = 16;
	} else if ([colorDepth compare:@"Millions"] == 0) {
		conn.serverBpp = 24;
	} else {
		NSLog(@"WTF");
		return -1;
	}
	
	int performanceFlags = RDP5_DISABLE_NOTHING;
	if (!windowDrags)
		performanceFlags |= RDP5_NO_FULLWINDOWDRAG;
	
	if (!themes)
		performanceFlags |= RDP5_NO_THEMING;
	
	if (!drawDesktop)
		performanceFlags |= RDP5_NO_WALLPAPER;
	
	if (!windowAnimation)
		performanceFlags |= RDP5_NO_MENUANIMATIONS;
	
	conn.rdp5PerformanceFlags = performanceFlags;
	
	rdpdr_init(&conn);
	memcpy(&conn.username,"cdooley",8);
	connected = rdp_connect(&conn, [name UTF8String], 
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
	
	view = [[RDCView alloc] initWithFrame:NSMakeRect(0, 0, conn.screenWidth, conn.screenHeight)];
	[view setValue:self forKey:@"controller"];
	[view setNeedsDisplay:YES];
	conn.ui = view;
	
	// rdp_main_loop()
	return connected;
}

- (int) disconnect {
	[view fillRect:[view frame] withColor:[NSColor whiteColor]];
	[view setNeedsDisplay:YES];
	
	NSStream *is = conn.inputStream;
	NSLog(@"disconnect");
	[is removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
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

- (void)dealloc {
	[name dealloc];
	[displayName dealloc];
	[screenResolution dealloc];
	[super dealloc];
}
@end
