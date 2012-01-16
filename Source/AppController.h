/*	Copyright (c) 2007-2012 Dorian Johnson <2011@dorianj.net>
 
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

#import "CRDShared.h"

@class CRDLabelCell;
@class CRDServerList;
@class CRDSession;
@class CRDTabView;
@protocol CRDApplicationDelegate;

@interface AppController : NSObject <NSWindowDelegate, CRDApplicationDelegate, NSTableViewDelegate, CRDServerListDataSource>
{
	// Inspector
	IBOutlet NSWindow *gui_inspector;
	IBOutlet NSTextField *gui_label, *gui_host, *gui_username, *gui_password, *gui_domain;
	IBOutlet NSSearchField *gui_searchField;
    IBOutlet NSButton *gui_savePassword, *gui_consoleSession, *gui_forwardDisks, *gui_forwardPrinters, *gui_displayDragging, *gui_drawDesktop, *gui_enableAnimations, *gui_enableThemes, *gui_enableFontSmoothing;
    IBOutlet NSPopUpButton *gui_screenResolution, *gui_colorCount, *gui_hotkey;
	IBOutlet NSBox *gui_performanceOptions;
	IBOutlet NSMatrix *gui_forwardAudio;
    CRDSession *inspectedServer;
	
	// Drawer
	IBOutlet NSDrawer *gui_serversDrawer;
	IBOutlet CRDServerList *gui_serverList;
	IBOutlet NSButton *gui_connectButton, *gui_inspectorButton, *gui_addNewButton;
	CRDLabelCell *connectedServersLabel, *savedServersLabel, *filteredServersLabel;
	
	// Unified window
	IBOutlet NSWindow *gui_unifiedWindow;
	IBOutlet NSComboBox *gui_quickConnect;
	IBOutlet CRDTabView *gui_tabView;
	IBOutlet NSToolbar *gui_toolbar;
	IBOutlet NSToolbarItem *gui_toolbarServers, *gui_toolbarFullscreen, *gui_toolbarWindowed, *gui_toolbarDisconnect;
    
	// Other display modes
	CRDDisplayMode displayMode, displayModeBeforeFullscreen;
	NSPoint windowCascadePoint;
	IBOutlet NSUserDefaultsController *userDefaultsController;
	NSUserDefaults *userDefaults;
	
	// Preferences window
	IBOutlet NSWindow *gui_preferencesWindow;
	
	// Menu
	IBOutlet NSMenu *gui_serversMenu;
	
	// Active sessions, disconnected saved servers, and current search results
	NSMutableArray *connectedServers, *savedServers, *filteredServers;
	
	BOOL _isFilteringSavedServers;
	
	// Support for server dragging
	CRDSession *dumpedInstance;
	BOOL dumpedInstanceWasSelected;
	
	BOOL _appIsTerminating, useMinimalServersList;
}

// Actions
- (IBAction)addNewSavedServer:(id)sender;
- (IBAction)removeSelectedSavedServer:(id)sender;
- (IBAction)connect:(id)sender;
- (IBAction)disconnect:(id)sender;
- (IBAction)performConnectOrDisconnect:(id)sender;
- (IBAction)keepSelectedServer:(id)sender;
- (IBAction)toggleInspector:(id)sender;
- (IBAction)togglePerformanceDisclosure:(id)sender;
- (IBAction)fieldEdited:(id)sender;
- (IBAction)selectNext:(id)sender;
- (IBAction)selectPrevious:(id)sender;
- (IBAction)performStop:(id)sender;
- (IBAction)stopConnection:(id)sender;
- (IBAction)showOpen:(id)sender;
- (IBAction)toggleDrawer:(id)sender;
- (IBAction)startFullscreen:(id)sender;
- (IBAction)endFullscreen:(id)sender;
- (IBAction)performFullScreen:(id)sender;
- (IBAction)performUnified:(id)sender;
- (IBAction)startWindowed:(id)sender;
- (IBAction)startUnified:(id)sender;
- (IBAction)takeScreenCapture:(id)sender;
- (IBAction)performQuickConnect:(id)sender;
- (IBAction)clearQuickConnectHistory:(id)sender;
- (IBAction)jumpToQuickConnect:(id)sender;
- (IBAction)helpForConnectionOptions:(id)sender;
- (IBAction)performServerMenuItem:(id)sender;
- (IBAction)saveSelectedServer:(id)sender;
- (IBAction)sortSavedServersAlphabetically:(id)sender;
- (IBAction)doNothing:(id)sender;
- (IBAction)duplicateSelectedServer:(id)sender;
- (IBAction)filterServers:(id)sender;
- (IBAction)jumpToFilter:(id)sender;
- (IBAction)showServerInFinder:(id)sender;
- (IBAction)visitDevelopment:(id)sender;
- (IBAction)reportABug:(id)sender;
- (IBAction)visitHomepage:(id)sender;
- (IBAction)visitSupportForums:(id)sender;
- (IBAction)closeSessionOrWindow:(id)sender;

// Other methods are in no particular order
- (void)cellNeedsDisplay:(NSCell *)cell;
- (void)connectInstance:(CRDSession *)inst;
- (void)disconnectInstance:(CRDSession *)inst;
- (void)cancelConnectingInstance:(CRDSession *)inst;
- (void)reconnectInstanceForEnteringFullscreen:(CRDSession*)inst;
- (void)parseCommandLine;
- (void)printUsage;
- (void)updateInspectorToMatchSelectedServer;

- (CRDSession *)serverInstanceForRow:(int)row;
- (CRDSession *)selectedServer;
- (CRDSession *)viewedServer;

- (BOOL)mainWindowIsFocused;
- (CRDDisplayMode)displayMode;
- (NSWindow *)unifiedWindow;

- (void)holdSavedServer:(NSInteger)row;
- (void)reinsertHeldSavedServer:(NSInteger)intoRow;

@end

@interface AppController (SharedResources)
+ (NSString *)savedServersPath;
@end




