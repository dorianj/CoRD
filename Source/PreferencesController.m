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

#define CRDPreferencesGeneralTabTag 0
#define CRDPreferencesConnectionTabTag 1
#define CRDPreferencesAdvancedTabTag 2


#pragma mark -

@implementation PreferencesController

- (void)awakeFromNib
{
	[self changePanes:[[toolbar items] objectAtIndex:0]];
}


- (IBAction)changePanes:(id)sender
{
	NSView *currentPane = [preferencesWindow contentView], *newPane = nil;
	
	if ([sender tag] == CRDPreferencesGeneralTabTag)
		newPane = generalView;
	else if ([sender tag] == CRDPreferencesConnectionTabTag)
		newPane = connectionView;
	else if ([sender tag] == CRDPreferencesAdvancedTabTag)
		newPane = advancedView;
	
	if ( (newPane == nil) || (currentPane == newPane) )
		return;
		
	[preferencesWindow makeFirstResponder:nil];
	[preferencesWindow setContentView:[[[NSView alloc] initWithFrame:[[preferencesWindow contentView] frame]] autorelease]];
	[toolbar setSelectedItemIdentifier:[sender itemIdentifier]];
	
	NSRect newFrame = [preferencesWindow frame];
	newFrame.size.height = [newPane frame].size.height + ([preferencesWindow frame].size.height - [[preferencesWindow contentView] frame].size.height);
	newFrame.size.width = [newPane frame].size.width; 
	newFrame.origin.y += ([[preferencesWindow contentView] frame].size.height - [newPane frame].size.height);
	
	
	[preferencesWindow setFrame:newFrame display:YES animate:YES];
	[[preferencesWindow animator] setContentView:newPane];
	[preferencesWindow makeFirstResponder:newPane];
}

#pragma mark -
#pragma mark Managing Update Feeds

- (IBAction)sparkleTypeChanged:(id)sender
{
	NSString *newUpdateType = [[NSUserDefaults standardUserDefaults] valueForKey:@"SUUpdateType"];

	if ([newUpdateType isEqual:@"Beta Releases"])
		[[NSUserDefaults standardUserDefaults] setValue:@"http://cord.sourceforge.net/appcast-beta.xml" forKey:@"SUFeedURL"];
	else if ([newUpdateType isEqual:@"Nightly Releases"])
		[[NSUserDefaults standardUserDefaults] setValue:@"http://cord.sourceforge.net/appcast-nightly.xml" forKey:@"SUFeedURL"];
	else 
		[[NSUserDefaults standardUserDefaults] setValue:@"http://cord.sourceforge.net/sparkle.xml" forKey:@"SUFeedURL"];
}

#pragma mark -
#pragma mark Calling for help

- (IBAction)showPreferencesHelp:(id)sender
{
	NSString *helpAnchor = @"";
	
	if ([sender tag] == CRDPreferencesGeneralTabTag)
		helpAnchor = @"GeneralPreferences";
	else if ([sender tag] == CRDPreferencesConnectionTabTag)
		helpAnchor = @"ConnectionPreferences";
	else if ([sender tag] == CRDPreferencesAdvancedTabTag)
		helpAnchor = @"";

	if ([helpAnchor length])
		[[NSHelpManager sharedHelpManager] openHelpAnchor:helpAnchor inBook:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleHelpBookName"]];
}


#pragma mark -
#pragma mark NSToolbarDelegate

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar_
{
	NSMutableArray *selectableItemsBuilder = [NSMutableArray array];
	for (NSToolbarItem *toolbarItem in [toolbar_ items])
		[selectableItemsBuilder addObject:[toolbarItem itemIdentifier]];
	
	return selectableItemsBuilder;
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
