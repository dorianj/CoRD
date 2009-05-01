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
	[[preferencesWindow animator] setContentView:generalView];
}

- (void)switchToGeneral
{
	
}

-(void) mapTabsToToolbar
{
    // Create a new toolbar instance, and attach it to our document window 
	prefsToolbar = [[tabView window] toolbar];
	int				itemCount = 0,
	x = 0;
	NSTabViewItem	*currPage = nil;
	
	if( prefsToolbar == nil )   // No toolbar yet? Create one!
		prefsToolbar = [[NSToolbar alloc] initWithIdentifier: @"CoRDPrefsToolbar"];
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults 
    [prefsToolbar setAllowsUserCustomization: NO];
    [prefsToolbar setAutosavesConfiguration: NO];
    [prefsToolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
	
	// Set up item list based on Tab View:
	itemCount = [tabView numberOfTabViewItems];

	[toolbarItems removeAllObjects];	// In case we already had a toolbar.
	
	[toolbarItems setObject:@"General" forKey:@"General"];
	[toolbarItems setObject:@"Connections" forKey:@"Connections"];
    
	NSLog(@"Toolbar Items Count:  %i", [toolbarItems count]);
    // We are the delegate
    [prefsToolbar setDelegate: self];


    // Attach the toolbar to the document window 
    [preferencesWindow setToolbar: prefsToolbar];
	
	// Set up window title:
	currPage = [tabView selectedTabViewItem];
	if( currPage == nil )
		currPage = [tabView tabViewItemAtIndex:0];
	
	if( [prefsToolbar respondsToSelector: @selector(setSelectedItemIdentifier:)] )
		[prefsToolbar setSelectedItemIdentifier: [currPage identifier]];
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
	
	if ( (newPane == nil) || (currentPane == newPane) ) return;
	
	ZNLog(@"newPane: %@", newPane);
	// Preserve upper left point of window during resize.
	NSRect newFrame = [preferencesWindow frame];
	ZNLog(@"Original preferences window frame: %@", NSStringFromRect(newFrame));
	
	newFrame.size.height = [newPane frame].size.height + ([preferencesWindow frame].size.height - [[preferencesWindow contentView] frame].size.height);
	newFrame.size.width = [newPane frame].size.width; 
	newFrame.origin.y += ([[preferencesWindow contentView] frame].size.height - [newPane frame].size.height);
	
	ZNLog(@"Using preferences window frame: %@", NSStringFromRect(newFrame));
	[preferencesWindow setFrame:newFrame display:YES animate:YES];
	[preferencesWindow setContentView:newPane];
	
	// Set appropriate resizing on window.
	NSSize theSize = [preferencesWindow frame].size;
	ZNLog(@"Original preferences window size: %@", NSStringFromSize(theSize));
	theSize.height -= 100;
	ZNLog(@"Using preferences window size: %@", NSStringFromSize(theSize));
	
	[preferencesWindow setMinSize:theSize];
}



/* -----------------------------------------------------------------------------
 toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:
 Create an item with the proper image and name based on our list
 of tabs for the specified identifier.
 -------------------------------------------------------------------------- */

-(NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *)itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted
{
	NSLog(@"Creating Toolbar Item With Ident: %@", itemIdent);
    // Required delegate method:  Given an item identifier, this method returns an item 
    // The toolbar will use this method to obtain toolbar items that can be displayed in the customization sheet, or in the toolbar itself 
    NSToolbarItem   *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
    NSString*		itemLabel;
	NSLog(@"Toolbar Item Created, with Ident:  %@, %@", [toolbarItem itemIdentifier], [toolbarItems objectForKey:itemIdent]);
    if( (itemLabel = [toolbarItems objectForKey:itemIdent]) != nil )
	{
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: itemLabel];
		[toolbarItem setPaletteLabel: itemLabel];
		[toolbarItem setTag:[tabView indexOfTabViewItemWithIdentifier:itemIdent]];
		NSLog(@"Set Item Properties, Label %@, Palette Label %@, and Tag %i",[toolbarItem label],[toolbarItem paletteLabel], [toolbarItem tag]);
		// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip: itemLabel];
		if ([[toolbarItem label] isEqualToString:@"General"])
		{
			[toolbarItem setImage: [NSImage imageNamed:NSImageNamePreferencesGeneral]];
		} else if ([[toolbarItem label] isEqualToString:@"Connections"])
		{
			[toolbarItem setImage:[NSImage imageNamed:@"Windowed.png"]];
		}
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(changePanes:)];
    }
	else
	{
		// itemIdent refered to a toolbar item that is not provide or supported by us or cocoa 
		// Returning nil will inform the toolbar this kind of item is not supported 
		toolbarItem = nil;
    }
	
    return toolbarItem;
}


-(NSArray*) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
	NSLog(@"Checking Allowed Idents");
    NSMutableArray*	allowedItems = [[[toolbarItems allKeys] mutableCopy] autorelease];
	
	[allowedItems addObjectsFromArray: [NSArray arrayWithObjects: NSToolbarSeparatorItemIdentifier,
										NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
										NSToolbarCustomizeToolbarItemIdentifier, nil] ];
	return allowedItems;
}

-(NSArray*) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
	NSLog(@"Checking Default Idents");
//	int					itemCount = [tabView numberOfTabViewItems],
//	x;
//	NSTabViewItem*		theItem = [tabView tabViewItemAtIndex:0];
//	//NSMutableArray*	defaultItems = [NSMutableArray arrayWithObjects: [theItem identifier], NSToolbarSeparatorItemIdentifier, nil];
	NSMutableArray* defaultItems = [NSMutableArray arrayWithArray:[toolbarItems allKeys]];
	//
//	for( x = 0; x < itemCount; x++ )
//	{
//		theItem = [tabView tabViewItemAtIndex:x];
//		
//		[defaultItems addObject: [theItem identifier]];
//		NSLog(@"Adding Default Item: %@", [theItem identifier]); 
//	}
	
	return defaultItems;
}

-(NSArray*) toolbarSelectableItemIdentifiers: (NSToolbar*)toolbar
{
	NSLog(@"Checking Selectable Item Idents");
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
