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

#import "rdesktop.h"
#import "miscellany.h"

@class CRDServerCell;
@class RDCView;

@interface RDInstance : NSObject
{
	// Represented rdesktop object
	rdcConnection conn;

	// User configurable RDP settings
	NSString *label, *hostName, *username, *password, *domain;	
	BOOL savePassword, forwardDisks, cacheBitmaps, drawDesktop, windowDrags,
			windowAnimation, themes, consoleSession, fullscreen;
	int startDisplay, forwardAudio, screenDepth, screenWidth, screenHeight, port;
	NSMutableDictionary *otherAttributes;
	
	// Allows disconnect to be called from any thread
	BOOL inputLoopFinished;
	NSRunLoop *inputRunLoop;

	// General information about instance
	BOOL temporary, modified, temporarilyFullscreen;
	int preferredRowIndex;
	CRDConnectionStatus connectionStatus;
	
	// Represented file
	NSString *rdpFilename;
	NSStringEncoding fileEncoding;
	
	// Clipboard
	NSString *remoteClipboardContents;

	// UI elements
	RDCView *view;
	NSScrollView *scrollEnclosure;
	CRDServerCell *cellRepresentation;
	NSTabViewItem *tabViewRepresentation;
	NSWindow *window;
}

- (id)initWithRDPFile:(NSString *)path;

// Working with rdesktop
- (BOOL)connect;
- (void)disconnect;
- (void)disconnectAsync:(NSNumber *)block;
- (void)sendInput:(uint16)type flags:(uint16)flags param1:(uint16)param1 param2:(uint16)param2;
- (void)startInputRunLoop;
- (void)synchronizeRemoteClipboard:(NSPasteboard *)toPasteboard suggestedFormat:(int)format;
- (void)synchronizeLocalClipboard:(NSData *)data;

// Working with the rest of CoRD
- (void)cancelConnection;
- (NSComparisonResult)compareUsingPreferredOrder:(id)compareTo;
- (void)clearKeychainData;

// Working with GUI
- (void)updateCellData;
- (void)createUnified:(BOOL)useScrollView enclosure:(NSRect)enclosure;
- (void)createWindow:(BOOL)useScrollView;
- (void)destroyUnified;
- (void)destroyWindow;

// Working with the represented file
- (BOOL)readRDPFile:(NSString *)path;
- (BOOL)writeRDPFile:(NSString *)path;


// Accessors
- (rdcConnection)conn;
- (NSString *)label;
- (RDCView *)view;
- (NSString *)rdpFilename;
- (void)setRdpFilename:(NSString *)path;
- (BOOL)temporary;
- (void)setTemporary:(BOOL)temp;
- (CRDServerCell *)cellRepresentation;
- (NSTabViewItem *)tabViewRepresentation;
- (BOOL)modified;
- (CRDConnectionStatus)status;
- (void)setStatusAsNumber:(NSNumber *)status;
- (NSWindow *)window;

- (void)setLabel:(NSString *)s;
- (void)setHostName:(NSString *)s;
- (void)setUsername:(NSString *)s;
- (void)setPassword:(NSString *)pass;


@end
