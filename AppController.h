//  Copyright (c) 2007 Dorian Johnson <arcadiclife@gmail.com>, Craig Dooley <xlnxminusx@gmail.com>
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
#import "miscellany.h"

@class CRDLabelCell;
@class CRDServerList;
@class RDInstance;

@interface AppController : NSObject
{
	// Inspector elements    
	IBOutlet NSTextField *gui_label;
    IBOutlet NSTextField *gui_host;
	IBOutlet NSTextField *gui_username;
    IBOutlet NSTextField *gui_password;
    IBOutlet NSButton *gui_savePassword;
	IBOutlet NSTextField *gui_domain;
	IBOutlet NSButton *gui_consoleSession;
	
	IBOutlet NSButton *gui_forwardDisks;
    IBOutlet NSPopUpButton *gui_screenResolution;
    IBOutlet CRDServerList *gui_serverList;
    
	IBOutlet NSButton *gui_cacheBitmaps;
    IBOutlet NSPopUpButton *gui_colorCount;
    IBOutlet NSButton *gui_displayDragging;
    IBOutlet NSButton *gui_drawDesktop;
    IBOutlet NSButton *gui_enableAnimations;
    IBOutlet NSButton *gui_enableThemes;

	IBOutlet NSButton *gui_connectButton;
	IBOutlet NSButton *gui_inspectorButton;
	IBOutlet NSButton *gui_addNewButton;
	
	IBOutlet NSWindow *gui_inspector;
	IBOutlet NSWindow *gui_mainWindow;
	
	IBOutlet NSMenuItem *gui_inspectorToggleMenu;
	IBOutlet NSMenuItem *gui_drawerToggleMenu;
	IBOutlet NSMenuItem *gui_keepServerMenu;
	
	// Other interface elements
	IBOutlet NSBox *gui_performanceOptions;
	IBOutlet NSTabView *gui_tabView;
	IBOutlet NSDrawer *gui_serversDrawer;
	
	// The list of connected servers (may contain some saved servers)
	NSMutableArray *connectedServers;
	
	// The list of unconnected saved servers
	NSMutableArray *savedServers;
	
	CRDDisplayMode displayMode;
	
	// Label cells
	CRDLabelCell *connectedServersLabel;
	CRDLabelCell *savedServersLabel;
	
	// The instance that the inspector is currently viewing/editing
	RDInstance *inspectedServer;
	
	// Some constant file paths
	NSString *serversDirectory;
	NSString *resourcePath;
	
	// Toolbar stuff
	NSToolbar *gui_toolbar;
	NSMutableDictionary *toolbarItems;
	
	NSUserDefaults *userDefaults;
}

// Actions
- (IBAction)addNewSavedServer:(id)sender;
- (IBAction)removeSelectedSavedServer:(id)sender;
- (IBAction)keepSelectedServer:(id)sender;
- (IBAction)toggleInspector:(id)sender;
- (IBAction)togglePerformanceDisclosure:(id)sender;
- (IBAction)fieldEdited:(id)sender;
- (IBAction)selectNext:(id)sender;
- (IBAction)selectPrevious:(id)sender;
- (IBAction)disconnect:(id)sender;
- (IBAction)connect:(id)sender;
- (IBAction)showOpen:(id)sender;
- (IBAction)toggleDrawer:(id)sender;
- (IBAction)toggleUnified:(id)sender;
- (IBAction)startFullscreen:(id)sender;

- (void)toggleDrawer:(id)sender visible:(BOOL)VisibleLength;

- (void)cellNeedsDisplay:(NSCell *)cell;
- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames;

- (BOOL)mainWindowIsFocused;
+ (NSImage *)sharedDocumentIcon;

- (void)disconnectInstance:(RDInstance *)inst;
- (RDInstance *)serverInstanceForRow:(int)row;
- (RDInstance *)selectedServerInstance;
- (RDInstance *)viewedServer;

- (CRDDisplayMode)displayMode;

@end




