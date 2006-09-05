//
//  RDInstance.h
//  Remote Desktop
//
//  Created by Craig Dooley on 8/28/06.
//  Copyright 2006 Craig Dooley. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "RDCView.h"

@interface RDInstance : NSObject {
	RDCController *controller;
	RDCView *view;
	NSString *name;
	NSString *displayName;
	NSString *screenResolution;
	NSString *colorDepth;
	NSString *forwardAudio;
	BOOL forwardDisks;
	BOOL cacheBitmaps;
	BOOL drawDesktop;
	BOOL windowDrags;
	BOOL windowAnimation;
	BOOL themes;
	
	uint32		cFlags;
	NSString	*cHost;
	NSString	*cDomain;
	NSString	*cCommand;
	NSString	*cPassword;
	NSString	*cDirectory;
	BOOL connected;
	struct rdcConn conn;
}

- (int) connect;
- (int) disconnect;
@end
