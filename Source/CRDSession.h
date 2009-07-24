/*	Copyright (c) 2007-2009 Dorian Johnson <2009@dorianj.net>
	
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
	BOOL savePassword, forwardDisks, forwardPrinters, drawDesktop, windowDrags, windowAnimation, themes, fontSmoothing, consoleSession, fullscreen;
	NSInteger forwardAudio, port;
	NSInteger hotkey, screenDepth, screenWidth, screenHeight;
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
	
	// Represented file
	NSString *rdpFilename;
	NSStringEncoding fileEncoding;
	
	// Clipboard
	BOOL isClipboardOwner;
	NSString *remoteClipboard;
	NSInteger clipboardChangeCount;

	// UI elements
	CRDSessionView *view;
	NSScrollView *scrollEnclosure;
	CRDServerCell *cellRepresentation;
	NSWindow *window;
}

@property (copy) NSString *hostName, *label;
@property (readonly) RDConnectionRef conn;
@property (readonly) CRDSessionView *view;
@property (assign) BOOL temporary;
@property (readonly) BOOL modified;
@property (readonly) CRDServerCell *cellRepresentation;
@property (readonly) volatile CRDConnectionStatus status;
@property (readonly) NSWindow *window;
@property (assign) NSInteger hotkey;



- (id)initWithPath:(NSString *)path;
- (id)initWithBaseConnection;

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
- (void)destroyUIElements;

// Working with the represented file
- (void)setFilename:(NSString *)filename;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)atomicFlag updateFilenames:(BOOL)updateNamesFlag;
- (void)flushChangesToFile;


// Accessors
- (NSView *)tabItemView;
- (NSString *)filename;
- (void)setFilename:(NSString *)path;
- (void)setTemporary:(BOOL)temp;
- (void)setHostName:(NSString *)newHost;
- (void)setUsername:(NSString *)s;
- (void)setPassword:(NSString *)pass;
@end
