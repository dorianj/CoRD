//
//  RDCController.h
//  Xrdc
//
//  Created by Craig Dooley on 4/27/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <sys/types.h>
#import <dirent.h>

#import "constants.h"
#import "parse.h"
#import "types.h"
#import "proto.h"
#import "rdesktop.h"

@class RDCView;

@interface RDCController : NSWindowController {
	IBOutlet RDCView *view;
	uint32		cFlags;
	NSString	*cHost;
	NSString	*cDomain;
	NSString	*cCommand;
	NSString	*cPassword;
	NSString	*cDirectory;
	BOOL connected;
	struct rdcConn conn;
}
- (int) setHost:(NSString *)host;
- (int) connect;
- (int) disconnect;
- (RDCView *)view;
- (rdcConnection) conn;
- (void) sendInput:(uint16) type flags:(uint16)flags param1:(uint16)param1 param2:(uint16)param2;
@end

RDCController *controller;