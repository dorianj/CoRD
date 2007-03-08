//  Copyright (c) 2006 Craig Dooley <xlnxminusx@gmail.com>
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


#import "AppController.h"
#import "RDInstance.h"
#import "RDPFile.h"
#import "ActiveConnection.h"
#import "Definitions.h"

@implementation AppController

#pragma mark NSObject methods
- (id)init {
	self = [super init];
	if (self) {
		userDefaults = [[NSUserDefaults standardUserDefaults] retain];
		currentConnections = [[NSMutableArray alloc] init];
	}
	
	return self;
}
- (void) dealloc {
	[userDefaults release];
	[currentConnections release];
	[super dealloc];
}

- (void)awakeFromNib {
	[mainWindow setAcceptsMouseMovedEvents:YES];

	staticToolbarItems = [[NSMutableDictionary alloc] init];
	[staticToolbarItems
		setObject:createStaticToolbarItem(nil, @"Connect", 
			@"Connect to a saved computer", @selector(showQuickConnect:))
		forKey:@"Connect"];
	[staticToolbarItems 
		setObject: createStaticToolbarItem(nil, @"Computers",
			@"Manage saved computers", @selector(showServerManager:))
		forKey:@"Computers"];
	[staticToolbarItems 
		setObject:createStaticToolbarItem(nil, @"Disconnect",
			@"Close the selected connection", @selector(disconnect:))
		forKey:@"Disconnect"];
	
	// Separate the static items from the connected servers
	[staticToolbarItems setObject:NSToolbarFlexibleSpaceItemIdentifier forKey:@"spacer1"];
	
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"CoRDMainToolbar"];
	[toolbar setDelegate:self];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
	[toolbar setAutosavesConfiguration:NO];
	[toolbar setSelectedItemIdentifier:@"Computers"];
	[mainWindow setToolbar:toolbar];


	if (![userDefaults objectForKey:@"LivePreviews"])
		[userDefaults registerDefaults:[NSDictionary dictionaryWithObject:@"YES" forKey:@"LivePreviews"]];
	previewsEnabled = [userDefaults boolForKey:@"LivePreviews"];
	[self setPreviewsVisible:previewsEnabled];
	
}

#pragma mark Toolbar methods

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar 
	 itemForItemIdentifier:(NSString *)itemIdentifier 
	willBeInsertedIntoToolbar:(BOOL)flag
{
	id staticItem = [staticToolbarItems objectForKey:itemIdentifier];
	if (staticItem) return staticItem;
	
	id active = [self connectionForLabel:itemIdentifier];
	if (active != nil)
		return [active toolbarRepresentation];
		
	return nil;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)tb {
	return [self toolbarDefaultItemIdentifiers:tb];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)tb {
	NSArray *staticItems = [NSArray arrayWithObjects:@"Connect", @"Computers", @"Disconnect",
			NSToolbarFlexibleSpaceItemIdentifier, nil];
	return staticItems;
}
- (NSArray *)toolbarSelectableItemIdentifiers: (NSToolbar *)toolbar;
{
	NSMutableArray *selectableItems = [NSMutableArray arrayWithCapacity:10];
	@synchronized(currentConnections) 
	{
		NSEnumerator *enumerator = [currentConnections objectEnumerator];
		id obj;
		while ( (obj = [enumerator nextObject]) )
			[selectableItems addObject:[obj label]];
	}
	return selectableItems;
}

- (int)count
{
	return [staticToolbarItems count];
}

-(BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
	NSString *itemId = [toolbarItem itemIdentifier];
	if ([itemId isEqualToString:@"Connect"])
	{
		return [quickConnectMenu numberOfItems] > 0;		
	}
	else if ([itemId isEqualToString:@"Disconnect"])
	{
		return [self selectedConnection] != nil;
	} else return YES;
}


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
		RDPFile *details = [RDPFile rdpFromFile:file];
		[self connectRDInstance:[serversManager rdInstanceFromRDPFile:details]];
	}
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)theApplication
{
    return NO;
}

#pragma mark Action Methods

- (IBAction)showServerManager:(id)sender {
	[serversWindow makeKeyAndOrderFront:self];
	[toolbar validateVisibleItems];
}

- (IBAction)disconnect:(id)sender {
	ActiveConnection *current = [self selectedConnection];
	if ([current rd]) {
		[[current rd] disconnect];
		[self removeItem:current];
	}
}

- (void)changeSelection:(id)sender {
	NSString *label;
	if ([sender isKindOfClass:[ActiveConnection class]])
		label = [sender label];
	else if ([sender isKindOfClass:[NSMenuItem class]])
		label = [sender title];
	else if ([sender isKindOfClass:[NSButton class]])
		label = [sender title];
	
	[toolbar setSelectedItemIdentifier:label];
	[tabView selectTabViewItemWithIdentifier:label];
	[self resizeToMatchSelection];
}

- (IBAction)togglePreviews:(id)sender
{
	previewsEnabled = !previewsEnabled;
	[self setPreviewsVisible:previewsEnabled];
	[userDefaults setBool:previewsEnabled forKey:@"LivePreviews"];
	[self resizeToMatchSelection];
}

- (IBAction)showQuickConnect:(id)sender
{
	[NSMenu popUpContextMenu:quickConnectMenu
				   withEvent:[[NSApplication sharedApplication] currentEvent]
					 forView:[sender view]];
}

#pragma mark Other methods

- (void)resizeToMatchSelection {
	id selection = [self selectedConnection];
	NSSize newContentSize;
	NSString *serverString;
	if (selection) {
		newContentSize = [[[selection rd] valueForKey:@"view"] frame].size;
		serverString = [selection label];
	} else {
		newContentSize = NSMakeSize(640, 480);
		serverString = @"CoRD";
	}
	
	NSRect windowFrame = [mainWindow frame];
	NSRect screenRect = [[mainWindow screen] visibleFrame];
	float scrollerWidth = [NSScroller scrollerWidth];
	float toolbarHeight = windowFrame.size.height - [[mainWindow contentView] frame].size.height;
	
	[mainWindow setContentMaxSize:newContentSize];	
	
	NSRect newWindowFrame = NSMakeRect( windowFrame.origin.x, windowFrame.origin.y +
										windowFrame.size.height-newContentSize.height-toolbarHeight, 
										newContentSize.width, newContentSize.height + toolbarHeight);
	if (newWindowFrame.size.height > screenRect.size.height &&
			newWindowFrame.size.width + scrollerWidth <= screenRect.size.width)
	{
		newWindowFrame.origin.y = screenRect.origin.y;
		newWindowFrame.size.height = screenRect.size.height;
		newWindowFrame.size.width += scrollerWidth;
	} else if (newWindowFrame.size.width>screenRect.size.width &&
				newWindowFrame.size.height+scrollerWidth <= screenRect.size.height)
	{
		newWindowFrame.origin.x = screenRect.origin.x;
		newWindowFrame.size.width = screenRect.size.width;
		newWindowFrame.size.height += scrollerWidth;
	}
	
	[mainWindow setFrame:newWindowFrame display:YES animate:YES];
}

- (void)removeItem:(id)sender
{
	
	ActiveConnection *ac = nil;
	if ([sender isKindOfClass:[ActiveConnection class]]) {
		ac = sender;
	} else if ([sender isKindOfClass:[RDInstance class]]) {
		// linear search current connections for the wrapper to this connection.. could be replaced
		//	with a much easier solution, but I forgot it..
		NSEnumerator * enumerator = [currentConnections objectEnumerator];
		id potentialConnection;
		@synchronized(currentConnections) 
		{
			while ( (potentialConnection = [enumerator nextObject]) )
			{
				if ([potentialConnection rd] == (RDInstance *)sender) {
					ac = potentialConnection;
					break;
				}
			}
		}
	}
	
	if (!ac) return;
	NSString *label = [ac label];
	
	[self selectNext:self];
	
	NSArray *toolbarItems = [toolbar items];
	int i;
	for (i = 0; i < [toolbarItems count]; i++)
	{
		if ([[[toolbarItems objectAtIndex:i] itemIdentifier] isEqual:label])
			[toolbar removeItemAtIndex:i];
	}

	[tabView removeTabViewItem:[ac tabViewRepresentation]];
	[ac disconnect];
	@synchronized(currentConnections) {
		[currentConnections removeObject:ac];
	}
	[self resizeToMatchSelection];
}

- (BOOL)windowShouldClose:(id)sender {
	[[NSApplication sharedApplication] hide:self];
	return NO;
}


- (IBAction)selectNext:(id) sender {
	int index = [self selectedConnectionIndex];
	if (index < 0) return;
	
	@synchronized(currentConnections) {
		int newIndex = wrap_array_index(index, [currentConnections count], 1);
		[self changeSelection:[currentConnections objectAtIndex:newIndex]];
	}
	[self resizeToMatchSelection];
}

- (IBAction)selectPrevious:(id) sender {
	int index = [self selectedConnectionIndex];
	if (index < 0) return;
	@synchronized(currentConnections) {
		int newIndex = wrap_array_index(index, [currentConnections count], -1);
		[self changeSelection:[currentConnections objectAtIndex:newIndex]];
	}
	[self resizeToMatchSelection];
}

- (void)setStatus:(NSString *)status {
	[errorField setStringValue:status];
}

- (void)connectRDInstance:(id)instance
{
	[instance retain];
	[NSThread detachNewThreadSelector:@selector(connectAsync:) toTarget:self
			withObject:instance];
}

- (void)connectAsync:(id)instance
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[instance setValue:self forKey:@"appController"];
	
	// segmented threading code:
	[instance setValue:[NSRunLoop currentRunLoop] forKey:@"runLoop"];
	[serversManager setConnecting:YES to:[instance valueForKey:@"displayName"]];
	BOOL connected = [instance connect];
	[serversManager setConnecting:NO to:nil];
	
	if (connected) {
		// Find a label that doesn't already exist
		int i=0;
		NSString *displayName = [instance valueForKey:@"displayName"],
				 *label = displayName;
		while ([self connectionForLabel:label] != nil && ++i<100)
			label = [displayName stringByAppendingString:[NSString stringWithFormat:@" %d", i]];
		[instance setValue:label forKey:@"displayName"];

		NSScrollView *scroll = [[[NSScrollView alloc] initWithFrame:[tabView frame]] autorelease];
		ActiveConnection *ac = [[ActiveConnection alloc] initFromRDInstance:instance scroll:scroll
					preview:previewsEnabled target:self];
		
		@synchronized(currentConnections) {
			[currentConnections addObject:ac];
		}
				
		[serversWindow close];
		[self performSelectorOnMainThread:@selector(completeConnection:)
					withObject:ac waitUntilDone:NO];
		[ac release];
		[instance release];
		
		
		[pool release];
		[ac startInputRunLoop];
		pool = [[NSAutoreleasePool alloc] init];
	} else {
		[self setStatus:[NSString stringWithFormat:@"Couldn't connect to %@",
					[instance valueForKey:@"displayName"]]];
	}

	[pool release];
}

- (void)completeConnection:(id)arg
{
	[toolbar insertItemWithItemIdentifier:[arg label]
				atIndex:[staticToolbarItems count] + [currentConnections count]-1];
	[tabView addTabViewItem:[arg tabViewRepresentation]];
		
	[mainWindow makeFirstResponder:[[arg rd] valueForKey:@"view"]];
	[self changeSelection:arg];
	[self resizeToMatchSelection];
}

// returns the currently selected tab in the form of an ActiveConnection
- (id)selectedConnection
{
	int index = [self selectedConnectionIndex];
	if (index > -1)
		return [currentConnections objectAtIndex:index];
	else
		return nil;
}
-(int)selectedConnectionIndex
{
	return [self connectionIndexForLabel:[toolbar selectedItemIdentifier]];
}

-(id)connectionForLabel:(NSString *)label
{
	@synchronized(currentConnections) 
	{
		NSEnumerator *enumerator = [currentConnections objectEnumerator];
		id obj;
		while ( (obj = [enumerator nextObject]) )
			if ([[obj label] isEqual:label]) return obj;
	}
	return nil;
}
-(int)connectionIndexForLabel:(NSString *)label
{
	@synchronized(currentConnections) 
	{
		int i, count = [currentConnections count];
		id obj;
		for (i = 0; i < count; i++)
		{
			obj = [currentConnections objectAtIndex:i];
			if ([[obj label] isEqual:label]) return i;
		}
	}
	return -1;
}

-(void)setPreviewsVisible:(BOOL)visible
{
	SEL action = (visible) ? @selector(enableThumbnailView) : @selector(disableThumbnailView);
	// this line might need a lock, but I don't think so
	[currentConnections makeObjectsPerformSelector:action];
	NSString *text = (visible) ? @"Hide" : @"Show";
	[previewToggleMenu setTitle:[text stringByAppendingString:@" Previews"]];
	
	if (visible) [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];
	else [toolbar setDisplayMode:NSToolbarDisplayModeLabelOnly];
}

@end





#pragma mark Stubs

/* Just a few stubs specific to this module */
NSToolbarItem * createStaticToolbarItem(NSView *view, NSString *name,
		NSString *tooltip, SEL action)
{
	NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:name] autorelease];
	[item setPaletteLabel:name];
	[item setLabel:name];
	[item setToolTip:tooltip];
	[item setAction:action];
	if (view) {
		[item setView:view];
		[item setMinSize:[view bounds].size];
		[item setMaxSize:[view bounds].size];
	} else
		[item setImage:[NSImage imageNamed:[NSString stringWithFormat:@"%@.png", name]]];
		
	return item;
}

int wrap_array_index(int start, int count, signed int modifier) {
	int new = start + modifier;
	if (new < 0) new = count-1;
	else if (new >= count) new = 0;
	return new;
}