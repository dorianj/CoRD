//
//  CRDServer.h
//  Cord
//
//  Created by Nick Peelman on 4/13/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "rdesktop.h"
#import "CRDShared.h"

@interface CRDServer : NSObject {

	// User configurable RDP settings
	NSString *label, *hostName;
	BOOL savePassword;
	NSInteger port, hotkey;
	NSMutableDictionary *otherAttributes;
	
	// Working between main thread and connection thread
	volatile BOOL connectionRunLoopFinished;
	NSRunLoop *connectionRunLoop;
	NSThread *connectionThread;
	NSMachPort *inputEventPort;
	NSMutableArray *inputEventStack;
	
	// General information about instance
	BOOL temporary, modified, temporarilyFullscreen, _usesScrollers;
	NSInteger preferredRowIndex;
	volatile CRDConnectionStatus connectionStatus;
	
	// Clipboard
	BOOL isClipboardOwner;
	NSString *remoteClipboard;
	NSInteger clipboardChangeCount;
	
	// UI elements
	CRDSessionView *view;
	NSScrollView *scrollEnclosure;
//	CRDServerCell *cellRepresentation;
	NSWindow *window;
	
}

@end
