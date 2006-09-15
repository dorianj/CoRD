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

@implementation AppController

#pragma mark NSObject methods
- (void)awakeFromNib {
	[mainWindow setAcceptsMouseMovedEvents:YES];
	
	NSToolbarItem *item;
	NSString *name = @"New Server";
	item=[[NSToolbarItem alloc] initWithItemIdentifier:name];
	
	[item setPaletteLabel:name];
	[item setLabel:name];
	[item setToolTip:@"Connect to a new server"];
	[item setView:openButton];
	[item setMinSize:[openButton bounds].size];
	[item setMaxSize:[openButton bounds].size];
	
	toolbarItems = [[[NSMutableDictionary alloc] init] retain];
	[toolbarItems setObject:item forKey:name];
	[item release];
	
	name = @"Disconnect";
	item=[[NSToolbarItem alloc] initWithItemIdentifier:name];
	
	[item setPaletteLabel:name];
	[item setLabel:name];
	[item setToolTip:@"Disconnect from the current server"];
	[item setView:disconnectButton];
	[item setMinSize:[disconnectButton bounds].size];
	[item setMaxSize:[disconnectButton bounds].size];
	
	[toolbarItems setObject:item forKey:name];
	[item release];
	
	name = @"Servers";
	item=[[NSToolbarItem alloc] initWithItemIdentifier:name];
	
	[item setPaletteLabel:name];
	[item setLabel:name];
	[item setToolTip:@"Connected Servers"];
	[item setView:serverPopup];
	[item setMinSize:[serverPopup bounds].size];
	[item setMaxSize:[serverPopup bounds].size];
	
	[toolbarItems setObject:item forKey:name];
	[item release];
	
	toolbar = [[NSToolbar alloc] initWithIdentifier:@"Toolbar"];
	[toolbar setDelegate:self];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
	[mainWindow setToolbar:toolbar];
}

#pragma mark Toolbar methods

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar 
	 itemForItemIdentifier:(NSString *)itemIdentifier 
 willBeInsertedIntoToolbar:(BOOL)flag {
	return [toolbarItems objectForKey:itemIdentifier];
	
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)tb {
	return [self toolbarDefaultItemIdentifiers:tb];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)tb {
	NSMutableArray *ret = [NSMutableArray array];
	[ret addObject:@"New Server"];
	[ret addObject:@"Disconnect"];
	[ret addObject:NSToolbarFlexibleSpaceItemIdentifier];
	[ret addObject:@"Servers"];
	
	return ret;
}

- (int)count {
	return [toolbarItems count];
}

#pragma mark Action Methods

- (IBAction)newServer:(id)sender {
	[NSApp beginSheet:newServerSheet 
	   modalForWindow:mainWindow
		modalDelegate:self
	   didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) 
		  contextInfo:NULL];
}

- (IBAction)hideOptions:(id)sender {
	NSRect windowFrame, boxFrame;

	boxFrame = [box frame];
	windowFrame = [newServerSheet frame];

	if (![sender state]) {
		[box setHidden:YES];
	}
	
	if ([sender state]) {
		windowFrame.size.height += boxFrame.size.height + 5.0;
		windowFrame.origin.y -= boxFrame.size.height + 5.0;
	} else {
		windowFrame.size.height -= boxFrame.size.height + 5.0;
		windowFrame.origin.y += boxFrame.size.height + 5.0;
	}
	
	[newServerSheet setFrame:windowFrame display:YES animate:YES];
	
	if ([sender state]) {
		[box setHidden:NO];
	}
}

- (IBAction)connectSheet:(id)sender {
	if ([[host stringValue] compare:@""] == 0) {
		[NSApp endSheet:newServerSheet];
		return;
	}
	
	RDInstance *instance = [[RDInstance alloc] init];
	[instance setValue:[host stringValue] forKey:@"name"];
	[instance setValue:[host stringValue] forKey:@"displayName"];
	[instance setValue:[screenResolution titleOfSelectedItem] forKey:@"screenResolution"];
	[instance setValue:[colorDepth titleOfSelectedItem] forKey:@"colorDepth"];
	[instance setValue:[NSNumber numberWithInt:[forwardDisks intValue]] forKey:@"forwardDisks"];
	[instance setValue:[forwardAudio titleOfSelectedItem] forKey:@"forwardAudio"];
	[instance setValue:[NSNumber numberWithInt:[cacheBitmaps intValue]] forKey:@"cacheBitmaps"];
	[instance setValue:[NSNumber numberWithInt:[drawDesktop intValue]] forKey:@"drawDesktop"];
	[instance setValue:[NSNumber numberWithInt:[windowDrags intValue]] forKey:@"windowDrags"];
	[instance setValue:[NSNumber numberWithInt:[windowAnimation intValue]] forKey:@"windowAnimation"];
	[instance setValue:[NSNumber numberWithInt:[themes intValue]] forKey:@"themes"];
	[instance setValue:self forKey:@"appController"];
	
	if (![instance connect]) {
		[instance release];
		return;
	}
	
	NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:[tabView frame]];
	[scroll setDocumentView:[instance valueForKey:@"view"]];
	[scroll setHasVerticalScroller:YES];
	[scroll setHasHorizontalScroller:YES];
	[scroll setAutohidesScrollers:YES];
	[scroll setBorderType:NSNoBorder];

	
	NSTabViewItem *item = [[NSTabViewItem alloc] initWithIdentifier:[instance valueForKey:@"view"]];	
	[item setView:scroll];
	[item setLabel:[instance valueForKey:@"name"]];
	[tabView addTabViewItem:item];
	[mainWindow makeFirstResponder:[instance valueForKey:@"view"]];
	
	[arrayController addObject:instance];
	[instance release];
	[serverPopup selectItemAtIndex:[arrayController selectionIndex]];
	
	[self resizeToMatchSelection];
	
	NSMutableArray *recent = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"RecentServers"]];
	if (![recent containsObject:[host stringValue]]) {
		[recent addObject:[host stringValue]];
		[[NSUserDefaults standardUserDefaults] setObject:recent forKey:@"RecentServers"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
	
	[NSApp endSheet:newServerSheet];
}

- (IBAction)cancelSheet:(id)sender {
	[NSApp endSheet:newServerSheet];
}

- (IBAction)disconnect:(id)sender {
	int index = [serverPopup indexOfSelectedItem];
	if (index == -1) {
		return;
	}
	
	RDInstance *instance = [[arrayController arrangedObjects] objectAtIndex:index];
	if (instance) {
		[self removeItem:instance];
		[instance disconnect];
	}
}

- (IBAction)changeSelection:(id)sender {
	[arrayController setSelectionIndex:[sender indexOfSelectedItem]];
	[self resizeToMatchSelection];
}

#pragma mark Other methods

- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	[sheet orderOut:self];
}

- (void)resizeToMatchSelection {
	int index = [serverPopup indexOfSelectedItem];
	id selection;
	NSSize newContentSize;
	NSString *serverString;
	
	if (index != -1) {
		selection = [[arrayController arrangedObjects] objectAtIndex:index];
		newContentSize = [[selection valueForKey:@"view"] frame].size;
		serverString = [NSString stringWithFormat:@" (%@)", [selection valueForKey:@"displayName"]];
	} else {
		newContentSize = NSMakeSize(640, 480);
		serverString = @"";
	}
	
	NSRect windowFrame = [mainWindow frame];
	float toolbarHeight = windowFrame.size.height - [[mainWindow contentView] frame].size.height;
	
	[mainWindow setContentMaxSize:newContentSize];	
	[mainWindow setFrame:NSMakeRect(windowFrame.origin.x, windowFrame.origin.y + windowFrame.size.height - newContentSize.height - toolbarHeight, 
								newContentSize.width, newContentSize.height + toolbarHeight)
				 display:YES
				 animate:YES];
	
	[mainWindow setTitle:[NSString stringWithFormat:@"Remote Desktop%@", serverString]];
}

- (void)removeItem:(id)sender {
	[arrayController removeObject:sender];
	
	int index = [arrayController selectionIndex];
	[serverPopup selectItemAtIndex:index];
	
	NSArray *items = [tabView tabViewItems];
	NSEnumerator *e = [items objectEnumerator];
	NSTabViewItem *tabViewItem;
		
	while ((tabViewItem = [e nextObject])) {
		if ([tabViewItem identifier] == [sender valueForKey:@"view"]) {
			break;
		}
	}
	
	if (tabViewItem == nil) {
		NSLog(@"No match found");
		return;
	}
	
	[tabView removeTabViewItem:tabViewItem];
	[tabViewItem release];
		  
	[self resizeToMatchSelection];
}

- (BOOL)windowShouldClose:(id)sender {
	[[NSApplication sharedApplication] hide:self];
	return NO;
}

@end
