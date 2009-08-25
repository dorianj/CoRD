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
#import "AppController.h"
#import "CRDShared.h"

#define CRDPreferencesGeneralTabTag 0
#define CRDPreferencesConnectionTabTag 1
#define CRDPreferencesForwardingTabTag 2
#define CRDPreferencesAdvancedTabTag 3

#pragma mark -

@implementation PreferencesController

- (void)awakeFromNib
{
	[screenResolutionsController setSortDescriptors:[NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"resolution" ascending:YES selector:@selector(compareScreenResolution:)] autorelease]]];
	[screenResolutionsController addObserver:self forKeyPath:@"sortDescriptors" options:0 context:NULL];
	[self changePanes:[[toolbar items] objectAtIndex:0]];
}

- (IBAction)changePanes:(id)sender
{
	NSView *currentPane = [preferencesWindow contentView], *newPane = nil;
	
	if ([sender tag] == CRDPreferencesGeneralTabTag)
		newPane = generalView;
	else if ([sender tag] == CRDPreferencesConnectionTabTag)
		newPane = connectionView;
	else if ([sender tag] == CRDPreferencesForwardingTabTag)
		newPane = forwardingView;
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
	else if ([sender tag] == CRDPreferencesForwardingTabTag)
		helpAnchor = @"ForwardingPreferences";
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
#pragma mark General pane

- (IBAction)restoreAllSettingsToDefault:(id)sender
{
	NSInteger buttonPressed = NSRunAlertPanel(@"Restore default settings", @"Are you sure you want to restore your CoRD settings to the built-in defaults? Saved servers will not be affected.", @"Restore Defaults", @"Cancel", nil);

	if (buttonPressed != 1)
		return;
		
	NSDictionary *builtInDefaults = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]];
	NSSet *excludedKeys = [NSSet setWithObjects:@"CRDScreenResolutions", nil];
	for (NSString *defaultKey in builtInDefaults)
		if (![excludedKeys containsObject:defaultKey])
			[[NSUserDefaults standardUserDefaults] setObject:[builtInDefaults objectForKey:defaultKey] forKey:defaultKey];
}


#pragma mark -
#pragma mark Screen resolution editor

- (IBAction)restoreDefaultScreenResolutions:(id)sender
{

	NSInteger buttonPressed = NSRunAlertPanel(@"Restore default resolutions", @"Are you sure you want to restore the default screen resolutions? Any additions you have made will be lost.", @"Restore Defaults", @"Cancel", nil);	
	if (buttonPressed != 1)
		return;

	NSDictionary *builtInDefaults = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]];
	[[NSUserDefaults standardUserDefaults] setObject:[builtInDefaults objectForKey:@"CRDScreenResolutions"] forKey:@"CRDScreenResolutions"];
}

- (IBAction)addNewScreenResolution:(id)sender
{
	// -[NSArrayController insert] performs its action in the next runloop cycle, so wait a bit before starting to edit the new row.
	// also, the NSArrayController won't select the row for us, due to a bug where "compound object" and selectsInsertedObjects don't work together ( rdar://7079110 ) 
	
	BOOL foundExistingEmptyRow = NO;
	for (NSDictionary *value in [screenResolutionsController arrangedObjects])
		if (![[value objectForKey:@"resolution"] length])
		{
			foundExistingEmptyRow = [screenResolutionsController setSelectedObjects:[NSArray arrayWithObject:value]];
			break;
		}
	
	if (foundExistingEmptyRow)
		[screenResolutionsTableView editSelectedRow:[NSNumber numberWithInteger:0]];
	else
	{
		[screenResolutionsController add:nil];
		[self performSelector:@selector(addNewScreenResolution:) withObject:nil afterDelay:0.05];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == screenResolutionsController)
		if ([keyPath isEqualToString:@"sortDescriptors"])
			[g_appController updateInspectorToMatchSelectedServer];
}


#pragma mark -
#pragma mark Forwarded Paths Editor

- (IBAction)addNewForwardedPath:(id)sender
{
	// -[NSArrayController insert] performs its action in the next runloop cycle, so wait a bit before starting to edit the new row.
	// also, the NSArrayController won't select the row for us, due to a bug where "compound object" and selectsInsertedObjects don't work together ( rdar://7079110 ) 
	
	BOOL foundExistingEmptyRow = NO;
	for (NSDictionary *value in [forwardedPathsController arrangedObjects])
		if (![[value objectForKey:@"label"] length])
		{
			foundExistingEmptyRow = [forwardedPathsController setSelectedObjects:[NSArray arrayWithObject:value]];
			break;
		}
	
	if (foundExistingEmptyRow)
	{	
		[forwardedPathsTableView editSelectedRow:[NSNumber numberWithInteger:1]];
		[self addPathPanelOpen:sender];
	}
	else
	{
		[forwardedPathsController add:nil];
		[self performSelector:@selector(addNewForwardedPath:) withObject:nil afterDelay:0.05];
	}
}

- (IBAction)addPathPanelOpen:(id)sender
{
	NSOpenPanel *folderPanel = [NSOpenPanel openPanel];
	
	[folderPanel setPrompt: NSLocalizedString(@"Select", "Preferences -> New Forwarded Path Panel Prompt")];
	[folderPanel setAllowsMultipleSelection: NO];
	[folderPanel setCanChooseFiles: NO];
	[folderPanel setCanChooseDirectories: YES];
	[folderPanel setCanCreateDirectories: YES];
	
	[folderPanel beginSheetForDirectory:nil 
								   file:nil 
								  types:nil
						 modalForWindow:preferencesWindow 
						  modalDelegate:self 
						 didEndSelector:@selector(addPathPanelClosed: returnCode: contextInfo:) 
							contextInfo: nil];
}

- (void)addPathPanelClosed:(NSOpenPanel *)openPanel returnCode:(int)code contextInfo:(void *)info
{
	NSString *path = @"~/";
	if (code == NSOKButton)
	{		
		path = [[openPanel filenames] objectAtIndex: 0];
		[[forwardedPathsController selection] setValue:[path stringByExpandingTildeInPath] forKey:@"path"];

		if (![[forwardedPathsController selection] valueForKey:@"label"])
		{
			if ([[path lastPathComponent] length] > 7)
				[[forwardedPathsController selection] setValue:[[path lastPathComponent] substringToIndex:7] forKey:@"label"];
			else if (![path lastPathComponent])
				[[forwardedPathsController selection] setValue:@"Root" forKey:@"label"];
		}
			
		
	}
}

@end
