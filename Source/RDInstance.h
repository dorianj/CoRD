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
	RDCView *view;
	NSRunLoop *inputRunLoop;
	
	// All user-settable options
	NSString *label;
	NSString *hostName;
	NSString *username; 
	NSString *password; 
	NSString *domain;	
	
	BOOL savePassword;
	BOOL forwardDisks; 
	BOOL cacheBitmaps; 
	BOOL drawDesktop; 
	BOOL windowDrags; 
	BOOL windowAnimation; 
	BOOL themes; 
	BOOL consoleSession;
	BOOL fullscreen;
	
	int startDisplay;
	int forwardAudio; 
	int screenDepth;
	int screenWidth;
	int screenHeight;
	int port;
	
	
	// Used to store attributes that RDP files may define but aren't handled in 
	//	instance variables so when the file is written out those attributes are
	//	retained
	NSMutableDictionary *otherAttributes;
	
	// Flags used by ServersManager (and possibly others)
	BOOL temporary;
	BOOL modified;
	BOOL temporarilyFullscreen;
	CRDConnectionStatus connectionStatus;
	
	// Path to the RDP File backing this RDInstance, if any.
	NSString *rdpFilename;
	NSStringEncoding fileEncoding;
	
	// Some internal stuff
	uint32 cFlags;
	NSString *cCommand, *cDirectory;
	NSString *remoteClipboardContents;
	rdcConnection conn;

	// UI elements (only valid if connected)
	CRDServerCell *cellRepresentation;
	NSTabViewItem *tabViewRepresentation;
	
	// Used when in windowed mode
	NSWindow *window;
	NSScrollView *scrollEnclosure;
}
- (id)initWithRDPFile:(NSString *)path;

// RDP-related
- (BOOL)connect;
- (void)disconnect;
- (void)sendInput:(uint16)type flags:(uint16)flags param1:(uint16)param1 param2:(uint16)param2;
- (void)startInputRunLoop;
- (void)synchronizeRemoteClipboard:(NSPasteboard *)toPasteboard suggestedFormat:(int)format;
- (void)synchronizeLocalClipboard:(NSData *)data;

// GUI
- (void)updateCellData;
- (void)createUnified:(BOOL)useScrollView enclosure:(NSRect)enclosure;
- (void)createWindow:(BOOL)useScrollView;
- (void)destroyUnified;
- (void)destroyWindow;

- (BOOL)readRDPFile:(NSString *)path;
- (BOOL)writeRDPFile:(NSString *)path;

- (void)cancelConnection;

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
