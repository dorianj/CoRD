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

#import <Carbon/Carbon.h>

#import "AppController.h"
#import "RDInstance.h"
#import "RDCView.h"

#import "CRDServerList.h"
#import "CRDFullScreenWindow.h"
#import "miscellany.h"

static NSImage *shared_documentIcon = nil;

#define TOOLBAR_DISCONNECT	@"Disconnect"
#define TOOLBAR_DRAWER @"Servers"
#define TOOLBAR_FULLSCREEN @"Fullscreen"
#define TOOLBAR_UNIFIED @"Windowed"
#define TOOLBAR_QUICKCONNECT @"Quick connect"

#pragma mark -

@interface AppController (Private)
	- (void)listUpdated;
	- (void)saveInspectedServer;
	- (void)updateInstToMatchInspector:(RDInstance *)inst;
	- (void)setInspectorSettings:(RDInstance *)newSettings;
	- (void)completeConnection:(RDInstance *)inst;
	- (void)connectAsync:(RDInstance *)inst;
	- (void)autosizeUnifiedWindow;
	- (void)autosizeUnifiedWindowWithAnimation:(BOOL)animate;
	- (void)setInspectorEnabled:(BOOL)enabled;
	- (void)toggleControlsEnabledInView:(NSView *)view enabled:(BOOL)enabled;
	- (void)createWindowForInstance:(RDInstance *)inst;
	- (void)toggleDrawer:(id)sender visible:(BOOL)VisibleLength;
@end


#pragma mark -
@implementation AppController

+ (void)initialize
{
	NSDictionary *defaults = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithBool:YES], PREFS_RESIZE_VIEWS,
			[NSNumber numberWithBool:YES], PREFS_FULLSCREEN_RECONNECT,
			nil];
	[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:defaults];	
}

#pragma mark NSObject methods
- (id)init
{
	if (![super init])
		return nil;
		
	userDefaults = [NSUserDefaults standardUserDefaults];
	
	connectedServers = [[NSMutableArray alloc] init];
	savedServers = [[NSMutableArray alloc] init];
	
	connectedServersLabel = [[CRDLabelCell alloc] initTextCell:@"Active sessions"];
	savedServersLabel = [[CRDLabelCell alloc] initTextCell:@"Saved Servers"];

	inspectedServer = nil;

	return self;
}
- (void) dealloc
{
	[resourcePath release];
	[serversDirectory release];
	
	[connectedServers release];
	[savedServers release];
	
	[connectedServersLabel release];
	[savedServersLabel release];
	
	[userDefaults release];
	g_appController = nil;
	[super dealloc];
}

- (void)awakeFromNib
{
	g_appController = self;

	displayMode = CRDDisplayUnified;
	
	[gui_unifiedWindow setAcceptsMouseMovedEvents:YES];
	windowCascadePoint = NSMakePoint(WINDOW_START_X, WINDOW_START_Y);
	
	
	// Create the toolbar 
	{
		NSToolbarItem *quickConnectItem = [[[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_QUICKCONNECT] autorelease];
		[quickConnectItem setView:gui_quickConnect];
		NSSize qcSize = [gui_quickConnect frame].size;
		[quickConnectItem setMinSize:NSMakeSize(110.0, qcSize.height)];
		[quickConnectItem setMaxSize:NSMakeSize(150.0, qcSize.height)];
		[quickConnectItem setLabel:@"Quick Connect"];
		[quickConnectItem setToolTip:@"Connect to a computer with default settings. Uses 'host[:port]' syntax."];
		
		toolbarItems = [[NSMutableDictionary alloc] init];
		
		[toolbarItems 
			setObject:create_static_toolbar_item(TOOLBAR_DRAWER, @"Show Servers",
				@"Hide or show the servers drawer", @selector(toggleDrawer:))
			forKey:TOOLBAR_DRAWER];
		[toolbarItems 
			setObject:create_static_toolbar_item(TOOLBAR_DISCONNECT, @"Disconnect", 
				@"Close the selected connection", @selector(performStop:))
			forKey:TOOLBAR_DISCONNECT];	
		[toolbarItems
			setObject:create_static_toolbar_item(TOOLBAR_FULLSCREEN, @"Full Screen",
				@"Enter fullscreen mode", @selector(startFullscreen:))
			forKey:TOOLBAR_FULLSCREEN];
		[toolbarItems
			setObject:create_static_toolbar_item(TOOLBAR_UNIFIED, @"Windowed",
				@"Toggle between unified mode and windowed mode", @selector(performUnified:))
			forKey:TOOLBAR_UNIFIED];
		[toolbarItems setObject:quickConnectItem forKey:TOOLBAR_QUICKCONNECT];
		
		gui_toolbar = [[NSToolbar alloc] initWithIdentifier:@"CoRDMainToolbar"];
		[gui_toolbar setDelegate:self];
		
		[gui_toolbar setAllowsUserCustomization:YES];
		[gui_toolbar setAutosavesConfiguration:YES];
		
		[gui_unifiedWindow setToolbar:gui_toolbar];
	}
	
	
	// Load saved servers from the CoRD Application Support folder
	{
		NSFileManager *fileManager = [NSFileManager defaultManager];
		
		// Assure that the CoRD application support folder is created, locate and store other useful paths
		NSString *appSupport = 
			[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
				NSUserDomainMask, YES) objectAtIndex:0];
		NSString *cordDirectory = [[appSupport stringByAppendingPathComponent:@"CoRD"] retain];
		serversDirectory = [[cordDirectory stringByAppendingPathComponent:@"Servers"] retain];
		resourcePath = [[NSBundle mainBundle] resourcePath];
		
		ensure_directory_exists(cordDirectory, fileManager);
		ensure_directory_exists(serversDirectory, fileManager);

		// Read each .rdp file
		RDInstance *rdpinfo;
		NSString *path;
		NSArray *files = [fileManager directoryContentsAtPath:serversDirectory];
		NSEnumerator *enumerator = [files objectEnumerator];
		id filename;
		while ( (filename = [enumerator nextObject]) )
		{
			if ([[filename pathExtension] isEqualToString:@"rdp"])
			{
				path = [serversDirectory stringByAppendingPathComponent:filename];
				rdpinfo = [[RDInstance alloc] initWithRDPFile:path];
				if (rdpinfo != nil)
					[savedServers addObject:rdpinfo];
				else
					NSLog(@"RDP file '%@' failed to load!", filename);
					
				[rdpinfo release];
			}
		}
		
	}
	
	// Register for drag operations. xxx: could be done in CRDServersList
	NSArray *types = [NSArray arrayWithObjects:SAVED_SERVER_DRAG_TYPE, NSFilenamesPboardType, NSFilesPromisePboardType, nil];
	[gui_serverList registerForDraggedTypes:types];

	// Since it's a custom class, the attributes pane isn't available for the password entry box in IB.
	[[gui_password cell] setSendsActionOnEndEditing:YES];
	[[gui_password cell] setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];

	// Load this separately from other user defaults because it needs to be loaded before anything is displayed
	displayMode = [[userDefaults objectForKey:DEFAULTS_DISPLAY_MODE] intValue];

	[gui_toolbar validateVisibleItems];
	[self validateControls];
	[self listUpdated];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
	RDInstance *inst = [self selectedServerInstance];
	RDInstance *viewedInst = [self viewedServer];
	SEL action = [item action];
	
    if (action == @selector(removeSelectedSavedServer:))
		return (inst != nil) && ![inst temporary] && [inst status] == CRDConnectionClosed;
    else if (action == @selector(connect:))
        return (inst != nil) && [inst status] == CRDConnectionClosed;
    else if (action == @selector(disconnect:))
		return (inst != nil) && [inst status] != CRDConnectionClosed;
	else if (action == @selector(selectNext:))
		return [gui_tabView numberOfTabViewItems] > 2; /* Greater than 2 because 1 blank is added */ 
	else if (action == @selector(selectPrevious:))
		return [gui_tabView numberOfTabViewItems] > 2;
	else if (action == @selector(toggleInspector:))
	{
		[item setTitle:([gui_inspector isVisible] ? @"Hide Inspector" : @"Show Inspector")];
		return inst != nil;
	}
	else if (action == @selector(toggleDrawer:))
	{
		[item setTitle:(drawer_is_visisble(gui_serversDrawer) ? @"Hide Servers Drawer" : @"Show Servers Drawer")];
	}
	else if (action == @selector(keepSelectedServer:))
	{
		[item setState:([inst temporary] ? NSOffState : NSOnState)];
		return [inst status] == CRDConnectionConnected;
	}
	else if (action == @selector(performFullScreen:)) 
	{
		if ([self displayMode] == CRDDisplayFullscreen) {
			[item setTitle:@"Exit Full Screen"];
			return YES;
		} else {
			[item setTitle:@"Start Full Screen"];
			return [connectedServers count] > 0;			
		}
	}
	
	return YES;
}


#pragma mark -
#pragma mark Actions

- (IBAction)addNewSavedServer:(id)sender
{
	RDInstance *inst = [[[RDInstance alloc] init] autorelease];
	
	NSString *path = increment_file_name(serversDirectory, @"New Server", @".rdp");
		
	[inst setTemporary:NO];
	[inst setRdpFilename:path];
	[inst setLabel:[[path lastPathComponent] stringByDeletingPathExtension]];
	[inst writeRDPFile:nil];
	
	[savedServers addObject:inst];

	[self listUpdated];
	
	NSIndexSet *index = [NSIndexSet indexSetWithIndex:2 + [savedServers indexOfObjectIdenticalTo:inst]];
	[gui_serverList selectRowIndexes:index byExtendingSelection:NO];
	
	if (![gui_inspector isVisible])
		[self toggleInspector:self];
}


/* Removes the currently selected server, and deletes the file.
	todo: allow this to work with connected servers
*/
- (IBAction)removeSelectedSavedServer:(id)sender
{
	RDInstance *inst = [self selectedServerInstance];
	
	if (inst == nil || [inst temporary] || [inst status] != CRDConnectionClosed)
		return;
	
	NSAlert *alert = [NSAlert alertWithMessageText:@"Delete saved server" defaultButton:@"Delete" 
			alternateButton:@"Cancel" otherButton:nil informativeTextWithFormat:@"Are you sure you wish to delete the saved server '%@'?", [inst label]];
	[alert setAlertStyle:NSCriticalAlertStyle];
	
	if ([alert runModal] == NSAlertAlternateReturn)
		return;
		
	[gui_serverList deselectAll:self];
	
	// Remove the server from the list, delete its backing file
	[[NSFileManager defaultManager] removeFileAtPath:[inst rdpFilename] handler:nil];
	[savedServers removeObject:inst];
	
	[self listUpdated];
}

// Connects to the currently selected saved server
- (IBAction)connect:(id)sender
{
	RDInstance *inst = [self selectedServerInstance];
	
	if (inst == nil || [inst status] != CRDConnectionClosed)
		return;
	
	[self connectInstance:inst];
}

// Toggles whether or not the selected server is kept after disconnect
- (IBAction)keepSelectedServer:(id)sender
{
	RDInstance *inst = [self selectedServerInstance];
	if (inst == nil)
		return;
	
	[inst setTemporary:![inst temporary]];
	[self validateControls];
	[self listUpdated];
}

// Disconnects the currently selected active server
- (IBAction)disconnect:(id)sender
{
	RDInstance *inst = [self viewedServer];
	[self disconnectInstance:inst];
}

// Either disconnects the viewed session, or cancels a pending connection
- (IBAction)performStop:(id)sender
{
	RDInstance *inst = [self viewedServer];
	
	if ([[self viewedServer] status]  == CRDConnectionConnected)
		[self disconnect:nil];
	else if ([[self selectedServerInstance] status] == CRDConnectionConnecting)
		[self stopConnection:nil];
}

- (IBAction)stopConnection:(id)sender
{
	[self cancelConnectingInstance:[self selectedServerInstance]];
}


/* Hides or shows the inspector. */
- (IBAction)toggleInspector:(id)sender
{
	BOOL nowVisible = ![gui_inspector isVisible];
	if (nowVisible)
		[gui_inspector makeKeyAndOrderFront:sender];
	else
		[gui_inspector close];	
		
	[self validateControls];
}


// Hides/shows the performance options in inspector.
- (IBAction)togglePerformanceDisclosure:(id)sender
{
	BOOL nowVisible = ([sender state] != NSOffState);
	
	NSRect boxFrame = [gui_performanceOptions frame], windowFrame = [gui_inspector frame];
	
	if (nowVisible) {
		windowFrame.size.height += boxFrame.size.height;	
		windowFrame.origin.y	-= boxFrame.size.height;
	} else {
		windowFrame.size.height -= boxFrame.size.height;
		windowFrame.origin.y	+= boxFrame.size.height;
	}
	
	[gui_performanceOptions setHidden:!nowVisible];
	
	NSSize minSize = [gui_inspector minSize];
	[gui_inspector setMinSize:NSMakeSize(minSize.width, windowFrame.size.height)];
	[gui_inspector setMaxSize:NSMakeSize(FLT_MAX, windowFrame.size.height)];
	[gui_inspector setFrame:windowFrame display:YES animate:YES];
}

// Called whenever anything in the inspector is edited
- (IBAction)fieldEdited:(id)sender
{			
	if (inspectedServer != nil)
	{
		[self updateInstToMatchInspector:inspectedServer];
		[self listUpdated];
	}
}

- (IBAction)selectNext:(id)sender
{
	[gui_tabView selectNextTabViewItem:sender];
	
	RDInstance *inst = [self viewedServer];
	if (inst == nil)
		return;
		
	[gui_serverList selectRow:(1 + [connectedServers indexOfObjectIdenticalTo:inst])];
	[self autosizeUnifiedWindow];
}

- (IBAction)selectPrevious:(id)sender
{
	if ([gui_tabView indexOfTabViewItem:[gui_tabView selectedTabViewItem]] == 1)
		return;
	
	[gui_tabView selectPreviousTabViewItem:sender];
	
	RDInstance *inst = [self viewedServer];
	if (inst == nil)
		return;
		
	[gui_serverList selectRow:(1 + [connectedServers indexOfObjectIdenticalTo:inst])];
	[self autosizeUnifiedWindow];
}

- (IBAction)showOpen:(id)sender
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setAllowsMultipleSelection:YES];
	[panel runModalForTypes:[NSArray arrayWithObject:@"rdp"]];
	NSArray *filenames = [panel filenames];
	if ([filenames count] <= 0)
		return;
	
	[self application:[NSApplication sharedApplication] openFiles:filenames];
}

- (IBAction)toggleDrawer:(id)sender
{
	[self toggleDrawer:sender visible:!drawer_is_visisble(gui_serversDrawer)];
	[gui_toolbar validateVisibleItems];
}

- (IBAction)startFullscreen:(id)sender
{
	if (displayMode == CRDDisplayFullscreen || [connectedServers count] == 0)
		return;
		
	displayModeBeforeFullscreen = displayMode;
	
	// Create the fullscreen window then move the tabview into it	
	RDInstance *inst = [self viewedServer];
	RDCView *serverView = [inst view];
	NSSize serverSize = [serverView bounds].size;	
	NSRect winRect = [[NSScreen mainScreen] frame];

	// If needed, reconnect the instance so that it can fill the screen
	if (![[inst valueForKey:@"fullscreen"] boolValue]  && PREFERENCE_ENABLED(PREFS_FULLSCREEN_RECONNECT) &&
		( fabs(serverSize.width - winRect.size.width) > 0.001 || fabs(serverSize.height - winRect.size.height) > 0.001) )
	{
		[self disconnectInstance:inst];
		[inst setValue:[NSNumber numberWithBool:YES] forKey:@"fullscreen"];
		[inst setValue:[NSNumber numberWithBool:YES] forKey:@"temporarilyFullscreen"];
		instanceReconnectingForFullscreen = inst;
		[self connectInstance:inst];
		return;
	}
	
	if ([self displayMode] != CRDDisplayUnified)
		[self startUnified:self];
	
	instanceReconnectingForFullscreen = nil;
	
	gui_fullScreenWindow = [[CRDFullScreenWindow alloc] initWithScreen:[NSScreen mainScreen]];	
	
	[gui_tabView retain];
	[gui_tabView removeFromSuperviewWithoutNeedingDisplay];
	[[gui_fullScreenWindow contentView] addSubview:gui_tabView];
	[gui_fullScreenWindow setInitialFirstResponder:serverView];
	[gui_tabView release];	
	
	NSSize serverViewSize = [serverView bounds].size;
	[gui_tabView setFrame:NSMakeRect(0.0, 0.0, serverViewSize.width, serverViewSize.height)];
	
	[gui_fullScreenWindow startFullScreen];

	[gui_fullScreenWindow makeFirstResponder:serverView];
	
	displayMode = CRDDisplayFullscreen;
}

- (IBAction)endFullscreen:(id)sender
{
	if ([self displayMode] != CRDDisplayFullscreen)
		return;
	
	displayMode = CRDDisplayUnified;
	[self autosizeUnifiedWindowWithAnimation:NO];
	
	[gui_tabView retain];
	[gui_tabView removeFromSuperviewWithoutNeedingDisplay];
	
	NSSize contentSize = [[gui_unifiedWindow contentView] frame].size;
	
	// Autosizing will get screwed up if the size is bigger than the content view
	[gui_tabView setFrame:NSMakeRect(0.0, 0.0, contentSize.width, contentSize.height)];
	
	[[gui_unifiedWindow contentView] addSubview:gui_tabView];
	[gui_tabView release];
	
	[gui_unifiedWindow display];
	
	
	if (displayModeBeforeFullscreen == CRDDisplayWindowed)
		[self startWindowed:self];
		
	// Animate the fullscreen window fading away
	NSDictionary *fadeWindow = [NSDictionary dictionaryWithObjectsAndKeys:
						gui_fullScreenWindow, NSViewAnimationTargetKey,
						NSViewAnimationFadeInEffect, NSViewAnimationEffectKey,
						nil];
	NSViewAnimation *viewAnim = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:fadeWindow]];
	[viewAnim setAnimationBlockingMode:NSAnimationBlocking];
	[viewAnim setDuration:0.5];
	[viewAnim setAnimationCurve:NSAnimationEaseOut];
	
	[viewAnim startAnimation];
	[viewAnim release];	

	[gui_fullScreenWindow close];
	gui_fullScreenWindow = nil;

	displayMode = displayModeBeforeFullscreen;
}

// Toggles between fullscreen and previous state
- (IBAction)performFullScreen:(id)sender
{
	if ([self displayMode] == CRDDisplayFullscreen)
		[self endFullscreen:sender];
	else
		[self startFullscreen:sender];
}

- (IBAction)performUnified:(id)sender
{
	if (displayMode == CRDDisplayUnified)
		[self startWindowed:sender];
	else if (displayMode == CRDDisplayWindowed)
		[self startUnified:sender];
	
	[gui_toolbar validateVisibleItems];
}

- (IBAction)startWindowed:(id)sender
{
	if (displayMode == CRDDisplayWindowed)
		return;
	
	displayMode = CRDDisplayWindowed;
	
	if ([connectedServers count] == 0)
		return;
	
	NSEnumerator *enumerator = [connectedServers objectEnumerator];
	RDInstance *inst;
	
	while ( (inst = [enumerator nextObject]) )
	{
		[gui_tabView removeTabViewItem:[inst tabViewRepresentation]];
		[self createWindowForInstance:inst];
	}	
		
	[self autosizeUnifiedWindow];
}

- (IBAction)startUnified:(id)sender
{
	if (displayMode == CRDDisplayUnified || displayMode == CRDDisplayFullscreen)
		return;
		
	displayMode = CRDDisplayUnified;
	
	if ([connectedServers count] == 0)
		return;
	
	NSEnumerator *enumerator = [connectedServers objectEnumerator];
	RDInstance *inst;
	
	while ( (inst = [enumerator nextObject]) )
	{
		[inst destroyWindow];
		[inst createUnified:!PREFERENCE_ENABLED(PREFS_RESIZE_VIEWS) enclosure:[gui_tabView frame]];
		[gui_tabView addTabViewItem:[inst tabViewRepresentation]];
	}	
	
	[gui_tabView selectLastTabViewItem:self];
	
	if ([self selectedServerInstance])
		[gui_unifiedWindow setTitle:[[self viewedServer] label]];
	else
		[gui_unifiedWindow setTitle:@"CoRD"];
	
	[self autosizeUnifiedWindowWithAnimation:(sender != self)];
}

- (IBAction)takeScreenCapture:(id)sender
{
	RDInstance *inst = [self viewedServer];
	
	if (inst == nil)
		return;
	
	NSString *desktopFolder = [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES)
				objectAtIndex:0];
	
	NSString *path = increment_file_name(desktopFolder,
				[[inst label] stringByAppendingString:@" Screen Capture"], @".png");
	
	[[inst view] writeScreenCaptureToFile:path];
}

- (IBAction)performQuickConnect:(id)sender
{
	NSString *address = [gui_quickConnect stringValue], *hostname;
	int port;
	
	split_hostname(address, &hostname, &port);
	
	RDInstance *newInst = [[[RDInstance alloc] init] autorelease];
	
	[newInst setValue:[NSNumber numberWithInt:16] forKey:@"screenDepth"];
	[newInst setValue:hostname forKey:@"label"];
	[newInst setValue:hostname forKey:@"hostName"];
	[newInst setValue:[NSNumber numberWithInt:port] forKey:@"port"];
	
	[connectedServers addObject:newInst];
	[gui_serverList deselectAll:self];
	[self listUpdated];
	[self connectInstance:newInst];
	
	
	NSMutableArray *recent = [NSMutableArray arrayWithArray:[userDefaults arrayForKey:DEFAULTS_RECENT_SERVERS]];
	
	if ([recent containsObject:address])
		[recent removeObject:address];
	
	if ([recent count] > 10)
		[recent removeLastObject];
	
	[recent insertObject:address atIndex:0];
	[userDefaults setObject:recent forKey:DEFAULTS_RECENT_SERVERS];
	[userDefaults synchronize];
}


#pragma mark -
#pragma mark Toolbar methods

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar 
		itemForItemIdentifier:(NSString *)itemIdentifier 
		willBeInsertedIntoToolbar:(BOOL)flag
{	
	return [toolbarItems objectForKey:itemIdentifier];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)tb
{
		NSMutableArray *menuExtras = [NSMutableArray arrayWithObjects:
				NSToolbarSeparatorItemIdentifier,
				NSToolbarSpaceItemIdentifier,
				NSToolbarFlexibleSpaceItemIdentifier, nil];
		[menuExtras addObjectsFromArray:[toolbarItems allKeys]];
		return menuExtras;
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)tb
{

	NSMutableArray *defaultItems = [NSArray arrayWithObjects:
				TOOLBAR_DRAWER,
				NSToolbarSeparatorItemIdentifier,
				TOOLBAR_QUICKCONNECT,
				NSToolbarFlexibleSpaceItemIdentifier,
				TOOLBAR_FULLSCREEN,
				TOOLBAR_UNIFIED, 
				NSToolbarFlexibleSpaceItemIdentifier,
				TOOLBAR_DISCONNECT,
				nil];
	return defaultItems;
}

-(BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
	NSString *itemId = [toolbarItem itemIdentifier];
	
	RDInstance *inst = [self selectedServerInstance];
	RDInstance *viewedInst = [self viewedServer];
	
	if ([itemId isEqualToString:TOOLBAR_DRAWER])
		[toolbarItem setLabel:(drawer_is_visisble(gui_serversDrawer) ? @"Hide Servers" : @"Show Servers")];
	else if ([itemId isEqualToString:TOOLBAR_FULLSCREEN])
		return ([connectedServers count] > 0);
	else if ([itemId isEqualToString:TOOLBAR_UNIFIED] && (displayMode != CRDDisplayFullscreen))
	{
		NSString *label = (displayMode == CRDDisplayUnified) ? @"Windowed" : @"Unified";
		[toolbarItem setImage:[NSImage imageNamed:[label stringByAppendingString:@".png"]]];
		[toolbarItem setLabel:label];	
	}
	else if ([itemId isEqualToString:TOOLBAR_DISCONNECT])
	{
		NSString *label = ([inst status] == CRDConnectionConnecting) ? @"Stop" : @"Disconnect";
		[toolbarItem setLabel:label];
		[toolbarItem setImage:[NSImage imageNamed:[label stringByAppendingString:@".png"]]];
		return ([inst status] == CRDConnectionConnecting) || 
				( (viewedInst != nil) && (displayMode == CRDDisplayUnified) );
	}
	
	return YES;
}


#pragma mark -
#pragma mark NSApplication delegate methods

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
	[self application:sender openFiles:[NSArray arrayWithObject:filename]];
	return YES;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
	NSEnumerator *enumerator = [filenames objectEnumerator];
	id file;
	while ( (file = [enumerator nextObject]) )
	{
		RDInstance *inst = [[RDInstance alloc] initWithRDPFile:file];
		
		if (inst != nil)
		{
			[inst setTemporary:YES];
			[connectedServers addObject:inst];
			[gui_serverList deselectAll:self];
			[self listUpdated];
			[self connectInstance:inst];	
		}
	}
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)theApplication
{
    return NO;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	[self tableViewSelectionDidChange:nil];
	
	// Save drawer state to user defaults
	[userDefaults setBool:drawer_is_visisble(gui_serversDrawer) forKey:DEFAULTS_SHOW_DRAWER];
	[userDefaults setFloat:[gui_serversDrawer contentSize].width forKey:DEFAULTS_DRAWER_WIDTH];
	
	if (displayMode == CRDDisplayFullscreen)
		displayMode = displayModeBeforeFullscreen;
	[userDefaults setInteger:displayMode forKey:DEFAULTS_DISPLAY_MODE];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{	
	// Make sure the drawer is in the user-saved position. Do it here (not awakeFromNib) so that it displays nicely
	if ([userDefaults objectForKey:DEFAULTS_SHOW_DRAWER] != nil)
	{		
		float width = [userDefaults floatForKey:DEFAULTS_DRAWER_WIDTH];
		float height = [gui_serversDrawer contentSize].height;
		if (width > 0)
			[gui_serversDrawer setContentSize:NSMakeSize(width, height)];
			
		if ([userDefaults boolForKey:DEFAULTS_SHOW_DRAWER])
			[self toggleDrawer:self visible:YES];
	}
	else
	{
		[self toggleDrawer:self visible:YES];
	}
}


#pragma mark -
#pragma mark NSTableDataSource methods

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return 2 + [connectedServers count] + [savedServers count];
}

- (id)tableView:(NSTableView *)aTableView
		objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	if (rowIndex == 0)
		return [connectedServersLabel attributedStringValue];
	else if (rowIndex == [connectedServers count] + 1)
		return [savedServersLabel attributedStringValue];
	else
		return [self serverInstanceForRow:rowIndex]; 
}

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info
		proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{	
	if ([info draggingSource] == gui_serverList)
	{
		// Inner list drag
		return NSDragOperationNone;
	} 
	else
	{
		// External drag, make sure there's at least one RDP file in there
		NSArray *files = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
		NSArray *rdpFiles = filter_filenames(files, [NSArray arrayWithObjects:@"rdp",nil]);
		
		return ([rdpFiles count] > 0) ? NSDragOperationCopy : NSDragOperationNone;
	}
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
		row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	//TRACE_FUNC;

	if ([info draggingSource] == gui_serverList)
	{
		// inner list drag, currently ignoring. Todo: allow for item moving
		return NO;
	} 
	else
	{
		// External drag, load all rdp files passed
		NSArray *files = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
		NSArray *rdpFiles = filter_filenames(files, [NSArray arrayWithObjects:@"rdp",nil]);
		
		RDInstance *inst, *base = [self serverInstanceForRow:row];
		NSEnumerator *enumerator = [rdpFiles objectEnumerator];
		id file;
		
		while ( (file = [enumerator nextObject]) )
		{
			inst = [[RDInstance alloc] initWithRDPFile:file];
			
			if (inst != nil)
				[savedServers insertObject:inst atIndex:[savedServers indexOfObject:base]];
			
			[inst release];
		}
		
		return YES;
	}
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes
		toPasteboard:(NSPasteboard*)pboard
{
	//TRACE_FUNC;

	RDInstance *inst = [self serverInstanceForRow:[rowIndexes firstIndex]];
	
	if (inst == nil || [inst temporary]) // xxx: currently bails if not a saved server
		return NO;
			
	[pboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:nil];
	[pboard setPropertyList:[NSArray arrayWithObject:[inst rdpFilename]] forType:NSFilenamesPboardType];
	
	return YES;
}


#pragma mark NSTableView delegate

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	int selectedRow = [gui_serverList selectedRow];
	RDInstance *inst = [self selectedServerInstance];
	
	[self validateControls];
	[self fieldEdited:nil];
	
	// If there's no selection, clear the inspector
	if (selectedRow == -1)
	{
		[self setInspectorSettings:nil];	
		inspectedServer = nil;
		[self setInspectorEnabled:NO];
		
		return;
	} else {
		[inspectedServer writeRDPFile:nil];	
	}

	[self setInspectorEnabled:YES];
	
	inspectedServer =  inst;
	[self setInspectorSettings:inst];
	
	// If the new selection is an active session and this wasn't called from self, change the selected view
	if (inst != nil && aNotification != nil && [inst status] == CRDConnectionConnected)
	{
		if (displayMode == CRDDisplayWindowed)
		{
			[[inst window] makeKeyAndOrderFront:self];
			[[inst window] makeFirstResponder:[inst view]];
		}
		else if ([gui_tabView indexOfTabViewItem:[inst tabViewRepresentation]] != NSNotFound)
		{
			[gui_tabView selectTabViewItem:[inspectedServer tabViewRepresentation]];
			[gui_unifiedWindow makeFirstResponder:[[self viewedServer] view]];
			[gui_unifiedWindow setTitle:[inspectedServer label]];
			[self autosizeUnifiedWindow];
		}
	}
	
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(int)rowIndex
{
	return (rowIndex >= 1) && (rowIndex != [connectedServers count] + 1);
}

- (float)tableView:(NSTableView *)tableView heightOfRow:(int)row
{	
	if (row == 0 || row == [connectedServers count] + 1)
		return [connectedServersLabel cellSize].height;
	else
		return [[[self serverInstanceForRow:row] cellRepresentation] cellSize].height;
}

- (id) tableColumn:(NSTableColumn *)column inTableView:(NSTableView *)tableView dataCellForRow:(int)row
{
	if (row == 0)
		return connectedServersLabel;
	else if (row == [connectedServers count] + 1)
		return savedServersLabel;
	else 
		return [[self serverInstanceForRow:row] cellRepresentation];
}

#pragma mark Other table view related
- (void)cellNeedsDisplay:(NSCell *)cell
{
	[gui_serverList setNeedsDisplay:YES];
}


#pragma mark -
#pragma mark NSTabView delegate

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	if ([self viewedServer] == nil)
		return;
	
	// xxx: May be used to auto-center tab view items (otherwise an NSTabView subclass will be made)
}


#pragma mark -
#pragma mark Managing inspector settings

// Sets all of the values in the passed RDInstance to match the inspector
- (void)updateInstToMatchInspector:(RDInstance *)inst
{
	// Checkboxes
	[inst setValue:BUTTON_STATE_AS_NUMBER(gui_cacheBitmaps)		forKey:@"cacheBitmaps"];
	[inst setValue:BUTTON_STATE_AS_NUMBER(gui_displayDragging)	forKey:@"windowDrags"];
	[inst setValue:BUTTON_STATE_AS_NUMBER(gui_drawDesktop)		forKey:@"drawDesktop"];
	[inst setValue:BUTTON_STATE_AS_NUMBER(gui_enableAnimations)	forKey:@"windowAnimation"];
	[inst setValue:BUTTON_STATE_AS_NUMBER(gui_enableThemes)		forKey:@"themes"];
	[inst setValue:BUTTON_STATE_AS_NUMBER(gui_savePassword)		forKey:@"savePassword"];
	[inst setValue:BUTTON_STATE_AS_NUMBER(gui_forwardDisks)		forKey:@"forwardDisks"];
	[inst setValue:BUTTON_STATE_AS_NUMBER(gui_consoleSession)	forKey:@"consoleSession"];
	
	// Text fields
	[inst setValue:[gui_label stringValue] forKey:@"label"];
	[inst setValue:[gui_username stringValue] forKey:@"username"];
	[inst setValue:[gui_domain stringValue]	 forKey:@"domain"];	
	[inst setValue:[gui_password stringValue] forKey:@"password"];
	
	// Host/port
	int port;
	NSString *s;
	split_hostname([gui_host stringValue], &s, &port);
	[inst setValue:[NSNumber numberWithInt:port] forKey:@"port"];
	[inst setValue:s forKey:@"hostName"];
	
	// Screen depth
	[inst setValue:[NSNumber numberWithInt:([gui_colorCount indexOfSelectedItem]+1)*8]
			forKey:@"screenDepth"];
			
	// Screen resolution
	int width, height;
	if ([gui_screenResolution indexOfSelectedItem] == 0)
	{
		[inst setValue:[NSNumber numberWithBool:YES] forKey:@"fullscreen"];
		width = height = 0;
	}
	else
	{
		NSScanner *scanner = [NSScanner scannerWithString:[gui_screenResolution titleOfSelectedItem]];
		[scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"x"]];
		[scanner scanInt:&width]; [scanner scanInt:&height];
		[inst setValue:[NSNumber numberWithBool:NO] forKey:@"fullscreen"];
	}
	[inst setValue:[NSNumber numberWithInt:width]  forKey:@"screenWidth"];
	[inst setValue:[NSNumber numberWithInt:height] forKey:@"screenHeight"];
	
}

/* Sets the inspector options to match an RDInstance */
- (void)setInspectorSettings:(RDInstance *)newSettings
{
	if (newSettings == nil)
	{
		[gui_inspector setTitle:@"Inspector: No Server Selected"];
		newSettings = [[[RDInstance alloc] init] autorelease];
	}
	else
	{
		[gui_inspector setTitle:[@"Inspector: " stringByAppendingString:[newSettings label]]];
	}
		
	// Set the checkboxes 
	[gui_cacheBitmaps		setState:NUMBER_AS_BSTATE([newSettings valueForKey:@"cacheBitmaps"])];
	[gui_displayDragging	setState:NUMBER_AS_BSTATE([newSettings valueForKey:@"windowDrags"])];
	[gui_drawDesktop		setState:NUMBER_AS_BSTATE([newSettings valueForKey:@"drawDesktop"])];
	[gui_enableAnimations	setState:NUMBER_AS_BSTATE([newSettings valueForKey:@"windowAnimation"])];
	[gui_enableThemes		setState:NUMBER_AS_BSTATE([newSettings valueForKey:@"themes"])];
	[gui_savePassword		setState:NUMBER_AS_BSTATE([newSettings valueForKey:@"savePassword"])];
	[gui_forwardDisks		setState:NUMBER_AS_BSTATE([newSettings valueForKey:@"forwardDisks"])];
	[gui_consoleSession		setState:NUMBER_AS_BSTATE([newSettings valueForKey:@"consoleSession"])];
	
	// Set some of the textfield inputs
	[gui_label    setStringValue:[newSettings valueForKey:@"label"]];
	[gui_username setStringValue:[newSettings valueForKey:@"username"]];
	[gui_domain   setStringValue:[newSettings valueForKey:@"domain"]];
	[gui_password setStringValue:[newSettings valueForKey:@"password"]];
	
	// Set host
	int port = [[newSettings valueForKey:@"port"] intValue];
	NSString *host = [newSettings valueForKey:@"hostName"];
	
	[gui_host setStringValue:full_host_name(host, port)];
	
	// Set the color depth
	int colorDepth = [[newSettings valueForKey:@"screenDepth"] intValue];
	[gui_colorCount selectItemAtIndex:(colorDepth/8-1)];
	
	// Set the resolution
	if ([[newSettings valueForKey:@"fullscreen"] boolValue])
	{
		[gui_screenResolution selectItemAtIndex:0];
	}
	else 
	{
		int screenWidth = [[newSettings valueForKey:@"screenWidth"] intValue];
		int screenHeight = [[newSettings valueForKey:@"screenHeight"] intValue]; 
		if (screenWidth == 0 || screenHeight == 0) {
			screenWidth = 1024;
			screenHeight = 768;
		}
		
		NSString *resolutionLabel = [NSString stringWithFormat:@"%dx%d", screenWidth, screenHeight];
		// If this resolution doesn't exist in the pop-up box, create it. Either way, select it.
		if ([gui_screenResolution itemWithTitle:resolutionLabel] == nil)
			[gui_screenResolution addItemWithTitle:resolutionLabel];
		[gui_screenResolution selectItemWithTitle:resolutionLabel];
	}
	
	
}

- (void) saveInspectedServer
{
	if ([inspectedServer modified])
		[inspectedServer writeRDPFile:nil];
}


#pragma mark -
#pragma mark NSWindow delegate

- (BOOL)windowShouldClose:(id)sender
{
	if (sender == gui_unifiedWindow)
	{
		// todo: fix this up so unified window is always accessable to users, but can
		//	be closed during windowed mode (also, show it when the last active session closes)
		//if (displayMode == CRDDisplayUnified || ([connectedServers count] == 0))
			[[NSApplication sharedApplication] hide:self];
			
		return NO;
	}
		
	return YES;
}

- (void)windowWillClose:(NSNotification *)sender
{
	if ([sender object] == gui_inspector)
	{
		[self fieldEdited:nil];
		[self saveInspectedServer];
		inspectedServer = nil;
		[self validateControls];
	}
}

- (void)windowDidBecomeKey:(NSNotification *)sender
{
	if ( ([sender object] == gui_unifiedWindow) && (displayMode == CRDDisplayUnified) )
	{
		[[self viewedServer] synchronizeRemoteClipboard:[NSPasteboard generalPasteboard] suggestedFormat:CF_TEXT];
	}
}


#pragma mark -
#pragma mark Managing connected servers

// Starting point to connect to a instance
- (void)connectInstance:(RDInstance *)inst
{
	if (inst == nil)
		return;
	
	if ([inst status] == CRDConnectionConnected)
		[self disconnectInstance:inst];
		
	[inst retain];
	[NSThread detachNewThreadSelector:@selector(connectAsync:) toTarget:self withObject:inst];
}

// Should only be called by connectInstance
- (void)connectAsync:(RDInstance *)inst
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	if ([[inst valueForKey:@"fullscreen"] boolValue])
	{
		NSSize screenSize = [[gui_unifiedWindow screen] frame].size;
		[inst setValue:[NSNumber numberWithInt:(int)screenSize.width] forKey:@"screenWidth"];
		[inst setValue:[NSNumber numberWithInt:(int)screenSize.height] forKey:@"screenHeight"];
	}
	
	BOOL connected = [inst connect];
	
	[self performSelectorOnMainThread:@selector(completeConnection:)
			withObject:inst waitUntilDone:NO];
					
	if (connected)	
		[inst startInputRunLoop];

	[inst release];
	[pool release];
}

// Called in main thread by connectAsync
- (void)completeConnection:(RDInstance *)inst
{
	if ([inst status] == CRDConnectionConnected)
	{
		// Move it into the proper list
		if (![inst temporary])
		{
			[inst retain];
			[savedServers removeObject:inst];
			[connectedServers addObject:inst];
			[inst release];
		}
		
		NSIndexSet *index = [NSIndexSet indexSetWithIndex:1 + [connectedServers indexOfObject:inst]];
		[gui_serverList selectRowIndexes:index byExtendingSelection:NO];
		[self listUpdated];
		
		// Create gui
		if (displayMode == CRDDisplayUnified || displayMode == CRDDisplayFullscreen)
		{
			[inst createUnified:!PREFERENCE_ENABLED(PREFS_RESIZE_VIEWS) enclosure:[gui_tabView frame]];
			[gui_tabView addTabViewItem:[inst tabViewRepresentation]];
			[gui_tabView selectLastTabViewItem:self];
			[gui_unifiedWindow setTitle:[inst label]];
			[gui_unifiedWindow makeFirstResponder:[inst view]];
		}
		else
		{
			[self createWindowForInstance:inst];
		}
		
		
		if ([[inst valueForKey:@"fullscreen"] boolValue] || [[inst valueForKey:@"temporarilyFullscreen"] boolValue])
		{
			[self startFullscreen:self];	
			return;	
		}
		
		if (displayMode == CRDDisplayUnified)
		{
			[self autosizeUnifiedWindow];
		}
		
	}
	else
	{

		[self cellNeedsDisplay:(NSCell *)[inst cellRepresentation]];
		ConnectionErrorCode errorCode = [inst conn]->errorCode;
		
		if (errorCode != ConnectionErrorNone && errorCode != ConnectionErrorCanceled)
		{
			if ([inst temporary])
			{
				[connectedServers removeObject:inst];
				[self listUpdated];
			}
			
			NSString *descs[] = {
					@"No error",
					@"The connection timed out.",
					@"The host name could not be resolved.",
					@"There was an error connecting.",
					@"You canceled the connection." };
			NSString *title = [NSString stringWithFormat:@"Couldn't connect to %@", [inst label]];
			
			NSAlert *alert = [NSAlert alertWithMessageText:title defaultButton:nil
						alternateButton:@"Retry" otherButton:nil informativeTextWithFormat:descs[errorCode]];
			[alert setAlertStyle:NSCriticalAlertStyle];
			
			// Retry if requested
			if ([alert runModal] == NSAlertAlternateReturn)
			{
				[self connectInstance:inst];
			}
			else if ([inst temporary]) // Temporary items are added to the active session before connecting, so remove on failure
			{
				[connectedServers removeObject:inst];
				[self listUpdated];
			}
		}
	}	
}

// Assures that the passed instance is disconnected and removed from view.
- (void)disconnectInstance:(RDInstance *)inst
{
	if (inst == nil || [connectedServers indexOfObjectIdenticalTo:inst] == NSNotFound)
		return;
		
	if (displayMode != CRDDisplayWindowed && [inst tabViewRepresentation] != nil)
	{
		[gui_tabView removeTabViewItem:[inst tabViewRepresentation]];
	}
	
	if ([inst status] == CRDConnectionConnected)
		[inst disconnect];
		
	if ([[inst valueForKey:@"temporarilyFullscreen"] boolValue])
	{
		[inst setValue:[NSNumber numberWithBool:NO] forKey:@"fullscreen"];
		[inst setValue:[NSNumber numberWithBool:NO] forKey:@"temporarilyFullscreen"];
	}
	
	// If it's not temporary, move it to the saved servers list. Update the table view
	//	and selection as needed.
	[inst retain];
	[connectedServers removeObject:inst];
	
	if (![inst temporary])
	{
		if ([inst rdpFilename] == nil)
		{
			NSString *path = increment_file_name(serversDirectory, [inst label], @".rdp");
			[inst setRdpFilename:path];
			[inst writeRDPFile:path];
		}
		
		[savedServers addObject:inst];
		NSIndexSet *index = [NSIndexSet indexSetWithIndex:(2 + [connectedServers count] + [savedServers indexOfObjectIdenticalTo:inst])];
		[gui_serverList selectRowIndexes:index byExtendingSelection:NO];
	} 
	else
	{
		if ( [[[inst rdpFilename] stringByDeletingLastPathComponent] isEqualToString:serversDirectory])
		{
			[[NSFileManager defaultManager] removeFileAtPath:[inst rdpFilename] handler:nil];
		}
		
		[gui_serverList deselectAll:self];
	}
	
	[inst release];

	[self listUpdated];
		
	if (displayMode == CRDDisplayFullscreen && [gui_tabView numberOfTabViewItems] == 1)
	{
		[self autosizeUnifiedWindowWithAnimation:NO];
		[self endFullscreen:self];
	}
	else if (displayMode == CRDDisplayUnified)
	{
		[self autosizeUnifiedWindow];
	}
}

- (void)cancelConnectingInstance:(RDInstance *)inst
{
	if ([inst status] != CRDConnectionConnecting)
		return;
	
	[inst cancelConnection];
}


#pragma mark -
#pragma mark Other methods

- (BOOL)mainWindowIsFocused
{
	return [gui_unifiedWindow isMainWindow] && [gui_unifiedWindow isKeyWindow];
}

- (void)toggleDrawer:(id)sender visible:(BOOL)visible
{
	if (visible)
		[gui_serversDrawer open];
	else
		[gui_serversDrawer close];
	
	[gui_toolbar validateVisibleItems];
}

- (void)autosizeUnifiedWindow
{
	[self autosizeUnifiedWindowWithAnimation:YES];
}

- (void)autosizeUnifiedWindowWithAnimation:(BOOL)animate
{
	RDInstance *inst = [self viewedServer];
	NSSize newContentSize;
	if ([self displayMode] == CRDDisplayUnified && inst != nil)
	{
		newContentSize = [[inst view] bounds].size;
		[gui_unifiedWindow setContentMaxSize:newContentSize];
	}
	else
	{
		newContentSize = NSMakeSize(600, 400);
		[gui_unifiedWindow setContentMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
	}

	NSRect windowFrame = [gui_unifiedWindow frame];
	NSRect screenRect = [[gui_unifiedWindow screen] visibleFrame];
	
	if (PREFERENCE_ENABLED(PREFS_RESIZE_VIEWS))
		[gui_unifiedWindow setContentAspectRatio:newContentSize];
	else
		[gui_unifiedWindow setContentResizeIncrements:NSMakeSize(1.0,1.0)];
	
	float scrollerWidth = [NSScroller scrollerWidth];
	float toolbarHeight = windowFrame.size.height - [[gui_unifiedWindow contentView] frame].size.height;
	
	NSRect newWindowFrame = NSMakeRect( windowFrame.origin.x, windowFrame.origin.y +
										windowFrame.size.height-newContentSize.height-toolbarHeight, 
										newContentSize.width, newContentSize.height + toolbarHeight);
	
	float drawerWidth = [gui_serversDrawer contentSize].width + 
			([[[gui_serversDrawer contentView] window] frame].size.width-[gui_serversDrawer contentSize].width) / 2.0 + 1.0;
	
	// For our adjustments, add the drawer width
	if ([gui_serversDrawer state] == NSDrawerOpenState)
	{
		if ([gui_serversDrawer edge] == NSMinXEdge) // left side
			newWindowFrame.origin.x -= drawerWidth;
		
		newWindowFrame.size.width += drawerWidth;
	}
	
	newWindowFrame.size.width = MIN(screenRect.size.width, newWindowFrame.size.width);
	newWindowFrame.size.height = MIN(screenRect.size.height, newWindowFrame.size.height);
	
	
	// Assure that no unneccesary scrollers are created
	if (!PREFERENCE_ENABLED(PREFS_RESIZE_VIEWS))
	{
		
		if (newWindowFrame.size.height > screenRect.size.height &&
			newWindowFrame.size.width + scrollerWidth <= screenRect.size.width)
		{
			newWindowFrame.origin.y = screenRect.origin.y;
			newWindowFrame.size.height = screenRect.size.height;
			newWindowFrame.size.width += scrollerWidth;

		}
		if (newWindowFrame.size.width > screenRect.size.width &&
					newWindowFrame.size.height+scrollerWidth <= screenRect.size.height)
		{
			newWindowFrame.origin.x = screenRect.origin.x;
			newWindowFrame.size.width = screenRect.size.width;
			newWindowFrame.size.height += scrollerWidth;
		}
	}
	
	// Try to make it contained within the screen
	if (newWindowFrame.origin.y < screenRect.origin.y && newWindowFrame.size.height <= screenRect.size.height)
	{
		newWindowFrame.origin.y = screenRect.origin.y;
	}
	
	if (newWindowFrame.origin.x + newWindowFrame.size.width > screenRect.size.width)
	{
		newWindowFrame.origin.x -= (newWindowFrame.origin.x + newWindowFrame.size.width) - (screenRect.origin.x + screenRect.size.width);
		newWindowFrame.origin.x = MAX(newWindowFrame.origin.x, screenRect.origin.x);
	}
	
		
	// Reset window rect to exclude drawer
	if ([gui_serversDrawer state] == NSDrawerOpenState)
	{
		float drawerWidth = [gui_serversDrawer contentSize].width;
		drawerWidth += ([[[gui_serversDrawer contentView] window] frame].size.width - drawerWidth) / 2.0 + 1;
		if ([gui_serversDrawer edge] == NSMinXEdge) // left side
			newWindowFrame.origin.x += drawerWidth;

		newWindowFrame.size.width -= drawerWidth;
	}
	
	
	// Assure that the aspect ratio is correct
	if (PREFERENCE_ENABLED(PREFS_RESIZE_VIEWS))
	{
		float bareWindowHeight = (newWindowFrame.size.height - toolbarHeight);
		float realAspect = newContentSize.width / newContentSize.height;
		float proposedAspect = newWindowFrame.size.width / bareWindowHeight;
		
		if (fabs(realAspect - proposedAspect) > 0.001)
		{
			if (realAspect > proposedAspect)
			{
				float oldHeight = newWindowFrame.size.height;
				newWindowFrame.size.height = toolbarHeight + newWindowFrame.size.width * (1.0 / realAspect);
				newWindowFrame.origin.y += oldHeight - newWindowFrame.size.height;
			}
			else
				newWindowFrame.size.width = newWindowFrame.size.height * realAspect;			
		}
	}
	
	[gui_unifiedWindow setFrame:newWindowFrame display:YES animate:animate];
}

#pragma mark -
#pragma mark Internal use
- (void) listUpdated
{	
	[gui_serverList reloadData];
	[gui_serverList setNeedsDisplay:YES];
}

- (RDInstance *)serverInstanceForRow:(int)row
{
	int connectedCount = [connectedServers count];
	int savedCount = [savedServers count];
	if ( (row <= 0) || (row == 1+connectedCount) || (row > 1 + connectedCount + savedCount) )
		return nil;
	else if (row <= connectedCount)
		return [connectedServers objectAtIndex:row-1];
	else 
		return [savedServers objectAtIndex:row - connectedCount - 2];
}

- (RDInstance *)selectedServerInstance
{
	return [self serverInstanceForRow:[gui_serverList selectedRow]];
}

// Returns the connected server that the tab view is displaying
- (RDInstance *)viewedServer
{
	if (displayMode == CRDDisplayUnified || displayMode == CRDDisplayFullscreen)
	{
		NSTabViewItem *selectedItem = [gui_tabView selectedTabViewItem];

		if (selectedItem == nil)
			return nil;
			
		NSEnumerator *enumerator = [connectedServers objectEnumerator];
		id item;
		
		while ( (item = [enumerator nextObject]) )
		{
			if ([item tabViewRepresentation] == selectedItem)
				return item;
		}
	}
	else
	{
		NSEnumerator *enumerator = [connectedServers objectEnumerator];
		RDInstance *inst;
		
		while ( (inst = [enumerator nextObject]) )
		{
			if ([[inst window] isMainWindow])
				return inst;
		}
	}
	
	return nil;
}

// Enables/disables gui controls as needed
- (void)validateControls
{
	RDInstance *inst = [self serverInstanceForRow:[gui_serverList selectedRow]];
	
	[gui_connectButton setEnabled:(inst != nil && [inst status] == CRDConnectionClosed)];
	[gui_inspectorButton setEnabled:(inst != nil)];
}

- (void)setInspectorEnabled:(BOOL)enabled
{
	[self toggleControlsEnabledInView:[gui_inspector contentView] enabled:enabled];
	[gui_inspector display];
}

- (void)toggleControlsEnabledInView:(NSView *)view enabled:(BOOL)enabled
{
	if ([view isKindOfClass:[NSControl class]])
	{
		if ([view isKindOfClass:[NSTextField class]] && ![(NSTextField *)view drawsBackground])
		{
			// setTextColor is buggy in 10.4, thus use white to get the greyed color while disabled
			if (enabled)
				[(NSTextField *)view setTextColor:[NSColor blackColor]];
			else
				[(NSTextField *)view setTextColor:[NSColor whiteColor]];

		}
		[(NSControl *)view setEnabled:enabled];
	}
	else
	{
		NSEnumerator *enumerator = [[view subviews] objectEnumerator];
		id subview;
		while ( (subview = [enumerator nextObject]) )
		{
			[self toggleControlsEnabledInView:subview enabled:enabled];
		}
	}
	
}

- (void)createWindowForInstance:(RDInstance *)inst
{
	[inst createWindow:!PREFERENCE_ENABLED(PREFS_RESIZE_VIEWS)];
	
	NSWindow *window = [inst window];
	[window cascadeTopLeftFromPoint:windowCascadePoint];
	[window makeFirstResponder:[inst view]];
	[window makeKeyAndOrderFront:self];
}


#pragma mark -
#pragma mark Accessors

- (CRDDisplayMode)displayMode
{
	return displayMode;
}

- (NSWindow *)unifiedWindow
{
	return gui_unifiedWindow;
}

- (CRDFullScreenWindow *)fullScreenWindow
{
	return gui_fullScreenWindow;
}


#pragma mark -
#pragma mark Application-wide resources
+ (NSImage *)sharedDocumentIcon
{
	if (shared_documentIcon == nil)
	{
		// The stored icon is loaded flipped for whatever reason, so flip it back
		NSImage *icon = [NSImage imageNamed:@"rdp document.icns"];
		shared_documentIcon = [[NSImage alloc] initWithSize:[icon size]];
		[icon setFlipped:YES];
		[shared_documentIcon lockFocus];
		
		NSRect r = NSMakeRect(0.0,0.0, [icon size].width, [icon size].height);
		[icon drawInRect:r fromRect:r operation:NSCompositeSourceOver fraction:1.0];
		
		[shared_documentIcon unlockFocus];
		
	}
	
	return shared_documentIcon;
}


@end
