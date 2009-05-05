#import "PreferencesController.h"

@implementation PreferencesController

-(id) init
{
	if( (self = [super init]) )
	{
		toolbarItems = [[NSMutableDictionary alloc] init];
	}
	
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
	[self mapTabsToToolbar];

	[[preferencesWindow contentView] setWantsLayer:YES];
	[generalView setWantsLayer:YES];
	[connectionView setWantsLayer:YES];	
	[advancedView setWantsLayer:YES];
//	ZNLog(@"Init General View: %@", generalView);
	[self changePanes:nil];
}

-(void) mapTabsToToolbar
{
	//Define Toolbar Items
	[toolbarItems removeAllObjects];
	[toolbarItems setObject:@"General" forKey:@"General"];
	[toolbarItems setObject:@"Connections" forKey:@"Connections"];
//	[toolbarItems setObject:@"Advanced" forKey:@"Advanced"];
	
    // Create a new toolbar instance, and attach it to our document window 
	prefsToolbar = [preferencesWindow toolbar];
	int				itemCount = 0, x = 0;	
	
	if( prefsToolbar == nil )
	{
		prefsToolbar = [[NSToolbar alloc] initWithIdentifier: @"CoRDPrefsToolbar"];
	}

    [prefsToolbar setAllowsUserCustomization: NO];
    [prefsToolbar setAutosavesConfiguration: NO];
    [prefsToolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
    [prefsToolbar setDelegate: self];

    // Attach the toolbar to the document window 
    [preferencesWindow setToolbar: prefsToolbar];
	[preferencesWindow setShowsToolbarButton:NO];

}

-(IBAction)changePanes:(id)sender
{
	NSView *currentPane = [preferencesWindow contentView];
	NSView* newPane = nil;
	
	if ([[sender label] isEqualToString:@"General"])
	{
		newPane = generalView;
	}
	else if ([[sender label] isEqualToString:@"Connections"])
	{
		newPane = connectionView;
	}
	else if ([[sender label] isEqualToString:@"Advanced"])
	{
		newPane = advancedView;
	} else {
		//ZNLog(@"No Sender, Selecting General");
		newPane = generalView;
	}
	
	if ( (newPane == nil) || (currentPane == newPane) ) return;
	
	
	NSView *tempView = [[NSView alloc] initWithFrame:[[preferencesWindow contentView] frame]];
	[preferencesWindow setContentView:tempView];
	[tempView release]; 
	
	[preferencesWindow makeFirstResponder:nil];
	[prefsToolbar setSelectedItemIdentifier:([sender label]) ? [sender label] : @"General"];

	
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


/* -----------------------------------------------------------------------------
 toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:
 Create an item with the proper image and name based on our list
 of tabs for the specified identifier.
 -------------------------------------------------------------------------- */

-(NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted
{
	NSToolbarItem   *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
    NSString*		itemLabel;

    if ( (itemLabel = [toolbarItems objectForKey:itemIdent]) != nil )
	{
		[toolbarItem setLabel: itemLabel];
		[toolbarItem setPaletteLabel: itemLabel];

		// These aren't localized (yet)
		[toolbarItem setToolTip: itemLabel];
		if ([[toolbarItem label] isEqualToString:@"General"])
		{
			[toolbarItem setImage: [NSImage imageNamed:NSImageNamePreferencesGeneral]];
		} 
		else if ([[toolbarItem label] isEqualToString:@"Connections"])
		{
			[toolbarItem setImage:[NSImage imageNamed:@"Windowed.png"]];
		} 
		else if ([[toolbarItem label] isEqualToString:@"Advanced"])
		{
			[toolbarItem setImage:[NSImage imageNamed:NSImageNameAdvanced]];;
		}
		
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
	NSMutableArray* defaultItems = [NSMutableArray arrayWithArray:[toolbarItems allKeys]];
	return defaultItems;
}

-(NSArray*) toolbarSelectableItemIdentifiers: (NSToolbar*)toolbar
{
	//NSLog(@"Checking Selectable Item Idents");
	return [toolbarItems allKeys];
}

- (void)windowWillClose:(NSNotification *)notification
{
	//Set Cmd-W to close the current session and not the current window
}

- (void)windowDidBecomeKey:(NSNotification *)notification
{
	//Set Cmd-W to close the current window and not hte current session
	
	
}



@end
