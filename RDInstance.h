//
//  RDInstance.h
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

#import <Cocoa/Cocoa.h>
#import "AppController.h"
#import "RDCView.h"

@interface RDInstance : NSObject {
	RDCView *view;
	NSString *name;
	NSString *displayName;
	NSString *screenResolution;
	NSString *colorDepth;
	NSString *forwardAudio;
	AppController *appController;
	BOOL forwardDisks;
	BOOL cacheBitmaps;
	BOOL drawDesktop;
	BOOL windowDrags;
	BOOL windowAnimation;
	BOOL themes;
	
	NSColor *hostColor;
	uint32		cFlags;
	NSString	*cHost;
	NSString	*cDomain;
	NSString	*cCommand;
	NSString	*cPassword;
	NSString	*cDirectory;
	BOOL connected;
	struct rdcConn conn;
}

- (void) sendInput:(uint16) type flags:(uint16)flags param1:(uint16)param1 param2:(uint16)param2;
- (rdcConnection)conn;
- (int) connect;
- (int) disconnect;
@end
