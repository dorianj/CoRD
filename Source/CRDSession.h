/*	Copyright (c) 2006 Craig Dooley <xlnxminusx@gmail.com>
	
	This file is part of CoRD.
	CoRD is free software; you can redistribute it and/or modify it under the
	terms of the GNU General Public License as published by the Free Software
	Foundation; either version 2 of the License, or (at your option) any later
	version.

	CoRD is distributed in the hope that it will be useful, but WITHOUT ANY
	WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
	FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with
	CoRD; if not, write to the Free Software Foundation, Inc., 51 Franklin St,
	Fifth Floor, Boston, MA 02110-1301 USA
*/


#import <Cocoa/Cocoa.h>

#import "rdesktop.h"
#import "CRDShared.h"

@class CRDServerCell;
@class CRDSessionView;

@interface CRDSession : NSObject
{
	// Represented rdesktop object
	RDConnectionRef conn;

	// User configurable RDP settings
	NSString *label, *hostName, *username, *password, *domain;	
	BOOL savePassword, forwardDisks, forwardPrinters, drawDesktop, windowDrags,
			windowAnimation, themes, consoleSession, fullscreen;
	int startDisplay, forwardAudio, screenDepth, screenWidth, screenHeight, port;
	NSMutableDictionary *otherAttributes;
	
	// Working between main thread and connection thread
	BOOL connectionRunLoopFinished;
	NSRunLoop *connectionRunLoop;
	NSThread *connectionThread;
	NSMachPort *inputEventPort;
	NSMutableArray *inputEventStack;

	// General information about instance
	BOOL temporary, modified, temporarilyFullscreen;
	int preferredRowIndex;
	CRDConnectionStatus connectionStatus;
	
	// Represented file
	NSString *rdpFilename;
	NSStringEncoding fileEncoding;
	
	// Clipboard
	BOOL isClipboardOwner;
	NSString *remoteClipboard;
	int clipboardChangeCount;

	// UI elements
	CRDSessionView *view;
	NSScrollView *scrollEnclosure;
	CRDServerCell *cellRepresentation;
	NSWindow *window;
}

- (id)initWithPath:(NSString *)path;

// Working with rdesktop
- (BOOL)connect;
- (void)disconnect;
- (void)disconnectAsync:(NSNumber *)block;
- (void)sendInputOnConnectionThread:(uint32)time type:(uint16)type flags:(uint16)flags param1:(uint16)param1 param2:(uint16)param2;
- (void)runConnectionRunLoop;

// Clipboard
- (void)announceNewClipboardData;
- (void)setRemoteClipboard:(int)suggestedFormat;
- (void)setLocalClipboard:(NSData *)data format:(int)format;
- (void)requestRemoteClipboardData;
- (void)gotNewRemoteClipboardData;
- (void)informServerOfPasteboardType;

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
- (void)setFilename:(NSString *)filename;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)atomicFlag updateFilenames:(BOOL)updateNamesFlag;
- (void)flushChangesToFile;


// Accessors
- (RDConnectionRef)conn;
- (NSString *)label;
- (CRDSessionView *)view;
- (NSString *)filename;
- (void)setFilename:(NSString *)path;
- (BOOL)temporary;
- (void)setTemporary:(BOOL)temp;
- (CRDServerCell *)cellRepresentation;
- (BOOL)modified;
- (CRDConnectionStatus)status;
- (NSWindow *)window;

- (void)setHostName:(NSString *)newHost;
- (void)setUsername:(NSString *)s;
- (void)setPassword:(NSString *)pass;
@end
