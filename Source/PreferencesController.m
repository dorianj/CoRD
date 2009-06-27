/*	Copyright (c) 2009 Nick Peelman <nick@peelman.us>
	
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

#import "PreferencesController.h"

#pragma mark -

@implementation PreferencesController

- (id) init
{
	if (![super init])
		return nil;
		
	toolbarItems = [[NSMutableDictionary alloc] init];
	
	return self;
}


-(void)	dealloc
{
	[prefsToolbar release];
	[toolbarItems release];
	[super dealloc];
}

- (void)awakeFromNib
{
	//Turn Core Animation On For All Views
	[[preferencesWindow contentView] setWantsLayer:YES];
	[generalView setWantsLayer:YES];
	[connectionView setWantsLayer:YES];	
	[advancedView setWantsLayer:YES];

	// Init Toolbar & Set Initial Pane
	[self buildToolbar];
	[self changePanes:nil];
}

-(void) buildToolbar
{
	[toolbarItems removeAllObjects];
	[toolbarItems setObject:@"General" forKey:@"General"];
	[toolbarItems setObject:@"Connections" forKey:@"Connections"];
	[toolbarItems setObject:@"Advanced" forKey:@"Advanced"];
	
	prefsToolbar = [preferencesWindow toolbar];
	
	if (prefsToolbar == nil)
		prefsToolbar = [[NSToolbar alloc] initWithIdentifier: @"CoRDPrefsToolbar"];

    [prefsToolbar setAllowsUserCustomization: NO];
    [prefsToolbar setAutosavesConfiguration: NO];
    [prefsToolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
    [prefsToolbar setDelegate: self];

    [preferencesWindow setToolbar: prefsToolbar];
	[preferencesWindow setShowsToolbarButton:NO];
}

-(IBAction)changePanes:(id)sender
{
	NSView *currentPane = [preferencesWindow contentView];
	NSView* newPane = nil;
	
	NSString *paneLabel = [sender label];
	
	if ([paneLabel isEqualToString:@"General"])
		newPane = generalView;
	else if ([paneLabel isEqualToString:@"Connections"])
		newPane = connectionView;
	else if ([paneLabel isEqualToString:@"Advanced"])
		newPane = advancedView;
	else
		newPane = generalView;
	
	if ( (newPane == nil) || (currentPane == newPane) )
		return;
	
	
	NSView *tempView = [[NSView alloc] initWithFrame:[[preferencesWindow contentView] frame]];
	[preferencesWindow setContentView:tempView];
	[tempView release]; 
	
	[preferencesWindow makeFirstResponder:nil];
	[prefsToolbar setSelectedItemIdentifier:(paneLabel) ? paneLabel : @"General"];

	
	//ZNLog(@"newPane: %@", newPane);
	NSRect newFrame = [preferencesWindow frame];
	//ZNLog(@"Original preferences window frame: %@", NSStringFromRect(newFrame));
	newFrame.size.height = [newPane frame].size.height + ([preferencesWindow frame].size.height - [[preferencesWindow contentView] frame].size.height);
	newFrame.size.width = [newPane frame].size.width; 
	newFrame.origin.y += ([[preferencesWindow contentView] frame].size.height - [newPane frame].size.height);
	
	//ZNLog(@"Using preferences window frame: %@", NSStringFromRect(newFrame));
	[NSAnimationContext beginGrouping];
	[[preferencesWindow animator] setFrame:newFrame display:YES];
	[[preferencesWindow animator] setContentView:newPane];
	[NSAnimationContext endGrouping];
	
	NSSize theSize = [preferencesWindow frame].size;
	//ZNLog(@"Original preferences window size: %@", NSStringFromSize(theSize));
	theSize.height -= 100;
	//ZNLog(@"Using preferences window size: %@", NSStringFromSize(theSize));
	
	[preferencesWindow setMinSize:theSize];
}

-(IBAction) toggleAdvanced: (id)sender
{
}

#pragma mark -
#pragma mark Calling For Help

- (IBAction)helpForGeneralPreferences:(id)sender
{
    [[NSHelpManager sharedHelpManager] openHelpAnchor:@"GeneralPreferences" inBook: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleHelpBookName"]];
}

- (IBAction)helpForConnectionPreferences:(id)sender
{
    [[NSHelpManager sharedHelpManager] openHelpAnchor:@"ConnectionPreferences" inBook: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleHelpBookName"]];
}

#pragma mark -
#pragma mark NSToolbar Delegate Methods
-(NSToolbarItem*) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted
{
	NSToolbarItem* toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
    NSString* itemLabel;

    if ( (itemLabel = [toolbarItems objectForKey:itemIdent]) != nil )
	{
		[toolbarItem setLabel: itemLabel];
		[toolbarItem setPaletteLabel: itemLabel];

		// These aren't localized (yet)
		[toolbarItem setToolTip: itemLabel];
		if ([[toolbarItem label] isEqualToString:@"General"])
			[toolbarItem setImage: [NSImage imageNamed:NSImageNamePreferencesGeneral]];
		else if ([[toolbarItem label] isEqualToString:@"Connections"])
			[toolbarItem setImage:[NSImage imageNamed:@"Windowed.png"]];
		else if ([[toolbarItem label] isEqualToString:@"Advanced"])
			[toolbarItem setImage:[NSImage imageNamed:NSImageNameAdvanced]];;
		
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(changePanes:)];
    }
	else
	{
		toolbarItem = nil;
    }
	
    return toolbarItem;
}


-(NSArray*) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
	//NSLog(@"Checking Allowed Idents");
	
    NSMutableArray*	allowedItems = [[[toolbarItems allKeys] mutableCopy] autorelease];

	[allowedItems addObjectsFromArray: [NSArray arrayWithObjects: NSToolbarSeparatorItemIdentifier,
										NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
										NSToolbarCustomizeToolbarItemIdentifier, nil] ];
	return allowedItems;
}

-(NSArray*) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
	//NSLog(@"Checking Default Idents");
	NSMutableArray* defaultItems = [NSMutableArray arrayWithArray:[NSArray arrayWithObjects:@"General",@"Connections",@"Advanced",nil]];
	return defaultItems;
}

-(NSArray*) toolbarSelectableItemIdentifiers: (NSToolbar*)toolbar
{
	//NSLog(@"Checking Selectable Item Idents");
	return [toolbarItems allKeys];
}


#pragma mark -
#pragma mark NSWindow Delegate Methods
- (void)windowDidBecomeKey:(NSNotification *)notification
{
	[closeWindowMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask];
	[closeSessionMenuItem setKeyEquivalentModifierMask:(NSCommandKeyMask|NSAlternateKeyMask)];
}

- (void)windowDidResignKey:(NSNotification *)notification
{
	[closeWindowMenuItem setKeyEquivalentModifierMask:(NSCommandKeyMask|NSAlternateKeyMask)];
	[closeSessionMenuItem setKeyEquivalentModifierMask:NSCommandKeyMask];
}




@end
