/*	Copyright (c) 2007-2008 Dorian Johnson <info-2008@dorianjohnson.com>
	
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

#import <Carbon/Carbon.h>

#import "AppController.h"
#import "CRDSession.h"
#import "CRDSessionView.h"

#import "CRDServerList.h"
#import "CRDFullScreenWindow.h"
#import "CRDTabView.h"
#import "CRDShared.h"
#import "CRDLabelCell.h"

#define TOOLBAR_DISCONNECT	@"Disconnect"
#define TOOLBAR_DRAWER @"Servers"
#define TOOLBAR_FULLSCREEN @"Fullscreen"
#define TOOLBAR_UNIFIED @"Windowed"
#define TOOLBAR_QUICKCONNECT @"Quick Connect"
#define TOOLBAR_QUICKCONNECTCONSOLE @"Quick Connect Console"

#pragma mark -

@interface AppController (Private)
	- (void)listUpdated;
	- (void)saveInspectedServer;
	- (void)updateInstToMatchInspector:(CRDSession *)inst;
	- (void)setInspectorSettings:(CRDSession *)newSettings;
	- (void)completeConnection:(CRDSession *)inst;
	- (void)connectAsync:(CRDSession *)inst;
	- (void)autosizeUnifiedWindow;
	- (void)autosizeUnifiedWindowWithAnimation:(BOOL)animate;
	- (void)setInspectorEnabled:(BOOL)enabled;
	- (void)toggleControlsEnabledInView:(NSView *)view enabled:(BOOL)enabled;
	- (void)createWindowForInstance:(CRDSession *)inst;
	- (void)toggleDrawer:(id)sender visible:(BOOL)VisibleLength;
	- (void)addSavedServer:(CRDSession *)inst;
	- (void)addSavedServer:(CRDSession *)inst atIndex:(int)index;
	- (void)addSavedServer:(CRDSession *)inst atIndex:(int)index select:(BOOL)select;
	- (void)removeSavedServer:(CRDSession *)inst deleteFile:(BOOL)deleteFile;
	- (void)sortSavedServersByStoredListPosition;
	- (void)sortSavedServersAlphabetically;
	- (void)storeSavedServerPositions;
	- (void)validateControls;
@end


#pragma mark -
@implementation AppController

+ (void)initialize
{
	[[NSUserDefaults standardUserDefaults] registerDefaults: [NSDictionary dictionaryWithContentsOfFile:
		[[NSBundle mainBundle] pathForResource: @"Defaults" ofType: @"plist"]]];
		
	//LSSetDefaultHandlerForURLScheme(@"rdp", 
}

- (id)init
{
	if (![super init])
		return nil;
		
	userDefaults = [NSUserDefaults standardUserDefaults];
	
	connectedServers = [[NSMutableArray alloc] init];
	savedServers = [[NSMutableArray alloc] init];
	
	connectedServersLabel = [[CRDLabelCell alloc] 
			initTextCell:NSLocalizedString(@"Active sessions", @"Servers list label 1")];
	savedServersLabel = [[CRDLabelCell alloc]
			initTextCell:NSLocalizedString(@"Saved Servers", @"Servers list label 2")];

	return self;
}
- (void) dealloc
{
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
	windowCascadePoint = CRDWindowCascadeStart;
	
	
	// Create the toolbar 
	NSToolbarItem *quickConnectItem = [[[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_QUICKCONNECT] autorelease];
	[quickConnectItem setView:gui_quickConnect];
	NSSize qcSize = [gui_quickConnect frame].size;
	[quickConnectItem setMinSize:NSMakeSize(160.0, qcSize.height)];
	[quickConnectItem setMaxSize:NSMakeSize(160.0, qcSize.height)];
	[quickConnectItem setPaletteLabel:NSLocalizedString(@"Quick Connect", @"Quick Connect toolbar item -> label")];
	[quickConnectItem setValue:NSLocalizedString(@"Quick Connect", @"Quick Connect toolbar item -> label") forKey:@"label"];
	[quickConnectItem setToolTip:NSLocalizedString(@"Quick Connect Tooltip", @"Quick Connect toolbar item -> tooltip")];
	
	NSToolbarItem *quickConnectConsoleItem = [[[NSToolbarItem alloc] initWithItemIdentifier:TOOLBAR_QUICKCONNECTCONSOLE] autorelease];
	[quickConnectConsoleItem setView:gui_quickConnectConsole];
	[quickConnectConsoleItem setPaletteLabel:NSLocalizedString(@"Quick Connect Console", @"Quick Connect Console toolbar item -> label")];
	[quickConnectConsoleItem setValue:NSLocalizedString(@"Quick Connect Console", @"Quick Connect Console toolbar item -> label") forKey:@"label"];
	[quickConnectConsoleItem setToolTip:NSLocalizedString(@"Quick Connect Console Tooltip", @"Quick Connect Console toolbar item -> tooltip")];
	
	
	toolbarItems = [[NSMutableDictionary alloc] init];
	
	[toolbarItems 
		setObject:CRDMakeToolbarItem(TOOLBAR_DRAWER, 
			NSLocalizedString(@"Servers", @"Hide/show drawer toolbar item -> label"),
			NSLocalizedString(@"Toggle Servers Drawer", @"Hide/show drawer toolbar item -> tooltip"),
			@selector(toggleDrawer:))
		forKey:TOOLBAR_DRAWER];
	[toolbarItems 
		setObject:CRDMakeToolbarItem(TOOLBAR_DISCONNECT,
			NSLocalizedString(@"Disconnect", @"Disconnect toolbar item -> label"), 
			NSLocalizedString(@"Close selected connection", @"Disconnect toolbar item -> tooltip"),
			@selector(performStop:))
		forKey:TOOLBAR_DISCONNECT];	
	[toolbarItems
		setObject:CRDMakeToolbarItem(TOOLBAR_FULLSCREEN,
			NSLocalizedString(@"Full Screen", @"Full Screen toolbar item -> label"),
			NSLocalizedString(@"Enter fullscreen mode", @"Disconnect toolbar item -> tool tip"),
			@selector(startFullscreen:))
		forKey:TOOLBAR_FULLSCREEN];
	[toolbarItems
		setObject:CRDMakeToolbarItem(TOOLBAR_UNIFIED,
			NSLocalizedString(@"Windowed", @"Display Mode toolbar item -> label"),
			NSLocalizedString(@"Switch between unified and windowed mode", @"Display Mode toolbar item -> tool tip"),
			@selector(performUnified:))
		forKey:TOOLBAR_UNIFIED];
	
	[toolbarItems setObject:quickConnectItem forKey:TOOLBAR_QUICKCONNECT];
	[toolbarItems setObject:quickConnectConsoleItem	forKey:TOOLBAR_QUICKCONNECTCONSOLE];
	
	gui_toolbar = [[NSToolbar alloc] initWithIdentifier:@"CoRDMainToolbar"];
	[gui_toolbar setDelegate:self];
	
	[gui_toolbar setAllowsUserCustomization:YES];
	[gui_toolbar setAutosavesConfiguration:YES];
	
	[gui_unifiedWindow setToolbar:gui_toolbar];

	
	// Assure that the app support directory exists
	NSString *appSupport = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	
	CRDCreateDirectory([appSupport stringByAppendingPathComponent:@"CoRD"]);
	CRDCreateDirectory([AppController savedServersPath]);
	
	
	// Load servers from the saved servers directory
	CRDSession *savedSession;
	NSArray *files = [[NSFileManager defaultManager] directoryContentsAtPath:[AppController savedServersPath]];
	NSEnumerator *enumerator = [files objectEnumerator];
	id filename;
	while ( (filename = [enumerator nextObject]) )
	{
		if ([[filename pathExtension] isEqualToString:@"rdp"])
		{
			savedSession = [[CRDSession alloc] initWithPath:[[AppController savedServersPath] stringByAppendingPathComponent:filename]];
			if (savedSession != nil)
				[self addSavedServer:savedSession];
			else
				NSLog(@"RDP file '%@' failed to load!", filename);
				
			[savedSession release];
		}
	}
	
	[gui_serverList deselectAll:nil];
	[self sortSavedServersByStoredListPosition];
	[self storeSavedServerPositions];
	
	
	// Register for drag operations
	NSArray *types = [NSArray arrayWithObjects:CRDRowIndexPboardType, NSFilenamesPboardType, NSFilesPromisePboardType, nil];
	[gui_serverList registerForDraggedTypes:types];

	// Custom interface settings not accessable from IB
	[[gui_password cell] setSendsActionOnEndEditing:YES];
	[[gui_password cell] setFont:[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]]];
	[gui_unifiedWindow setExcludedFromWindowsMenu:YES];
	[gui_tabView setAnimatesWhenSwitchingItems:NO];

	// Load a few user defaults that need to be loaded before anything is displayed
	displayMode = [[userDefaults objectForKey:CRDDefaultsDisplayMode] intValue];

	// Register for preferences KVO notification
	[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:@"MinimalServerList" options:NSKeyValueObservingOptionNew context:NULL];
	
	[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(openUrl:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
	
	[gui_toolbar validateVisibleItems];
	[self validateControls];
	[self listUpdated];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
	BOOL drawerVisible = CRDDrawerIsVisible(gui_serversDrawer);
	CRDSession *inst = [self selectedServer];
	CRDSession *viewedInst = [self viewedServer];
	SEL action = [item action];
	
    if (action == @selector(removeSelectedSavedServer:))
		return (inst != nil) && ![inst temporary] && ([inst status] == CRDConnectionClosed);
    else if (action == @selector(connect:))
        return (inst != nil) && [inst status] == CRDConnectionClosed;
    else if (action == @selector(disconnect:))
		return (inst != nil) && [inst status] != CRDConnectionClosed;
	else if (action == @selector(selectNext:))
		return [gui_tabView numberOfItems] > 1;
	else if (action == @selector(selectPrevious:))
		return [gui_tabView numberOfItems] > 1;
	else if (action == @selector(takeScreenCapture:))
		return viewedInst != nil;
	else if (action == @selector(performDisconnect:))
		return [NSApp keyWindow] != nil;
	else if (action == @selector(duplicateSelectedServer:))
		return [self selectedServer] != nil;
	else if (action == @selector(toggleInspector:))
	{
		NSString *hideOrShow = [gui_inspector isVisible]
				? NSLocalizedString(@"Hide Inspector", @"View menu -> Show Inspector")
				: NSLocalizedString(@"Show Inspector", @"View menu -> Hide Inspector");
		[item setTitle:hideOrShow];
		return inst != nil;
	}
	else if (action == @selector(toggleDrawer:))
	{
		NSString *hideOrShow = CRDDrawerIsVisible(gui_serversDrawer)
				? NSLocalizedString(@"Hide Servers Drawer", @"View menu -> Show Servers Drawer")
				: NSLocalizedString(@"Show Servers Drawer", @"View menu -> Hide Servers Drawer");
		[item setTitle:hideOrShow];
	}
	else if (action == @selector(keepSelectedServer:))
	{
		[item setState:CRDButtonState(![inst temporary])];
		return [inst status] == CRDConnectionConnected;
	}
	else if (action == @selector(performFullScreen:)) 
	{
		if ([self displayMode] == CRDDisplayFullscreen) {
			[item setTitle:NSLocalizedString(@"Exit Full Screen", @"View menu -> Exit Full Screen")];
			return YES;
		} else {
			[item setTitle:NSLocalizedString(@"Start Full Screen", @"View menu -> Start Full Screen")];
			return [connectedServers count] > 0;			
		}
	}
	else if (action == @selector(performServerMenuItem:))
	{
		CRDSession *representedInst = [item representedObject];
		[item setState:([connectedServers indexOfObject:representedInst] != NSNotFound ? NSOnState : NSOffState)];	
	}
	else if (action == @selector(performConnectOrDisconnect:))
	{
		NSString *localizedDisconnect = NSLocalizedString(@"Disconnect", @"Servers menu -> Disconnect/connect item");
		NSString *localizedConnect = NSLocalizedString(@"Connect", @"Servers menu -> Disconnect/connect item");
	
		if (viewedInst != nil)
			[item setTitle:localizedDisconnect];
		else if (inst == nil)
			return NO;
		else
			[item setTitle:([inst status] == CRDConnectionClosed) ? localizedConnect : localizedDisconnect];
	}
	
	return YES;
}


#pragma mark -
#pragma mark Actions

- (IBAction)addNewSavedServer:(id)sender
{
	if (![gui_unifiedWindow isVisible])
		[gui_unifiedWindow makeKeyAndOrderFront:nil];

	if (!CRDDrawerIsVisible(gui_serversDrawer))
		[self toggleDrawer:nil visible:YES];
		
	CRDSession *inst = [[[CRDSession alloc] init] autorelease];
	
	NSString *path = CRDFindAvailableFileName([AppController savedServersPath],
			NSLocalizedString(@"New Server", @"Name of newly added servers"), @".rdp");
		
	[inst setTemporary:NO];
	[inst setFilename:path];
	[inst setValue:[[path lastPathComponent] stringByDeletingPathExtension] forKey:@"label"];
	[inst flushChangesToFile];
	
	[self addSavedServer:inst];
	
	[inst setValue:[NSNumber numberWithInt:[savedServers indexOfObjectIdenticalTo:inst]] forKey:@"preferredRowIndex"];
	
	if (![gui_inspector isVisible])
		[self toggleInspector:nil];
}


// Removes the currently selected server, and deletes the file.
- (IBAction)removeSelectedSavedServer:(id)sender
{
	CRDSession *inst = [self selectedServer];
	
	if (inst == nil || [inst temporary] || ([inst status] != CRDConnectionClosed) )
		return;
	
	NSAlert *alert = [NSAlert alertWithMessageText:
				NSLocalizedString(@"Delete saved server", @"Delete server confirm alert -> Title")
			defaultButton:NSLocalizedString(@"Delete", @"Delete server confirm alert -> Yes button") 
			alternateButton:NSLocalizedString(@"Cancel", @"Delete server confirm alert -> Cancel button")
			otherButton:nil
			informativeTextWithFormat:NSLocalizedString(@"Really delete", @"Delete server confirm alert -> Detail text"),
			[inst label]];
	[alert setAlertStyle:NSCriticalAlertStyle];
	
	if ([alert runModal] == NSAlertAlternateReturn)
		return;
	
	if ([inst status] != CRDConnectionClosed)
		[self performStop:nil];
		
	[gui_serverList deselectAll:self];
	
	[self removeSavedServer:inst deleteFile:YES];
	
	[self listUpdated];
	[self autosizeUnifiedWindowWithAnimation:NO];
}

// Connects to the currently selected saved server
- (IBAction)connect:(id)sender
{
	CRDSession *inst = [self selectedServer];
	
	if (inst == nil)
		return;
		
	if ( ([inst status] == CRDConnectionConnected) && (displayMode == CRDDisplayWindowed) )
	{
		[[inst window] makeKeyAndOrderFront:self];
		[[inst window] makeFirstResponder:[inst view]];
	}
	else if ([inst status] != CRDConnectionConnected)
	{
		[self connectInstance:inst];
	}	
}

// Disconnects the currently selected active server
- (IBAction)disconnect:(id)sender
{
	CRDSession *inst = [self viewedServer];
	[self disconnectInstance:inst];
}

// Either connects or disconnects the selected server, depending on whether it's connected
- (IBAction)performConnectOrDisconnect:(id)sender
{
	CRDSession *inst = [self selectedServer];
	
	if ([inst status] == CRDConnectionClosed)
		[self connectInstance:inst];
	else
		[self performStop:nil];
}


// Toggles whether or not the selected server is kept after disconnect
- (IBAction)keepSelectedServer:(id)sender
{
	CRDSession *inst = [self selectedServer];
	if (inst == nil)
		return;
	
	[inst setTemporary:![inst temporary]];
	[self validateControls];
	[self listUpdated];
}

// Either disconnects the viewed session, or cancels a pending connection
- (IBAction)performStop:(id)sender
{
	CRDSession *inst = [self viewedServer];
	
	if ([[self viewedServer] status]  == CRDConnectionConnected)
		[self disconnect:nil];
	else if ([[self serverInstanceForRow:[gui_serverList selectedRow]] status] == CRDConnectionConnecting)
		[self stopConnection:nil];
}

- (IBAction)stopConnection:(id)sender
{
	[self cancelConnectingInstance:[self serverInstanceForRow:[gui_serverList selectedRow]]];
}


// Hides or shows the inspector.
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
	[gui_tabView selectNextItem:sender];
	
	CRDSession *inst = [self viewedServer];
	if (inst == nil)
		return;
		
	[gui_serverList selectRow:(1 + [connectedServers indexOfObjectIdenticalTo:inst])];
	[self autosizeUnifiedWindow];
}

- (IBAction)selectPrevious:(id)sender
{
	if ([gui_tabView indexOfSelectedItem] == 1)
		return;
	
	[gui_tabView selectPreviousItem:sender];
	
	CRDSession *inst = [self viewedServer];
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
	[self toggleDrawer:sender visible:!CRDDrawerIsVisible(gui_serversDrawer)];
	[gui_toolbar validateVisibleItems];
}

- (IBAction)startFullscreen:(id)sender
{
	if (displayMode == CRDDisplayFullscreen || ![connectedServers count] || ![self viewedServer])
		return;
	
	displayModeBeforeFullscreen = displayMode;
	
	// Create the fullscreen window then move the tabview into it	
	CRDSession *inst = [self viewedServer];
	CRDSessionView *serverView = [inst view];
	NSSize serverSize = [serverView bounds].size;	
	NSRect winRect = [[NSScreen mainScreen] frame];

	// If needed, reconnect the instance so that it can fill the screen
	if (CRDPreferenceIsEnabled(CRDPrefsReconnectIntoFullScreen) && ( fabs(serverSize.width - winRect.size.width) > 0.001 || fabs(serverSize.height - winRect.size.height) > 0.001) )
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
	[gui_fullScreenWindow setDelegate:self];
	[gui_tabView setAnimatesWhenSwitchingItems:YES];
	
	[[gui_tabView retain] autorelease];
	

	// Force the unified window to maintain content by copying currently viewed server into an NSImageView and display it. see endFullscreen for details on why. xxx: doesn't do the right thing when scrollers are on (needs to copy full tabview, but cacheDisplayInRectAsImage'ing gui_tabView doesn't work since CRDSessionView is opengl
	NSImageView *visibleSessionCacheImageView = nil;
	if (![[inst valueForKey:@"usesScrollers"] boolValue])
	{
		visibleSessionCacheImageView = [[[NSImageView alloc] initWithFrame:(NSRect){NSZeroPoint, [serverView bounds].size}] autorelease];
		[visibleSessionCacheImageView setImage:[serverView cacheDisplayInRectAsImage:[serverView bounds]]];
		[visibleSessionCacheImageView setImageScaling:NSScaleProportionally];
	} 
	else
	{
		// Capture the scrollbar and the image of the server separately since the server won't show up naturally
		NSImage *fullCapture = [[gui_unifiedWindow contentView] cacheDisplayInRectAsImage:[[gui_unifiedWindow contentView] frame]]; // start with just scrollbars
		
		[fullCapture lockFocus]; {
			NSRect visibleSessionRect = [[serverView enclosingScrollView] documentVisibleRect];
			NSRect drawnRect = NSMakeRect(NSMinX(visibleSessionRect), [serverView screenSize].height-NSHeight(visibleSessionRect), NSWidth(visibleSessionRect), visibleSessionRect.size.height);		
			float yScrollerAdjust = NSWidth([serverView bounds]) > NSWidth(visibleSessionRect) ? [NSScroller scrollerWidth] : 0.0f; 
			[[serverView cacheDisplayInRectAsImage:(NSRect){NSZeroPoint, [serverView screenSize]}] drawInRect:(NSRect){{0, yScrollerAdjust}, drawnRect.size} fromRect:drawnRect operation:NSCompositeSourceOver fraction:1.0];
		} [fullCapture unlockFocus];
				
		visibleSessionCacheImageView = [[[NSImageView alloc] initWithFrame:(NSRect){NSZeroPoint, [[gui_unifiedWindow contentView] frame].size}] autorelease];
		[visibleSessionCacheImageView setImage:fullCapture];
		[visibleSessionCacheImageView setImageScaling:NSScaleNone];
	}
		
	[visibleSessionCacheImageView setImageFrameStyle:NSImageFrameNone];
	[visibleSessionCacheImageView setFrame:CRDRectFromSize([[gui_unifiedWindow contentView] frame].size)];
	
	NSDisableScreenUpdates(); {
		[[gui_tabView retain] autorelease];
		[gui_tabView removeFromSuperviewWithoutNeedingDisplay];
		[[gui_unifiedWindow contentView] addSubview:visibleSessionCacheImageView];
		[gui_unifiedWindow display];
	} NSEnableScreenUpdates();
	
	[gui_tabView setFrame:CRDRectFromSize([gui_fullScreenWindow frame].size)];

	if (CRDPreferenceIsEnabled(CRDPrefsScaleSessions))
	{
		NSSize fullScreenWindowSize = [gui_fullScreenWindow frame].size, sessionSize = [serverView screenSize];
		if ( (sessionSize.width > fullScreenWindowSize.width) || (sessionSize.height > fullScreenWindowSize.height) )
		{
			NSSize newSessionSize = CRDProportionallyScaleSize(sessionSize, fullScreenWindowSize);
			[serverView setFrame:CRDRectFromSize(newSessionSize)];
		}
	}
	
	
	[[gui_fullScreenWindow contentView] addSubview:gui_tabView];
	
	NSEnableScreenUpdates(); // Disable may have been used for slightly deferred fullscreen (see completeConnection:)
	[gui_fullScreenWindow startFullScreen];

	[gui_fullScreenWindow makeFirstResponder:serverView];
	
	[visibleSessionCacheImageView removeFromSuperview];
	
	displayMode = CRDDisplayFullscreen;
}

- (IBAction)endFullscreen:(id)sender
{
	if ([self displayMode] != CRDDisplayFullscreen)
		return;
	
	BOOL animate = !_appIsTerminating;
	
	CRDSession *inst = [self selectedServer];
	CRDSessionView *sessionView = [inst view];
	
	[gui_fullScreenWindow prepareForExit];

	// Misc preparation
	[gui_tabView setAnimatesWhenSwitchingItems:NO];
	displayMode = CRDDisplayUnified;
	[self autosizeUnifiedWindowWithAnimation:NO];
	

	// Force the full screen window to maintain content by copying currently viewed server into an NSImageView and display it. The OpenGL-drawing CRDSession doesn't play nicely with being moved between windows (it clears the fullscreen window as soon as it's removed by removeFromSuperviewWithoutNeedingDisplay). xxx: same scroller problem as startFullscreen
	
	NSImageView *visibleSessionCacheImageView = nil;
	if (![[inst valueForKey:@"usesScrollers"] boolValue])
	{
		visibleSessionCacheImageView = [[[NSImageView alloc] initWithFrame:(NSRect){NSZeroPoint, [sessionView bounds].size}] autorelease];
		[visibleSessionCacheImageView setImage:[sessionView cacheDisplayInRectAsImage:[sessionView bounds]]];
		[visibleSessionCacheImageView setImageScaling:NSScaleProportionally];
	} 
	else
	{
		// Capture the scrollbar and the image of the server separately since the server won't show up naturally
		NSImage *fullCapture = [[gui_fullScreenWindow contentView] cacheDisplayInRectAsImage:[[gui_fullScreenWindow contentView] frame]]; // start with just scrollbars
		
		[fullCapture lockFocus]; {
			NSRect visibleSessionRect = [[sessionView enclosingScrollView] documentVisibleRect];
			NSRect drawnRect = NSMakeRect(NSMinX(visibleSessionRect), [sessionView screenSize].height-NSHeight(visibleSessionRect), NSWidth(visibleSessionRect), visibleSessionRect.size.height);
			float yScrollerAdjust = NSWidth([sessionView bounds]) > NSWidth(visibleSessionRect) ? [NSScroller scrollerWidth] : 0.0f; 
			[[sessionView cacheDisplayInRectAsImage:(NSRect){NSZeroPoint, [sessionView screenSize]}] drawInRect:(NSRect){{0, yScrollerAdjust}, drawnRect.size} fromRect:drawnRect operation:NSCompositeSourceOver fraction:1.0];
		} [fullCapture unlockFocus];
		
		visibleSessionCacheImageView = [[[NSImageView alloc] initWithFrame:(NSRect){NSZeroPoint, [[gui_unifiedWindow contentView] frame].size}] autorelease];
		[visibleSessionCacheImageView setImage:fullCapture];
		[visibleSessionCacheImageView setImageScaling:NSScaleNone];
	}
		
	
	[visibleSessionCacheImageView setImageFrameStyle:NSImageFrameNone];
	[visibleSessionCacheImageView setFrame:CRDRectFromSize([gui_fullScreenWindow frame].size)];
	
	NSDisableScreenUpdates(); {
		[[gui_tabView retain] autorelease];
		[gui_tabView removeFromSuperviewWithoutNeedingDisplay];
		[[gui_fullScreenWindow contentView] addSubview:visibleSessionCacheImageView];
		[gui_fullScreenWindow display];
	} NSEnableScreenUpdates();
	
	
	// Move the tab view to the unified view
	
	// Autosizing will get screwed up if the size is bigger than the content view
	[gui_tabView setFrame:CRDRectFromSize([[gui_unifiedWindow contentView] frame].size)];
	
	[[gui_unifiedWindow contentView] addSubview:gui_tabView];	
	[gui_unifiedWindow display];
	
	if (displayModeBeforeFullscreen == CRDDisplayWindowed)
		[self startWindowed:self];
		
	// Animate the fullscreen window fading away, dispose of window
	[gui_fullScreenWindow exitFullScreenWithAnimation:animate];
	gui_fullScreenWindow = nil;
	
	displayMode = displayModeBeforeFullscreen;
	
	if (displayMode == CRDDisplayUnified)
		[gui_unifiedWindow makeKeyAndOrderFront:nil];
	else
		[[[self selectedServer] window] makeKeyAndOrderFront:nil];
}

// Toggles between full screen and previous state
- (IBAction)performFullScreen:(id)sender
{
	if ([self displayMode] == CRDDisplayFullscreen)
		[self endFullscreen:sender];
	else
		[self startFullscreen:sender];
}

// Toggles between Windowed and Unified modes
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
	CRDSession *inst;
	
	while ( (inst = [enumerator nextObject]) )
	{
		[gui_tabView removeItem:inst];
		[self createWindowForInstance:inst];
	}	
		
	[self autosizeUnifiedWindow];
}

- (IBAction)startUnified:(id)sender
{
	if (displayMode == CRDDisplayUnified || displayMode == CRDDisplayFullscreen)
		return;
		
	displayMode = CRDDisplayUnified;
	
	if (![connectedServers count])
		return;
	
	NSEnumerator *enumerator = [connectedServers objectEnumerator];
	CRDSession *inst;
	
	while ( (inst = [enumerator nextObject]) )
	{
		[inst destroyWindow];
		[inst createUnified:!CRDPreferenceIsEnabled(CRDPrefsScaleSessions) enclosure:[gui_tabView frame]];
		[gui_tabView addItem:inst];
	}	
	
	[gui_tabView selectLastItem:self];
	
	[self autosizeUnifiedWindowWithAnimation:(sender != self)];
}

- (IBAction)takeScreenCapture:(id)sender
{
	CRDSession *inst = [self viewedServer];
	
	if (inst == nil)
		return;
	
	NSString *desktopFolder = [NSSearchPathForDirectoriesInDomains(NSDesktopDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	
	NSString *path = CRDFindAvailableFileName(desktopFolder, [[inst label] stringByAppendingString:NSLocalizedString(@" Screen Capture", @"File name for screen captures")], @".png");
	
	[[inst view] writeScreenCaptureToFile:path];
}

- (IBAction)performQuickConnect:(id)sender
{
	NSString *address = [gui_quickConnect stringValue], *hostname, *consoleSes = [gui_quickConnectConsole stringValue];
	int port;
	
	CRDSplitHostNameAndPort(address, &hostname, &port);
	
	CRDSession *newInst = [[[CRDSession alloc] init] autorelease];
	
	[newInst setValue:[NSNumber numberWithInt:16] forKey:@"screenDepth"];
	[newInst setValue:hostname forKey:@"label"];
	[newInst setValue:hostname forKey:@"hostName"];
	[newInst setValue:[NSNumber numberWithInt:port] forKey:@"port"];
	[newInst setValue:[NSNumber numberWithInt:[consoleSes intValue]] forKey:@"consoleSession"];
	
	[connectedServers addObject:newInst];
	[gui_serverList deselectAll:self];
	[self listUpdated];
	[self connectInstance:newInst];
	
	
	NSMutableArray *recent = [NSMutableArray arrayWithArray:[userDefaults arrayForKey:CRDDefaultsQuickConnectServers]];
	
	if ([recent containsObject:address])
		[recent removeObject:address];
	
	if ([recent count] > 10)
		[recent removeLastObject];
	
	[recent insertObject:address atIndex:0];
	[userDefaults setObject:recent forKey:CRDDefaultsQuickConnectServers];
	[userDefaults synchronize];
}

- (IBAction)helpForConnectionOptions:(id)sender
{
    [[NSHelpManager sharedHelpManager] openHelpAnchor:@"ConnectionOptions"
			inBook: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleHelpBookName"]];
}

// Sent when a server in the Server menu is clicked on; either connects to the server or makes it visible
- (IBAction)performServerMenuItem:(id)sender
{
	CRDSession *inst = [sender representedObject];
	
	if (inst == nil)
		return;
		
	if ([connectedServers indexOfObject:inst] != NSNotFound)
	{
		// connected server, switch to it
		if (displayMode == CRDDisplayUnified)
		{
			[gui_tabView selectItem:inst];
			[gui_unifiedWindow makeFirstResponder:[inst view]];
			[self autosizeUnifiedWindow];
		}
		else if (displayMode == CRDDisplayWindowed)
		{
			[[inst window] makeKeyAndOrderFront:nil];
			[[inst window] makeFirstResponder:[inst view]];
		}
	}
	else
	{
		[self connectInstance:inst];
	}
}

// If in unified and with sessions, disconnects active. Otherwise, close the window. Similar to Safari/Camino's 'Close Tab'
- (IBAction)performDisconnect:(id)sender
{
	if ( ( ([self displayMode] == CRDDisplayUnified) || ([self displayMode] == CRDDisplayFullscreen)) && ![self viewedServer])
		[self disconnect:nil];
	else
	{
		CRDSession *inst = [self viewedServer];
		if (inst)
			[[inst window] performClose:nil];
	}
}

- (IBAction)saveSelectedServer:(id)sender
{
	CRDSession *inst = [self selectedServer];
	
	if (inst == nil)
		return;
		
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	[savePanel setTitle:[NSLocalizedString(@"Save Server As", @"Save server dialog -> Title") stringByAppendingFormat:@" '%@'"]];
	
	[savePanel setAllowedFileTypes:[NSArray arrayWithObject:@"rdp"]];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setExtensionHidden:NO];
	

	[savePanel beginSheetForDirectory:nil file:[[inst label] stringByAppendingPathExtension:@"rdp"] modalForWindow:gui_unifiedWindow modalDelegate:self didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) contextInfo:inst];
}

- (IBAction)sortSavedServersAlphabetically:(id)sender
{
	[self sortSavedServersAlphabetically];
	[self storeSavedServerPositions];
	[self listUpdated];
}

- (IBAction)doNothing:(id)sender
{

}

- (IBAction)duplicateSelectedServer:(id)sender
{
	CRDSession *selectedServer = [self selectedServer];
	
	if (!selectedServer)
		return;
	
	int serverIndex;
	
	if ( (serverIndex = [savedServers indexOfObject:selectedServer]) == NSNotFound)
		serverIndex = [savedServers count]-1;
	
	CRDSession *duplicate = [selectedServer copy];
	[duplicate setFilename:CRDFindAvailableFileName([AppController savedServersPath], [duplicate label], @".rdp")];
	[duplicate flushChangesToFile];
	[self addSavedServer:duplicate atIndex:serverIndex+1 select:YES];
	[gui_serverList noteNumberOfRowsChanged];
}

- (IBAction)jumpToQuickConnect:(id)sender
{
	if (![gui_quickConnect currentEditor]) {
		[[gui_quickConnect window] makeFirstResponder:gui_quickConnect];
	} 
}


#pragma mark -
#pragma mark Toolbar methods

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{	
	return [toolbarItems objectForKey:itemIdentifier];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)tb
{
		NSMutableArray *extras = [NSArray arrayWithObjects:
				NSToolbarSeparatorItemIdentifier,
				NSToolbarSpaceItemIdentifier,
				NSToolbarFlexibleSpaceItemIdentifier, nil];
		
		NSArray *allowedItems = [toolbarItems allKeys];
			
		return [extras arrayByAddingObjectsFromArray:allowedItems];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)tb
{
	NSMutableArray *defaultUnifiedItems = [NSArray arrayWithObjects:
				TOOLBAR_DRAWER,
				NSToolbarSeparatorItemIdentifier,
				TOOLBAR_QUICKCONNECT,
				TOOLBAR_QUICKCONNECTCONSOLE,
				NSToolbarFlexibleSpaceItemIdentifier,
				TOOLBAR_FULLSCREEN,
				TOOLBAR_UNIFIED, 
				NSToolbarFlexibleSpaceItemIdentifier,
				TOOLBAR_DISCONNECT,
				nil];
				
	if ( displayMode == CRDDisplayWindowed)
		return defaultUnifiedItems;
	else
		return defaultUnifiedItems;
}

-(BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
	NSString *itemId = [toolbarItem itemIdentifier];
	
	CRDSession *inst = [self selectedServer];
	CRDSession *viewedInst = [self viewedServer];
	
	if ([itemId isEqualToString:TOOLBAR_FULLSCREEN])
		return ([connectedServers count] > 0);
	else if ([itemId isEqualToString:TOOLBAR_UNIFIED] && (displayMode != CRDDisplayFullscreen))
	{
		NSString *label = (displayMode == CRDDisplayUnified) ? @"Windowed" : @"Unified";
		NSString *localizedLabel = (displayMode == CRDDisplayUnified) 
				? NSLocalizedString(@"Windowed", @"Display Mode toolbar item -> Windowed label")
				: NSLocalizedString(@"Unified", @"Display Mode toolbar item -> Unified label");
				
		[toolbarItem setImage:[NSImage imageNamed:[label stringByAppendingString:@".png"]]];
		[toolbarItem setValue:localizedLabel forKey:@"label"];	
	}
	else if ([itemId isEqualToString:TOOLBAR_DISCONNECT])
	{
		NSString *label = ([inst status] == CRDConnectionConnecting) ? @"Stop" : @"Disconnect";
		NSString *localizedLabel = ([inst status] == CRDConnectionConnecting)
				? NSLocalizedString(@"Stop", @"Disconnect toolbar item -> Stop label")
				: NSLocalizedString(@"Disconnect", @"Disconnect toolbar item -> Disconnect label");
				
		[toolbarItem setImage:[NSImage imageNamed:[label stringByAppendingString:@".png"]]];
		[toolbarItem setValue:localizedLabel forKey:@"label"];
		return ([inst status] == CRDConnectionConnecting) || 
				( (viewedInst != nil) && (displayMode == CRDDisplayUnified) );
	}
	else if ([itemId isEqualToString:TOOLBAR_QUICKCONNECTCONSOLE])
	{
		NSString *label = @"Console";
		NSString *localizedLabel = NSLocalizedString(@"Console", @"Quick Connect Console toolbar item -> label");
		[toolbarItem setValue:localizedLabel forKey:@"label"];
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
		CRDSession *inst = [[CRDSession alloc] initWithPath:file];
		
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
	_appIsTerminating = YES;
	
	[self tableViewSelectionDidChange:nil];
	
	// Save current state to user defaults
	[userDefaults setInteger:[gui_serversDrawer edge] forKey:CRDDefaultsUnifiedDrawerSide];
	[userDefaults setBool:CRDDrawerIsVisible(gui_serversDrawer) forKey:CRDDefaultsUnifiedDrawerShown];
	[userDefaults setFloat:[gui_serversDrawer contentSize].width forKey:CRDDefaultsUnifiedDrawerWidth];
	
	NSDisableScreenUpdates();
	
	// Clean up the fullscreen window
	if (displayMode == CRDDisplayFullscreen)
	{
		[gui_tabView setAnimatesWhenSwitchingItems:NO];
		[gui_fullScreenWindow orderOut:nil];
		displayMode = displayModeBeforeFullscreen;
	}
	[userDefaults setInteger:displayMode forKey:CRDDefaultsDisplayMode];
	
	// Disconnect all connected servers
	NSEnumerator *enumerator;
	CRDSession *inst;
	enumerator = [connectedServers objectEnumerator];
	
	while ( (inst = [enumerator nextObject]) )
		[self disconnectInstance:inst];
	
	[gui_unifiedWindow orderOut:nil];
	
	NSEnableScreenUpdates();
	
	
	// Flush each saved server to file (so that the perferred row will be saved)
	[self storeSavedServerPositions];
	enumerator = [savedServers objectEnumerator];
	
	while ( (inst = [enumerator nextObject]) )
		[inst flushChangesToFile];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{	
	// Make sure the drawer is in the user-saved position. Do it here (not awakeFromNib) so that it displays nicely
	[gui_serversDrawer setPreferredEdge:[userDefaults integerForKey:CRDDefaultsUnifiedDrawerSide]];

	float width = [userDefaults floatForKey:CRDDefaultsUnifiedDrawerWidth];
	float height = [gui_serversDrawer contentSize].height;
	if (width > 0)
		[gui_serversDrawer setContentSize:NSMakeSize(width, height)];
		
	if ([userDefaults boolForKey:CRDDefaultsUnifiedDrawerShown])
		[gui_serversDrawer openOnEdge:[userDefaults integerForKey:CRDDefaultsUnifiedDrawerSide]];
	
	[self validateControls];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)hasVisibleWindows
{
	if (!hasVisibleWindows)
		[gui_unifiedWindow makeKeyAndOrderFront:nil];
	
	return YES;
}

- (NSResponder *)application:(NSApplication *)application shouldForwardEvent:(NSEvent *)ev
{
	CRDSessionView *viewedSessionView = [[self viewedServer] view];
	NSWindow *viewedSessionWindow = [viewedSessionView window];
	
	BOOL shouldForward = YES;
	
	shouldForward &= ([ev type] == NSKeyDown) || ([ev type] == NSKeyUp) || ([ev type] == NSFlagsChanged);
			
	shouldForward &= ([viewedSessionWindow firstResponder] == viewedSessionView) && [viewedSessionWindow isKeyWindow] && ([viewedSessionWindow isMainWindow] || ([self displayMode] == CRDDisplayFullscreen));
	
	return shouldForward ? viewedSessionView : nil;

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
	NSPasteboard *pb = [info draggingPasteboard];
	NSString *pbDataType = [gui_serverList pasteboardDataType:pb];
	
	if ([pbDataType isEqualToString:CRDRowIndexPboardType])
	{
		return NSDragOperationMove;
	}
	else if ([pbDataType isEqualToString:NSFilenamesPboardType])
	{
		NSArray *files = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
		NSArray *rdpFiles = CRDFilterFilesByType(files, [NSArray arrayWithObject:@"rdp"]);
		return ([rdpFiles count] > 0) ? NSDragOperationCopy : NSDragOperationNone;
	}
	
	return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
		row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	NSPasteboard *pb = [info draggingPasteboard];
	NSString *pbDataType = [gui_serverList pasteboardDataType:pb];
	int newRow = -1;
	
	if ([pbDataType isEqualToString:CRDRowIndexPboardType])
	{
		newRow = row;
	}
	else if ([pbDataType isEqualToString:NSFilenamesPboardType])
	{
		// External drag, load all rdp files passed
		NSArray *files = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
		NSArray *rdpFiles = CRDFilterFilesByType(files, [NSArray arrayWithObject:@"rdp"]);
		
		CRDSession *inst;
		int insertIndex = [savedServers indexOfObject:[self serverInstanceForRow:row]];
		
		if (insertIndex == NSNotFound)
			insertIndex = [savedServers count];
		
		NSEnumerator *enumerator = [rdpFiles objectEnumerator];
		id file;
		
		while ( (file = [enumerator nextObject]) )
		{
			inst = [[CRDSession alloc] initWithPath:file];
			
			if (inst != nil)
			{
				[inst setFilename:CRDFindAvailableFileName([AppController savedServersPath], [inst label], @".rdp")];
				[self addSavedServer:inst atIndex:insertIndex];
			}
			
			[inst release];
		}
		
		return YES;
	}
	
	if ([info draggingSource] == gui_serverList)
	{
		[self reinsertHeldSavedServer:newRow];
		return YES;
	}

	return NO;
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes
		toPasteboard:(NSPasteboard*)pboard
{
	CRDSession *inst = [self serverInstanceForRow:[rowIndexes firstIndex]];
	
	if (inst == nil)
		return NO;
	
	int row = [rowIndexes firstIndex];
	
	[pboard declareTypes:[NSArray arrayWithObjects:CRDRowIndexPboardType, NSFilenamesPboardType, nil] owner:nil];
	[pboard setPropertyList:[NSArray arrayWithObject:[inst filename]] forType:NSFilenamesPboardType];
	[pboard setString:[NSString stringWithFormat:@"%d", row] forType:CRDRowIndexPboardType];

	return YES;
}

- (BOOL)tableView:(NSTableView *)aTableView canDragRow:(unsigned)rowIndex
{	
	return [savedServers indexOfObject:[self serverInstanceForRow:rowIndex]] != NSNotFound;
}

- (BOOL)tableView:(NSTableView *)aTableView canDropAboveRow:(unsigned)rowIndex
{
	return rowIndex >= 2 + [connectedServers count];
}


#pragma mark NSTableView delegate

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	int selectedRow = [gui_serverList selectedRow];
	CRDSession *inst = [self serverInstanceForRow:[gui_serverList selectedRow]];
	
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
		if ([inspectedServer modified] && ![inspectedServer temporary] )
			[inspectedServer flushChangesToFile];	
	}

	[self setInspectorEnabled:YES];

	inspectedServer = inst;
	[self setInspectorSettings:inst];
	
	// If the new selection is an active session and this wasn't called from self, change the selected view
	if (inst != nil && aNotification != nil && [inst status] == CRDConnectionConnected)
	{
		if ( ([gui_tabView indexOfItem:inst] != NSNotFound) && ([self viewedServer] != inspectedServer) )
		{
			[gui_tabView selectItem:inspectedServer];
			[gui_unifiedWindow makeFirstResponder:[[self viewedServer] view]];
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
	if (!row || row == [connectedServers count] + 1)
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
#pragma mark NSWindow delegate

- (void)windowWillClose:(NSNotification *)sender
{
	if ([sender object] == gui_inspector)
	{
		[self fieldEdited:nil];
		[self saveInspectedServer];

		[self validateControls];
		
		if ( ([self viewedServer] == nil) && CRDDrawerIsVisible(gui_serversDrawer))
			[gui_unifiedWindow makeFirstResponder:gui_serverList];
	}
}


- (void)windowDidBecomeKey:(NSNotification *)sender
{
	if ( (([sender object] == gui_unifiedWindow) && (displayMode == CRDDisplayUnified)) || ( ([sender object] == gui_fullScreenWindow) && (displayMode == CRDDisplayFullscreen)) )
	{
		[[self viewedServer] announceNewClipboardData];
	}
}

- (void)windowDidResignKey:(NSNotification *)sender
{
	if ( (([sender object] == gui_unifiedWindow) && (displayMode == CRDDisplayUnified)) || ( ([sender object] == gui_fullScreenWindow) && (displayMode == CRDDisplayFullscreen)) )
	{
		[[self viewedServer] requestRemoteClipboardData];
	}
}

// Implement unified window 'snap' to real size
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
	if ( (sender == gui_unifiedWindow) && (displayMode == CRDDisplayUnified) && ([self viewedServer] != nil) )
	{
		NSSize realSize = [[[self viewedServer] view] bounds].size;
		realSize.height += [gui_unifiedWindow frame].size.height - [[gui_unifiedWindow contentView] frame].size.height;
		if ( (realSize.width-proposedFrameSize.width <= CRDWindowSnapSize) && (realSize.height-proposedFrameSize.height <= CRDWindowSnapSize) )
		{
			return realSize;	
		}
	}
	
	return proposedFrameSize;
}


#pragma mark -
#pragma mark Managing connected servers

// Starting point to connect to a instance
- (void)connectInstance:(CRDSession *)inst
{
	if (!inst)
		return;
	
	if ([inst status] == CRDConnectionConnected)
		[self disconnectInstance:inst];
		
	[NSThread detachNewThreadSelector:@selector(connectAsync:) toTarget:self withObject:inst];
}

// Assures that the passed instance is disconnected and removed from view.
- (void)disconnectInstance:(CRDSession *)inst
{
	if (!inst || [connectedServers indexOfObjectIdenticalTo:inst] == NSNotFound)
		return;
		
	if (displayMode != CRDDisplayWindowed)
		[gui_tabView removeItem:inst];
	
	if ([inst status] == CRDConnectionConnected)
		[inst disconnect];
		
	if ([[inst valueForKey:@"temporarilyFullscreen"] boolValue])
	{
		[inst setValue:[NSNumber numberWithBool:NO] forKey:@"fullscreen"];
		[inst setValue:[NSNumber numberWithBool:NO] forKey:@"temporarilyFullscreen"];
	}
	

	[[inst retain] autorelease];
	[connectedServers removeObject:inst];
	
	if ([inst temporary])
	{
		// If temporary and in the CoRD servers directory, delete it
		if ([[[inst filename] stringByDeletingLastPathComponent] isEqualToString:[AppController savedServersPath]])
		{
			[inst clearKeychainData];
			[[NSFileManager defaultManager] removeFileAtPath:[inst filename] handler:nil];
		}
		
		[gui_serverList deselectAll:self];
	}
	else
	{
		// Move to saved servers if not already there
		if (![inst filename])
		{
			NSString *path = CRDFindAvailableFileName([AppController savedServersPath], [inst label], @".rdp");

			[inst writeToFile:path atomically:YES updateFilenames:YES];
		}
		
		// Re-insert into saved server list
		int preferredRow = MIN([savedServers count], [[inst valueForKey:@"preferredRowIndex"] intValue]);
		[self addSavedServer:inst atIndex:preferredRow select:YES];
	}

	[self listUpdated];
		
	if ((displayMode == CRDDisplayFullscreen) && ![gui_tabView numberOfItems])
	{
		[self autosizeUnifiedWindowWithAnimation:NO];
		[self endFullscreen:self];
	}
	else if (displayMode == CRDDisplayUnified)
	{
		[self autosizeUnifiedWindowWithAnimation:!_appIsTerminating];
		
		if (![self viewedServer] && CRDDrawerIsVisible(gui_serversDrawer))
			[gui_unifiedWindow makeFirstResponder:gui_serverList];
	}
	else if (displayMode == CRDDisplayWindowed)
	{
		if (![connectedServers count] && ![gui_unifiedWindow isVisible])
			[gui_unifiedWindow makeKeyAndOrderFront:nil];
	}
}

- (void)cancelConnectingInstance:(CRDSession *)inst
{
	if ([inst status] != CRDConnectionConnecting)
		return;
	
	[inst cancelConnection];
	
	[gui_serverList deselectAll:nil];
	[connectedServers removeObject:inst];
	inspectedServer = nil;
	[self listUpdated];
}

#pragma mark -
#pragma mark Support for dragging of saved servers

- (void)holdSavedServer:(int)row
{
	CRDSession *inst = [self serverInstanceForRow:row];
	int index = [savedServers indexOfObjectIdenticalTo:inst];
	
	if ( (inst == nil) || (index == NSNotFound) )
		return;
	
	dumpedInstanceWasSelected = [self selectedServer] == inst;
	dumpedInstance = [inst retain];
	[inst setValue:[NSNumber numberWithInt:index] forKey:@"preferredRowIndex"];
	
	[savedServers removeObject:inst];
}

- (void)reinsertHeldSavedServer:(int)intoRow
{
	int index = (intoRow == -1) ? [[dumpedInstance valueForKey:@"preferredRowIndex"] intValue] : (intoRow - 2 - [connectedServers count]);
	[self addSavedServer:dumpedInstance atIndex:index select:dumpedInstanceWasSelected];
	[dumpedInstance setValue:[NSNumber numberWithInt:index] forKey:@"preferredRowIndex"];
}


#pragma mark -
#pragma mark Other

- (BOOL)mainWindowIsFocused
{
	return [gui_unifiedWindow isMainWindow] && [gui_unifiedWindow isKeyWindow];
}

- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
	CRDSession *inst = contextInfo;
	
	if ( (inst == nil) || (returnCode != NSOKButton) || ([[sheet filename] length] == 0) )
		return;
	
	[inst writeToFile:[sheet filename] atomically:YES updateFilenames:NO];
}

// xxx probably should be private
- (CRDSession *)serverInstanceForRow:(int)row
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

- (void)openUrl:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	NSMutableString *url = [[[[event paramDescriptorForKeyword:keyDirectObject] stringValue] mutableCopy] autorelease];	
	[url deleteCharactersInRange:[url rangeOfString:@"rdp://"]];
	
	NSString *cleanURL = [url stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
	NSLog(@"Parsing URL '%@'", cleanURL);
	
	NSString *username = @"", *password = @"", *host;
	int port;
	

	unsigned int ampersandLocation = [url rangeOfString:@"@"].location;
	if (ampersandLocation != NSNotFound)
	{
		NSScanner *scanner = [NSScanner scannerWithString:[cleanURL substringToIndex:ampersandLocation]];
		
		NSCharacterSet *windowsUsernameCharacters = [NSCharacterSet characterSetWithCharactersInString:@"\\/\"[]:|<>+=;,?*@\n\r"], *emptySet = [NSCharacterSet characterSetWithCharactersInString:@""];
		
		[scanner setCharactersToBeSkipped:windowsUsernameCharacters];
		[scanner scanUpToCharactersFromSet:windowsUsernameCharacters intoString:&username];
		
		if (![scanner isAtEnd])
		{	
			[scanner setScanLocation:([scanner scanLocation] + 1)];
			[scanner setCharactersToBeSkipped:emptySet];
			[scanner scanUpToCharactersFromSet:emptySet intoString:&password];
		}
		
		ampersandLocation++;
	}
	else
	{
		ampersandLocation = 0;
	}
	
	CRDSplitHostNameAndPort([cleanURL substringFromIndex:ampersandLocation], &host, &port);
	
	
	CRDSession *session = [[[CRDSession alloc] init] autorelease];

	[session setValue:host forKey:@"label"];
	[session setValue:host forKey:@"hostName"];
	[session setValue:username forKey:@"username"];
	[session setValue:password forKey:@"password"];
	[session setValue:[NSNumber numberWithInt:port] forKey:@"port"];
	[session setTemporary:YES];
	
	[connectedServers addObject:session];
	[gui_serverList deselectAll:self];
	[self listUpdated];
	[self connectInstance:session];
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

// Returns the connected server that the tab view is displaying
- (CRDSession *)viewedServer
{
	if (displayMode == CRDDisplayUnified || displayMode == CRDDisplayFullscreen)
	{
		id selectedItem = [gui_tabView selectedItem];

		if (selectedItem == nil)
			return nil;
			
		NSEnumerator *enumerator = [connectedServers objectEnumerator];
		id item;
		
		while ( (item = [enumerator nextObject]) )
		{
			if (item == selectedItem)
				return item;
		}
	}
	else // windowed mode
	{
		NSEnumerator *enumerator = [connectedServers objectEnumerator];
		CRDSession *inst;
		
		while ( (inst = [enumerator nextObject]) )
		{
			if ([[inst window] isMainWindow])
				return inst;
		}
	}
	
	return nil;
}

- (CRDSession *)selectedServer
{
	if (!CRDDrawerIsVisible(gui_serversDrawer))
		return nil;
	else
		return [self serverInstanceForRow:[gui_serverList selectedRow]];
}

#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"label"])
	{
		NSString *newLabel = [change objectForKey:NSKeyValueChangeNewKey];
		if ( ([newLabel length] > 0) && ![newLabel isEqual:[change objectForKey:NSKeyValueChangeOldKey]] && ![object temporary])
		{
			NSString *newPath = CRDFindAvailableFileName([AppController savedServersPath], newLabel, @".rdp");
			
			[[NSFileManager defaultManager] movePath:[object filename] toPath:newPath handler:nil];
			
			[object setFilename:newPath];
		}
	}
	else if ([keyPath isEqualToString:CRDPrefsScaleSessions])
	{
	
	
	}
	else if ([keyPath isEqualToString:CRDPrefsMinimalisticServerList])
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:CRDMinimalViewDidChangeNotification object:nil];
	
		[gui_serverList noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [gui_serverList numberOfRows])]];
	}
}

@end


#pragma mark -

@implementation AppController (Private)


#pragma mark -
#pragma mark General

- (void) listUpdated
{	
	[gui_serverList noteNumberOfRowsChanged];
	
	if ([self serverInstanceForRow:[gui_serverList selectedRow]] == nil)
		[gui_serverList selectRow:-1];
	
	
	
	// Update servers menu
	int separatorIndex = [gui_serversMenu indexOfItemWithTag:SERVERS_SEPARATOR_TAG], i; 
	
	while ( (i = [gui_serversMenu numberOfItems]-1) > separatorIndex)
		[gui_serversMenu removeItemAtIndex:i];
	
	NSMenuItem *menuItem;
	NSEnumerator *enumerator;
	CRDSession *inst;
	
	enumerator = [connectedServers objectEnumerator];
	while ( (inst = [enumerator nextObject]) )
	{
		menuItem = [[NSMenuItem alloc] initWithTitle:[inst label]
					action:@selector(performServerMenuItem:) keyEquivalent:@""];
		[menuItem setRepresentedObject:inst];
		[gui_serversMenu addItem:menuItem];
		[menuItem autorelease];
	}
	
	enumerator = [savedServers objectEnumerator];
	while ( (inst = [enumerator nextObject]) )
	{
		menuItem = [[NSMenuItem alloc] initWithTitle:[inst label]
					action:@selector(performServerMenuItem:) keyEquivalent:@""];
		[menuItem setRepresentedObject:inst];
		[gui_serversMenu addItem:menuItem];
		[menuItem autorelease];
	}
}

// Validates non-menu and toolbar interface items
- (void)validateControls
{
	CRDSession *inst = [self serverInstanceForRow:[gui_serverList selectedRow]];
	
	[gui_connectButton setEnabled:(inst != nil && [inst status] == CRDConnectionClosed)];
	[gui_inspectorButton setEnabled:(inst != nil)];
}

- (void)setInspectorEnabled:(BOOL)enabled
{
	[self toggleControlsEnabledInView:[gui_inspector contentView] enabled:enabled];
	[gui_inspector display];
}

- (void)createWindowForInstance:(CRDSession *)inst
{
	[inst createWindow:!CRDPreferenceIsEnabled(CRDPrefsScaleSessions)];
	
	NSWindow *window = [inst window];
	[window cascadeTopLeftFromPoint:windowCascadePoint];
	[window makeFirstResponder:[inst view]];
	[window makeKeyAndOrderFront:self];
}

- (void)saveInspectedServer
{
	if ([inspectedServer modified] && ![inspectedServer temporary])
		[inspectedServer flushChangesToFile];
}

// Enables/disables non-inspector gui controls as needed
- (void)toggleControlsEnabledInView:(NSView *)view enabled:(BOOL)enabled
{
	if ([view isKindOfClass:[NSControl class]])
	{
		if ([view isKindOfClass:[NSTextField class]] && ![(NSTextField *)view drawsBackground])
		{
			// setTextColor is buggy in 10.4, thus use white to get the greyed color while disabled.  don't know what 10.5 does.
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

#pragma mark -
#pragma mark Managing inspector settings

// Sets all of the values in the passed CRDSession to match the inspector
- (void)updateInstToMatchInspector:(CRDSession *)inst
{
	if (!inst)
		return;
		
	// Checkboxes
	[inst setValue:BUTTON_STATE_AS_NUMBER(gui_displayDragging)	forKey:@"windowDrags"];
	[inst setValue:BUTTON_STATE_AS_NUMBER(gui_drawDesktop)		forKey:@"drawDesktop"];
	[inst setValue:BUTTON_STATE_AS_NUMBER(gui_enableAnimations)	forKey:@"windowAnimation"];
	[inst setValue:BUTTON_STATE_AS_NUMBER(gui_enableThemes)		forKey:@"themes"];
	[inst setValue:BUTTON_STATE_AS_NUMBER(gui_savePassword)		forKey:@"savePassword"];
	[inst setValue:BUTTON_STATE_AS_NUMBER(gui_forwardDisks)		forKey:@"forwardDisks"];
	[inst setValue:BUTTON_STATE_AS_NUMBER(gui_forwardPrinters)	forKey:@"forwardPrinters"];
	[inst setValue:BUTTON_STATE_AS_NUMBER(gui_consoleSession)	forKey:@"consoleSession"];
	
	// Text fields
	[inst setValue:[gui_label stringValue]		forKey:@"label"];
	[inst setValue:[gui_username stringValue]	forKey:@"username"];
	[inst setValue:[gui_domain stringValue]		forKey:@"domain"];	
	[inst setValue:[gui_password stringValue]	forKey:@"password"];
	
	// Host
	int port;
	NSString *s;
	CRDSplitHostNameAndPort([gui_host stringValue], &s, &port);
	[inst setValue:[NSNumber numberWithInt:port] forKey:@"port"];
	[inst setValue:s forKey:@"hostName"];
	
	// Screen depth
	[inst setValue:[NSNumber numberWithInt:([gui_colorCount indexOfSelectedItem]+1)*8] forKey:@"screenDepth"];
			
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

// Sets the inspector options to match an CRDSession
- (void)setInspectorSettings:(CRDSession *)newSettings
{
	#define BUTTON_STATE_FOR_KEY(k) CRDButtonState([[newSettings valueForKey:(k)] boolValue])
	
	if (newSettings == nil)
	{
		[gui_inspector setTitle:NSLocalizedString(@"Inspector: No Server Selected", @"Inspector -> Disabled title")];
		newSettings = [[[CRDSession alloc] init] autorelease];
	}
	else
	{
		[gui_inspector setTitle:[NSLocalizedString(@"Inspector: ", @"Inspector -> Enabled title") stringByAppendingString:[newSettings label]]];
	}
		
	// All checkboxes 
	[gui_displayDragging    setState:BUTTON_STATE_FOR_KEY(@"windowDrags")];
	[gui_drawDesktop        setState:BUTTON_STATE_FOR_KEY(@"drawDesktop")];
	[gui_enableAnimations   setState:BUTTON_STATE_FOR_KEY(@"windowAnimation")];
	[gui_enableThemes       setState:BUTTON_STATE_FOR_KEY(@"themes")];
	[gui_savePassword       setState:BUTTON_STATE_FOR_KEY(@"savePassword")];
	[gui_forwardDisks       setState:BUTTON_STATE_FOR_KEY(@"forwardDisks")];
	[gui_forwardPrinters    setState:BUTTON_STATE_FOR_KEY(@"forwardPrinters")];
	[gui_consoleSession     setState:BUTTON_STATE_FOR_KEY(@"consoleSession")];
	
	// Most of the text fields
	[gui_label    setStringValue:[newSettings valueForKey:@"label"]];
	[gui_username setStringValue:[newSettings valueForKey:@"username"]];
	[gui_domain   setStringValue:[newSettings valueForKey:@"domain"]];
	[gui_password setStringValue:[newSettings valueForKey:@"password"]];
	
	// Host
	int port = [[newSettings valueForKey:@"port"] intValue];
	NSString *host = [newSettings valueForKey:@"hostName"];
	[gui_host setStringValue:CRDJoinHostNameAndPort(host, port)];
	
	// Color depth
	int colorDepth = [[newSettings valueForKey:@"screenDepth"] intValue];
	[gui_colorCount selectItemAtIndex:(colorDepth/8-1)];
	
	// Screen resolution
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
	
	#undef BUTTON_STATE_FOR_KEY
}

- (void)toggleDrawer:(id)sender visible:(BOOL)visible
{
	if (visible)
		[gui_serversDrawer open];
	else
		[gui_serversDrawer close];
	
	[gui_toolbar validateVisibleItems];
}


#pragma mark -
#pragma mark Connecting to servers asynchronously

// Should only be called by connectInstance
- (void)connectAsync:(CRDSession *)inst
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	if ([[inst valueForKey:@"fullscreen"] boolValue])
	{
		NSSize screenSize = [[gui_unifiedWindow screen] frame].size;
		[inst setValue:[NSNumber numberWithInt:(int)screenSize.width] forKey:@"screenWidth"];
		[inst setValue:[NSNumber numberWithInt:(int)screenSize.height] forKey:@"screenHeight"];
	}
	
	BOOL connected = [inst connect];
	
	[self performSelectorOnMainThread:@selector(completeConnection:) withObject:inst waitUntilDone:NO];
					
	if (connected)	
		[inst runConnectionRunLoop]; // this will block until the connection is finished
		
	if ([inst status] == CRDConnectionConnected)
		[self disconnectInstance:inst];
	
	[pool release];
}

// Called in main thread by connectAsync
- (void)completeConnection:(CRDSession *)inst
{
	if ([inst status] == CRDConnectionConnected)
	{
		// Move it into the proper list
		if (![inst temporary])
		{
			[[inst retain] autorelease];
			[savedServers removeObject:inst];
			[connectedServers addObject:inst];
		}
		
		[gui_serverList selectRow:(1 + [connectedServers indexOfObject:inst])];
		[self listUpdated];
		
		// Create gui
		if ( (displayMode == CRDDisplayUnified) || (displayMode == CRDDisplayFullscreen) )
		{
			[inst createUnified:!CRDPreferenceIsEnabled(CRDPrefsScaleSessions) enclosure:[gui_tabView frame]];
			[gui_tabView addItem:inst];
			[gui_tabView selectLastItem:self];
			[gui_unifiedWindow makeFirstResponder:[inst view]];
		}
		else
		{
			[self createWindowForInstance:inst];
		}
		
		
		if ([[inst valueForKey:@"fullscreen"] boolValue] || [[inst valueForKey:@"temporarilyFullscreen"] boolValue])
		{
			// defer the switch to fullscreen so that the server has a chance to set the background color of the screen so that the animation into fullscreen isn't abrupt. Very short time so as not to make interface laggy, but just long enough for the draw command to come in on LAN servers
			NSDisableScreenUpdates();
			[NSTimer scheduledTimerWithTimeInterval:0.15 target:self selector:@selector(startFullscreen:) userInfo:nil repeats:NO];
			
			return;
		}
		
		if (displayMode == CRDDisplayUnified)
			[self autosizeUnifiedWindow];
	}
	else
	{

		[self cellNeedsDisplay:(NSCell *)[inst cellRepresentation]];
		RDConnectionError errorCode = [inst conn]->errorCode;
		
		if (errorCode != ConnectionErrorNone && errorCode != ConnectionErrorCanceled)
		{			
			NSString *localizedErrorDescriptions[] = {
					@"No error", /* shouldn't ever occur */
					NSLocalizedString(@"The connection timed out.", @"Connection errors -> Timeout"),
					NSLocalizedString(@"The host name could not be resolved.", @"Connection errors -> Host not found"), 
					NSLocalizedString(@"There was an error connecting.", @"Connection errors -> Couldn't connect"),
					NSLocalizedString(@"You canceled the connection.", @"Connection errors -> User canceled")
					};
			NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Couldn't connect to %@",
					@"Connection error alert -> Title"), [inst label]];
			
			NSAlert *alert = [NSAlert alertWithMessageText:title defaultButton:nil
						alternateButton:NSLocalizedString(@"Retry", @"Connection errors -> Retry button")
						otherButton:nil
						informativeTextWithFormat:localizedErrorDescriptions[errorCode]];
			[alert setAlertStyle:NSCriticalAlertStyle];
			
			// Retry if requested
			if ([alert runModal] == NSAlertAlternateReturn)
			{
				[self connectInstance:inst];
			}
			else if ([inst temporary]) // Temporary items may be in connectedServers even though connection failed
			{
				[connectedServers removeObject:inst];
				[self listUpdated];
			}
		}
	}	
}


#pragma mark -
#pragma mark Autmatic window sizing

- (void)autosizeUnifiedWindow
{
	[self autosizeUnifiedWindowWithAnimation:YES];
}

- (void)autosizeUnifiedWindowWithAnimation:(BOOL)animate
{
	CRDSession *inst = [self viewedServer];
	NSSize newContentSize;
	if ([self displayMode] == CRDDisplayUnified && inst)
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
	
	if (CRDPreferenceIsEnabled(CRDPrefsScaleSessions) && inst)
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
	if (!CRDPreferenceIsEnabled(CRDPrefsScaleSessions))
	{
		
		if (newWindowFrame.size.height > screenRect.size.height && newWindowFrame.size.width + scrollerWidth <= screenRect.size.width)
		{
			newWindowFrame.origin.y = screenRect.origin.y;
			newWindowFrame.size.height = screenRect.size.height;
			newWindowFrame.size.width += scrollerWidth;

		}
		if (newWindowFrame.size.width > screenRect.size.width && newWindowFrame.size.height+scrollerWidth <= screenRect.size.height)
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
	if (CRDPreferenceIsEnabled(CRDPrefsScaleSessions))
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
			{
				newWindowFrame.size.width = bareWindowHeight * realAspect;
			}
		}
	}
	
	if ( ([self displayMode] != CRDDisplayUnified) || ([self viewedServer] == nil))
		[gui_unifiedWindow setTitle:@"CoRD"];
	else
		[gui_unifiedWindow setTitle:[[self viewedServer] label]];
	
	[gui_unifiedWindow setFrame:newWindowFrame display:YES animate:animate];
}


#pragma mark -
#pragma mark Managing saved servers

- (void)addSavedServer:(CRDSession *)inst
{
	[self addSavedServer:inst atIndex:[savedServers count] select:YES];
}

- (void)addSavedServer:(CRDSession *)inst atIndex:(int)index
{
	[self addSavedServer:inst atIndex:index select:NO];
}

- (void)addSavedServer:(CRDSession *)inst atIndex:(int)index select:(BOOL)select
{
	if ( !inst || (index < 0) || (index > [savedServers count]) )
		return;
	
	[inst setTemporary:NO];
	
	index = MIN(MAX(index, 0), [savedServers count]);
		
	[savedServers insertObject:inst atIndex:index];
	[gui_serverList noteNumberOfRowsChanged];
	
	if (select)
		[gui_serverList selectRow:(2 + [connectedServers count] + [savedServers indexOfObjectIdenticalTo:inst])];
		
	[inst addObserver:self forKeyPath:@"label" options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld) context:NULL];
}

- (void)removeSavedServer:(CRDSession *)inst deleteFile:(BOOL)deleteFile
{
	if (deleteFile)
	{
		[inst clearKeychainData];
		[[NSFileManager defaultManager] removeFileAtPath:[inst filename] handler:nil];
	}
	
	[inst removeObserver:self forKeyPath:@"label"];
	
	[savedServers removeObject:inst];
	
	if (inspectedServer == inst)
		inspectedServer = nil;
	
	[self listUpdated];
}

- (void)sortSavedServersByStoredListPosition
{
	[savedServers sortUsingSelector:@selector(compareUsingPreferredOrder:)];
}

- (void)sortSavedServersAlphabetically
{
	NSArray *sortDescriptors = [NSArray arrayWithObjects:
			[[[NSSortDescriptor alloc] initWithKey:@"label" ascending:YES] autorelease],
			[[[NSSortDescriptor alloc] initWithKey:@"hostName" ascending:YES] autorelease],
			[[[NSSortDescriptor alloc] initWithKey:@"username" ascending:YES] autorelease],
			nil];
	[savedServers sortUsingDescriptors:sortDescriptors];
}

- (void)storeSavedServerPositions
{
	NSEnumerator *enumerator = [savedServers objectEnumerator];
	CRDSession *inst;
	
	while ( (inst = [enumerator nextObject]) )
		[inst setValue:[NSNumber numberWithInt:[savedServers indexOfObject:inst]] forKey:@"preferredRowIndex"];	
}

@end

#pragma mark -

@implementation AppController (SharedResources)

+ (NSImage *)sharedDocumentIcon
{
	static NSImage *s_documentIcon = nil;
	
	if (s_documentIcon == nil)
	{
		// The stored icon is loaded flipped for whatever reason, so flip it back
		NSImage *icon = [NSImage imageNamed:@"rdp document.icns"];
		s_documentIcon = [[NSImage alloc] initWithSize:[icon size]];
		[icon setFlipped:YES];
		[s_documentIcon lockFocus];
		{
			[icon drawInRect:CRDRectFromSize([icon size]) fromRect:CRDRectFromSize([icon size]) operation:NSCompositeSourceOver fraction:1.0];
		} [s_documentIcon unlockFocus];
	}
	
	return s_documentIcon;
}

+ (NSString *)savedServersPath
{
	static NSString *s_savedServersPath = nil;
	
	if (s_savedServersPath == nil)
	{
		s_savedServersPath = [[[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"CoRD/Servers"] retain];
	}

	return s_savedServersPath;
}

@end
