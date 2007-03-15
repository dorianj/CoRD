//  Copyright (c) 2006 Dorian Johnson <arcadiclife@gmail.com>
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

/*	Purpose: controls the Server manager window
*/

#import <Cocoa/Cocoa.h>
#import "RDPFile.h"
#import "RDInstance.h"

@class AppController;
// status codes

/* Not currently used, probably won't ever be used 
typedef enum _ServerManagerStatus {
	CC_STATUS_NOTHING			= 0,
	CC_STATUS_CONNECTING		= 1,
	CC_STATUS_FAILED			= 2,
	CC_STATUS_SUCCESS			= 3
} ServerManagerStatus; */


@interface ConnectionsController : NSObject
{
	// Gui elements
    IBOutlet NSPopUpButton *gui_Audio;
    IBOutlet NSButton *gui_cacheBitmaps;
    IBOutlet NSPopUpButton *gui_colorCount;
    IBOutlet NSButton *gui_displayDragging;
    IBOutlet NSButton *gui_drawDesktop;
    IBOutlet NSButton *gui_enableAnimations;
    IBOutlet NSButton *gui_enableThemes;
    IBOutlet NSButton *gui_forwardDisks;
    IBOutlet NSTextField *gui_host;
    IBOutlet NSTextField *gui_password;
    IBOutlet NSButton *gui_savePassword;
    IBOutlet NSPopUpButton *gui_screenResolution;
    IBOutlet NSTableView *gui_serverList;
    IBOutlet NSTextField *gui_Status;
    IBOutlet NSProgressIndicator *gui_Throbber;
    IBOutlet NSTextField *gui_username;
	IBOutlet NSWindow *gui_mangerWindow;
	IBOutlet NSMenu *gui_quickConnectMenu;
	IBOutlet NSButton *gui_consoleSession;
	IBOutlet NSTextField *gui_domain;
	
	// Other outlets
	IBOutlet AppController *appController;
	
	// The list of servers, id's to RDPFile
	NSMutableArray *servers;
	
	int lastRowViewed;
	
	NSString *serversDirectory;
	NSString *resourcePath;
	
	SecKeychainRef keychainAccessRef;
	
	BOOL currentlyConnecting;
	
}


- (IBAction)addNewServer:(id)sender;
- (IBAction)cancelChanges:(id)sender;
- (IBAction)connect:(id)sender;
- (IBAction)removeServer:(id)sender;
- (IBAction)showOpen:(id)sender;
- (IBAction)showOpenAndKeep:(id)sender;
- (RDPFile *)currentOptions;
- (RDPFile *)currentOptionsByMerging:(RDPFile *)origninalOptions;
- (void)setCurrentOptions:(RDPFile *)newSettings;
- (void)saveServer:(int)row;
- (void)toggleProgressIndicator:(BOOL)on;
- (RDInstance *)rdInstanceFromRDPFile:(RDPFile *)source;
- (void)savePassword:(NSString *)password server:(NSString *)server
		user:(NSString *)username;
- (NSString *)retrievePassword:(RDPFile *)RDPFile;
- (void)clearPassword:(RDPFile *)rdp;
- (void)addServer:(RDPFile *)rdp;
- (void)quickConnectFromMenu:(id)sender;
- (void)buildServersMenu;
- (void)showOpen:(id)sender keepServer:(BOOL)keep;
- (void)setConnecting:(BOOL)isConnecting to:(NSString *)connectingTo;
@end


// A few methods for code readability and convenience
void ensureDirectoryExists(NSString *directory, NSFileManager *manager);
int boolAsButtonState(BOOL value);
NSNumber * buttonStateAsNumber(NSButton * button);
NSNumber * buttonStateAsNumberInverse(NSButton * button);
NSString * findAvailableFileName(NSString *path, NSString *base, NSString *extension);
void split_hostname(NSString *address, NSString **host, int *port);
NSArray *filter_filenames(NSArray *unfilteredFiles, NSArray *types);

