//  Copyright (c) 2006 Dorian Johnson <arcadiclife@gmail.com>
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

#import "ConnectionsController.h"
#import "RDPFile.h"
#import "keychain.h"

@interface ConnectionsController (PrivateMethods)
	- (void) listUpdated;
	- (id) selectedRowLabel;
	- (id) labelForRow:(int)row;
	- (id) selectedObject;
	- (id) objectForRow:(int)row;
@end

#pragma mark -
@implementation ConnectionsController


#pragma mark Actions

- (IBAction)addNewServer:(id)sender
{
	// Use the currently selected server as default. If no server is selected, 
	//	copy the Default.rdp out of the app resources
	id selectedServer = [self selectedObject], rdpFile;
	NSString *baseServerLabel,  *baseServerPath, *label;
	volatile int i, l, j; // these were getting corrupted in debugger
	
	if (selectedServer == nil) {
		baseServerPath = [resourcePath stringByAppendingPathComponent:@"Default.rdp"];
		baseServerLabel = @"New server";
	} else {
		baseServerPath = [selectedServer filename];
		baseServerLabel = [self labelForRow:[gui_serverList selectedRow]];
		
		// chop off the at the end ' #' if it's there. xxx this is hacky.
		const char *lbl = [baseServerLabel UTF8String];
		l = [baseServerLabel length];
		for (i = 0, j = MIN(l, 4); i < j; i++)
			if (!isdigit(lbl[l-i-1]) && lbl[l-i-1] != ' ') break;
		baseServerLabel = [baseServerLabel substringToIndex:l-i];
	}

	
	// play the 'append numbers until one found that doesn't exist' game
	BOOL serversContainsLabel;
	NSEnumerator *enumerator;
	i = 0;
	do
	{	
		i++;
		label = [baseServerLabel stringByAppendingFormat:@" %i", i];
		serversContainsLabel = NO;
		for (enumerator = [servers objectEnumerator]; (rdpFile = [enumerator nextObject]); )
		{
			if ([[rdpFile label] isEqualToString:label]) {
				serversContainsLabel = YES;
				break;
			}			
		}
	} while (serversContainsLabel);
				
	baseServerLabel = label;
	
	
	NSString *newServerFileName =
			findAvailableFileName([baseServerPath stringByDeletingLastPathComponent],
					baseServerLabel, @".rdp");
	NSString *newServerLabel = [newServerFileName stringByDeletingPathExtension];
	NSString *newServerPath = [serversDirectory stringByAppendingPathComponent:newServerFileName];

	// Copy the base file into this new one
	NSFileManager *fileManager = [NSFileManager defaultManager];
	[fileManager copyPath:baseServerPath toPath:newServerPath handler:nil];
	
	// Load this newly-copied file into an RDPFile instance, failing gracefully if it doesn't load
	RDPFile *newServer;
	newServer = ( (newServer = [RDPFile rdpFromFile:newServerPath]) != nil)
			? newServer
			: [[RDPFile alloc] init];
	
	[newServer setLabel:newServerLabel];
	[newServer setFilename:newServerPath];
	[servers addObject:newServer];
	
	[self listUpdated];
	[gui_serverList
			selectRowIndexes: [NSIndexSet indexSetWithIndex:[gui_serverList numberOfRows]-1]
		byExtendingSelection:NO];
}

- (IBAction)cancelChanges:(id)sender
{
	[gui_mangerWindow close];
}

- (IBAction)connect:(id)sender
{
	id server = [self selectedObject];
	RDInstance *inst;
	if (server) {
		// save current options, then load current options into an RDInstance and connect
		[self saveServer:[gui_serverList selectedRow]];
		inst = [self rdInstanceFromRDPFile:server];
	} else {
		// connect to current options but don't save any of it
		inst = [self rdInstanceFromRDPFile:[self currentOptions]];		
	}
	[appController connectRDInstance:inst];
}
/* Removes the currently selected server, and deletes the file */
- (IBAction)removeServer:(id)sender
{
	id server = [self selectedObject];
	if (server == nil) return;
	
	NSString *path = [server filename];
	[[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
	[servers removeObjectAtIndex:[gui_serverList selectedRow]];
	
	[self listUpdated];
}

- (IBAction)showOpen:(id)sender
{
	[self showOpen:sender keepServer:NO];
}

- (IBAction)showOpenAndKeep:(id)sender
{
	[self showOpen:sender keepServer:YES];
}

#pragma mark NSTableDataSource methods

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [servers count];
}
- (id)tableView:(NSTableView *)aTableView
		objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	NSString *label = [self labelForRow:rowIndex];
	return label;
}
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject
		forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	id label = [self labelForRow:rowIndex];
	if (label == nil || [label isEqual:anObject]) return;
	id objectBeingRenamed = [self objectForRow:rowIndex];
	// Rename file, change the label

	// try to clean up the file name as best possible. I don't know a better, more robust way.
	NSString *newLabel = [anObject copy];

	// Get an available new name
	NSString *filename = findAvailableFileName(serversDirectory, newLabel, @".rdp");
	
	// Do the rename, tidy up
	NSString *origPath = [[self objectForRow:rowIndex] filename];
	NSString *newPath  = [serversDirectory stringByAppendingPathComponent:filename];
	[[NSFileManager defaultManager] movePath:origPath toPath:newPath handler:nil];
	[objectBeingRenamed setLabel:newLabel];
	[objectBeingRenamed setFilename:newPath];
}

/* Drag and drop methods */

- (NSDragOperation)tableView:(NSTableView*)tv validateDrop:(id <NSDraggingInfo>)info
		proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)op
{
	
	if ([info draggingSource] == (id)gui_serverList)
	{
		// inner list drag, currently ignoring. Todo: allow for item moving
		return NSDragOperationNone;
	} 
	else
	{
		// external drag, make sure there's at least one RDP file in there
		NSArray *files = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
		NSArray *rdpFiles = filter_filenames(files, [NSArray arrayWithObjects:@"rdp",nil]);
		return ([rdpFiles count] > 0) ? NSDragOperationCopy : NSDragOperationNone;
	}	
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info
		row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
	if ([info draggingSource] == (id)gui_serverList)
	{
		// inner list drag, currently ignoring. Todo: allow for item moving
		return NO;
	} 
	else
	{
		// external drag, load all rdp files passed
		NSArray *files = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
		NSArray *rdpFiles = filter_filenames(files, [NSArray arrayWithObjects:@"rdp",nil]);
		NSEnumerator *enumerator = [rdpFiles objectEnumerator];
		id file;
		while ( (file = [enumerator nextObject]) )
		{
			[self addServer:[RDPFile rdpFromFile:file]];
		}
		
		return YES;
	}
}

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes
		toPasteboard:(NSPasteboard*)pboard
{
	NSMutableArray *filenames = [NSMutableArray arrayWithCapacity:5];
	NSEnumerator *e = [servers objectEnumerator];
	id rdp;
	unsigned i = 0;
	while ( (rdp = [e nextObject]) )
	{
		if ([rowIndexes containsIndex:i]) {
			[filenames addObject:[rdp filename]]; 	
		}
		i++;
	}
	[pboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:nil];
	[pboard setPropertyList:filenames forType:NSFilenamesPboardType];
	
	return YES;
}

#pragma mark NSTableView delegate

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{

	// Save the current settings into the last selected row. Use mergeWith so
	//	that any MSTSC-defined keys we don't recognize are preserved
	if (lastRowViewed >= 0 && lastRowViewed < [servers count]) {
		[self saveServer:lastRowViewed];
	}	
	
	id label = [self selectedRowLabel];
	if (label == nil) {
		lastRowViewed = -1;
		return;
	}
	[self setCurrentOptions:[self selectedObject]];
	lastRowViewed = [gui_serverList selectedRow];
}

// Allow everything to be edited
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn
		row:(int)rowIndex
{
	id key = [self labelForRow:rowIndex];
	return key != nil;
}


#pragma mark Converting between RDPFile and displayed options

/* Turns the selected options into an RDPFile */
- (RDPFile *)currentOptions
{
	return [self currentOptionsByMerging:nil];
}

- (RDPFile *)currentOptionsByMerging:(RDPFile *)originalOptions
{
	// Set up a temporary dictionary, taking it from the passed attributes if possible
	NSMutableDictionary *mergeWith =
			(!originalOptions) 
				? [[NSMutableDictionary alloc] init]
				: [[originalOptions attributes] mutableCopy];
	
	RDPFile *newRDP =
			(!originalOptions)
				? [[[RDPFile alloc] init] autorelease]
				: originalOptions;
	
	// Set all of the checkbox options
	[mergeWith setObject:buttonStateAsNumber(gui_cacheBitmaps) forKey:@"bitmapcachepersistenable"];
	[mergeWith setObject:buttonStateAsNumberInverse(gui_displayDragging) forKey:@"disable full window drag"];
	[mergeWith setObject:buttonStateAsNumberInverse(gui_drawDesktop) forKey:@"disable wallpaper"];
	[mergeWith setObject:buttonStateAsNumberInverse(gui_enableAnimations) forKey:@"disable menu anims"];
	[mergeWith setObject:buttonStateAsNumberInverse(gui_enableThemes) forKey:@"disable themes"];
	[mergeWith setObject:buttonStateAsNumber(gui_savePassword) forKey:@"save password"];
	[mergeWith setObject:buttonStateAsNumber(gui_forwardDisks) forKey:@"redirectdrives"];

	
	// Set the text fields
	[mergeWith setObject:[gui_host stringValue] forKey:@"full address"];
	[mergeWith setObject:[gui_username stringValue] forKey:@"username"];
	
	
	// Set screen depth
	[mergeWith setObject:[NSNumber numberWithInt:([gui_colorCount indexOfSelectedItem]+1)*8]
			forKey:@"session bpp"];
			
	// Get resolution. This one's sort of a doozie.
	NSScanner *scanner = [NSScanner scannerWithString:[gui_screenResolution titleOfSelectedItem]];
	[scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"x"]];
	int width, height;
	[scanner scanInt:&width]; [scanner scanInt:&height];
	[mergeWith setObject:[NSNumber numberWithInt:width] forKey:@"desktopwidth"];
	[mergeWith setObject:[NSNumber numberWithInt:height] forKey:@"desktopheight"];
	
	// Save whether password should be saved to keychain. Actual keychain save
	//	happens later
	if ([gui_savePassword state] == NSOnState) {
		[newRDP setPassword:[gui_password stringValue]];
		[mergeWith setObject:[NSNumber numberWithInt:1] forKey:@"cord save password"];
	} else {
		[newRDP setPassword:nil];
		[mergeWith setObject:[NSNumber numberWithInt:0] forKey:@"cord save password"];
	}
	
	
	// Clear the keychain password of the original if needed
	if (![[newRDP getStringAttribute:@"full address"]
			isEqualToString:[mergeWith valueForKey:@"full address"]] ||
		![[mergeWith valueForKey:@"cord save password"] boolValue])
	{
		[self clearPassword:originalOptions];
	}
	
	
	// Todo: audio popup box
	
	// put our temporary dictionary back into the passed rdp file and return 
	[newRDP setAttributes:[mergeWith copy]];
	[mergeWith release];
		
	return newRDP;
}

/* Takes an RDPFile and updates the currently selected options to match the settings in it */
- (void)setCurrentOptions:(RDPFile *)newSettings
{
	if (newSettings == nil) return;
	
	// Set the checkboxes 
	[gui_cacheBitmaps		setState:boolAsButtonState([newSettings getBoolAttribute:@"bitmapcachepersistenable"])];
	[gui_displayDragging	setState:!boolAsButtonState([newSettings getBoolAttribute:@"disable full window drag"])];
	[gui_drawDesktop		setState:!boolAsButtonState([newSettings getBoolAttribute:@"disable wallpaper"])];
	[gui_enableAnimations	setState:!boolAsButtonState([newSettings getBoolAttribute:@"disable menu anims"])];
	[gui_enableThemes		setState:!boolAsButtonState([newSettings getBoolAttribute:@"disable themes"])];
	[gui_savePassword		setState:boolAsButtonState([newSettings getBoolAttribute:@"save password"])];
	[gui_forwardDisks		setState:boolAsButtonState([newSettings getBoolAttribute:@"redirectdrives"])];
	
	// Set some of the textfield inputs
	[gui_host setStringValue:[newSettings getStringAttribute:@"full address"]];
	[gui_username setStringValue:[newSettings getStringAttribute:@"username"]];
	
	// Set the color depth
	int colorDepth = [newSettings getIntAttribute:@"session bpp"];
	if (colorDepth == 24 || colorDepth == 16 || colorDepth == 8)
		[gui_colorCount selectItemAtIndex:(colorDepth/8-1)];
	
	// Set the resolution
	int screenWidth = [newSettings getIntAttribute:@"desktopwidth"];
	int screenHeight = [newSettings getIntAttribute:@"desktopheight"]; 
	if (screenWidth == 0 || screenHeight == 0) {
		screenWidth = 1024;
		screenHeight = 768;
	}
	NSString *resolutionLabel = [NSString stringWithFormat:@"%dx%d", screenWidth, screenHeight];
	// If this resolution doesn't exist in the popup box create it. Either way, select it.
	id menuItem = [gui_screenResolution itemWithTitle:resolutionLabel];
	if (!menuItem)
		[gui_screenResolution addItemWithTitle:resolutionLabel];
	[gui_screenResolution selectItemWithTitle:resolutionLabel];
	
	if ([newSettings getBoolAttribute:@"cord save password"]) {
		[gui_password setStringValue:[self retrievePassword:newSettings]];
	} else {
		[gui_password setStringValue:@""];
	}
	
	// Todo: audio routing popup box
}

/* Merges any settings changes in the gui to a given row */
- (void) saveServer:(int)row
{
	NSString *label = [self labelForRow:row];
	if (label == nil) return;
	// Save to file
	RDPFile *rdp = [self objectForRow:row];
	NSString *filename = [rdp filename];
	[self currentOptionsByMerging:rdp];
	[rdp writeToFile:filename];

	// Save password to keychain
	if ([rdp getBoolAttribute:@"cord save password"]) {
		keychain_save_password(safe_string_conv([rdp getStringAttribute:@"full address"]),
					safe_string_conv([rdp getStringAttribute:@"username"]),
					safe_string_conv([rdp password]));
	}
}

#pragma mark NSWindow delegate methods
- (void)windowWillClose:(id)sender 
{
	[self saveServer:[gui_serverList selectedRow]];
}


#pragma mark NSObject methods
- (id) init {
	self = [super init];
	if (self != nil) {
		servers = [[NSMutableArray alloc] init];
		lastRowViewed = -1;
	}
	return self;
}
- (void) dealloc {
	[resourcePath release];
	[serversDirectory release];
	[servers release];
	[super dealloc];
}
- (void)awakeFromNib 
{

	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	// Assure that the CoRD application support folder is created, locate and store other useful paths
	NSString *appSupport = 
		[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
			NSUserDomainMask, YES) objectAtIndex:0];
	NSString *cordDirectory = [appSupport stringByAppendingString:@"/CoRD"];
	serversDirectory = [[appSupport stringByAppendingString:@"/CoRD/Servers"] retain];
	resourcePath = [[NSBundle mainBundle] resourcePath];
	
	ensureDirectoryExists(cordDirectory, fileManager);
	ensureDirectoryExists(serversDirectory, fileManager);
		

	// Get a list of files from the Servers directory, load each
	RDPFile *rdpinfo;
	NSString *filename, *path;
	NSArray *files = [fileManager directoryContentsAtPath:serversDirectory];
	int i, fileCount = [files count];
	for (i = 0; i < fileCount; i++)
	{
		filename = [files objectAtIndex:i];
		path = [NSString stringWithFormat:@"%@/%@", serversDirectory, filename];
		if ([[filename pathExtension] isEqual:@"rdp"])
		{
			rdpinfo = [RDPFile rdpFromFile:path];
			if (rdpinfo != nil)
				[servers addObject:rdpinfo];
			else {
				NSLog(@"RDP file '%@' failed to load!", filename);
				// TODO: delete that rdp file, or at least rename it to .rdp.bak
			}
		}
	}
	[gui_serverList setDraggingSourceOperationMask:NSDragOperationCopy forLocal:NO];
	[gui_serverList setDraggingSourceOperationMask:NSDragOperationMove forLocal:YES];
	[gui_serverList registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
	
	[self listUpdated];
		
	if ([gui_serverList numberOfRows] > 0) {
		[gui_serverList selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
				byExtendingSelection:NO];
	} else {
	
	
	}
}


#pragma mark Other misc stuff

- (void) toggleProgressIndicator:(BOOL)on
{
	if (on) [gui_Throbber startAnimation:self];
	else [gui_Throbber stopAnimation:self];
}


/*	Function to translate between a MSTSC description and RDInstance file. I decided not to change
		RDInstance's variable names and just do this because I didn't know RDInstance very well or 
		what depended on it. It could be changed if so desired.
*/
- (RDInstance *) rdInstanceFromRDPFile:(RDPFile *)source
{
	
	RDInstance *newInstance = [[[RDInstance alloc] init] autorelease];
	
	// extract port/host
	int port;
	NSString *host = nil;
	split_hostname([source getStringAttribute:@"full address"], &host, &port);
	
	[newInstance setValue:host forKey:@"hostName"];
	[newInstance setValue:[NSNumber numberWithInt:port] forKey:@"port"];
	[newInstance setValue:[NSNumber numberWithBool:[source getBoolAttribute:@"redirectdrives"]] forKey:@"forwardDisks"];
	[newInstance setValue:[NSNumber numberWithBool:[source getBoolAttribute:@"bitmapcachepersistenable"]] forKey:@"cacheBitmaps"];
	[newInstance setValue:[NSNumber numberWithBool:![source getBoolAttribute:@"disable wallpaper"]] forKey:@"drawDesktop"];
	[newInstance setValue:[NSNumber numberWithBool:![source getBoolAttribute:@"disable full window drag"]] forKey:@"windowDrags"];
	[newInstance setValue:[NSNumber numberWithBool:![source getBoolAttribute:@"disable menu anims"]] forKey:@"windowAnimation"];
	[newInstance setValue:[NSNumber numberWithBool:![source getBoolAttribute:@"disable themes"]] forKey:@"themes"];
	[newInstance setValue:[NSNumber numberWithInt:[source getIntAttribute:@"audiomode"]] forKey:@"forwardAudio"];
	[newInstance setValue:[NSNumber numberWithInt:[source getIntAttribute:@"desktopwidth"]] forKey:@"screenWidth"];
	[newInstance setValue:[NSNumber numberWithInt:[source getIntAttribute:@"desktopheight"]] forKey:@"screenHeight"];
	[newInstance setValue:[NSNumber numberWithInt:[source getIntAttribute:@"session bpp"]] forKey:@"screenDepth"];
	[newInstance setValue:[source label] forKey:@"displayName"];
	[newInstance setValue:[source getStringAttribute:@"username"] forKey:@"username"];
	
	if ( [source getBoolAttribute:@"cord save password"] )
		[newInstance setValue:[source password] forKey:@"password"];
	
	return newInstance;
}

- (void)addServer:(RDPFile *)rdp
{
	if (!rdp || ![rdp attributes]) return;
	NSString *label = ([rdp label]) ? [rdp label] : @"New server";
	
	// Copy into Servers folder by finding a new filename and writing to it
	NSString *newPath = [serversDirectory stringByAppendingPathComponent:
				findAvailableFileName(serversDirectory, label, @".rdp")];
	[rdp setFilename:newPath];
	[rdp writeToFile:newPath];
	[servers addObject:rdp];
	
	[self listUpdated];
}

- (void)buildServersMenu
{
	
	// remove all listed entries
	while ([gui_quickConnectMenu numberOfItems] > 0)
		[gui_quickConnectMenu removeItemAtIndex:0];
	
	// add all current entries
	NSEnumerator *enumerator = [servers objectEnumerator];
	id rdpfile;
	NSMenuItem *menuItem;
	while ((rdpfile = [enumerator nextObject]))
	{
		menuItem = [gui_quickConnectMenu addItemWithTitle:[rdpfile label]
				action:@selector(quickConnectFromMenu:) keyEquivalent:@""];	
		[menuItem setTarget:self];
	}
	
}

- (void)quickConnectFromMenu:(id)sender
{
	// Loop through entries to find the one that matches
	NSEnumerator *enumerator = [servers objectEnumerator];
	id rdpfile;
	while ((rdpfile = [enumerator nextObject]))
	{
		if ([[rdpfile label] isEqualToString:[sender title]])
		{
			if ([rdpfile getBoolAttribute:@"cord save password"])
				[rdpfile setPassword:[self retrievePassword:rdpfile]];
			RDInstance *inst = [self rdInstanceFromRDPFile:rdpfile];
			[appController connectRDInstance:inst];
			return;
		}
	}
}

- (void)showOpen:(id)sender keepServer:(BOOL)keep
{
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setAllowsMultipleSelection:YES];
	//[panel setDelegate:self];
	[panel runModalForTypes:[NSArray arrayWithObject:@"rdp"]];
	NSArray *filenames = [panel filenames];
	if ([filenames count] <= 0) return;
	
	[appController application:[NSApplication sharedApplication] openFiles:filenames];
	
	if (keep)
	{
		NSEnumerator *enumerator = [filenames objectEnumerator];
		NSString *file;
		while ( (file = [enumerator nextObject]) )
			[self addServer:[RDPFile rdpFromFile:file]];			
	}

}

- (void)setConnecting:(BOOL)isConnecting to:(NSString *)connectingTo
{
	currentlyConnecting = !currentlyConnecting;
	
	[self toggleProgressIndicator:currentlyConnecting];
	
	NSString *status = (!connectingTo) ? @"" : [NSString stringWithFormat:@"Connecting to %@", connectingTo];
	[gui_Status setStringValue:status];
}


#pragma mark Private methods
- (void) listUpdated
{	
	[self buildServersMenu];
	[gui_serverList reloadData];
}
- (id) selectedRowLabel
{
	return [self labelForRow:[gui_serverList selectedRow]];
}
- (id) labelForRow:(int)row
{
	return [[self objectForRow:row] label];
}
- (id) selectedObject
{
	return [self objectForRow:[gui_serverList selectedRow]];
}

- (id) objectForRow:(int)row
{
	if (row < 0 || row > [servers count])
		return nil;
	else
		return [servers objectAtIndex:(unsigned)row];
}

- (void)savePassword:(NSString *)password server:(NSString *)server
		user:(NSString *)username
{
	keychain_save_password(safe_string_conv(server), safe_string_conv(username),
			safe_string_conv(password));
}

- (NSString *)retrievePassword:(RDPFile *)rdp
{
	const char * pass = keychain_get_password(
			safe_string_conv([rdp getStringAttribute:@"full address"]), 
			safe_string_conv([rdp getStringAttribute:@"username"]));
	NSString *password= nil;
	if (pass) {
		password = [NSString stringWithCString:pass];
		free((void *)pass);
	}
	return password;
}

- (void)clearPassword:(RDPFile *)rdp
{
	keychain_clear_password(
			safe_string_conv([rdp getStringAttribute:@"full address"]),
			safe_string_conv([rdp getStringAttribute:@"username"]));
}

@end

#pragma mark -
#pragma mark Convenience stubs

/* Note from Dorian: I'm not really sure where these should go, so I put them here. If there's a 
	more suitable place, that's fine.
*/
void ensureDirectoryExists(NSString *path, NSFileManager *manager) {
	BOOL isDir;
	if (![manager fileExistsAtPath:path isDirectory:&isDir])
		[manager createDirectoryAtPath:path attributes:nil];
}

int boolAsButtonState(BOOL value) {
	return (value) ? NSOnState : NSOffState;
}

NSNumber * buttonStateAsNumber(NSButton * button) {
	return [NSNumber numberWithInt:(([button state] == NSOnState) ? 1 : 0)];
}
NSNumber * buttonStateAsNumberInverse(NSButton * button) {
	return [NSNumber numberWithInt:(([button state] == NSOnState) ? 0 : 1)];
}
/* Keeps trying filenames until it finds one that isn't taken.. eg: given "Untitled","rdp", if 
	'Untitled.rdp' is taken, it will try 'Untitled 1.rdp', 'Untitled 2.rdp', etc until one is found,
	then it returns the found filename */
NSString * findAvailableFileName(NSString *path, NSString *base, NSString *extension) {
	NSString *filename = [base stringByAppendingString:extension];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	int i = 0;
	while ([fileManager fileExistsAtPath:[path stringByAppendingPathComponent:filename]] && ++i<100)
		filename = [base stringByAppendingString:[NSString stringWithFormat:@"-%d%@", i, extension]];
		
	return filename;
}

void split_hostname(NSString *address, NSString **host, int *port) {
	NSScanner *scan = [NSScanner scannerWithString:address];
	NSCharacterSet *colonSet = [NSCharacterSet characterSetWithCharactersInString:@":"];
	[scan setCharactersToBeSkipped:colonSet];
	if (![scan scanUpToCharactersFromSet:colonSet intoString:host]) *host = @"";
	if (![scan scanInt:port]) *port = 3389;
}


const char * safe_string_conv(NSString *src) {
	return (src) ? [src UTF8String] : "";
}

NSArray *filter_filenames(NSArray *unfilteredFiles, NSArray *types)
{
	NSMutableArray *returnFiles = [NSMutableArray arrayWithCapacity:4];
	NSEnumerator *fileEnumerator = [unfilteredFiles objectEnumerator];
	int i, typeCount = [types count];
	NSString *filename, *type, *extension, *hfsFileType;	
	while ((filename = [fileEnumerator nextObject]))
	{
		hfsFileType = [NSHFSTypeOfFile(filename) stringByTrimmingCharactersInSet:
					[NSCharacterSet characterSetWithCharactersInString:@" '"]];
		NSLog(@"hfs type is: '%@'", hfsFileType);
		extension = [filename pathExtension];
		for (i = 0; i < typeCount; i++)
		{
			type = [types objectAtIndex:i];
			if ([type caseInsensitiveCompare:extension] == NSOrderedSame ||
				[type caseInsensitiveCompare:hfsFileType] == NSOrderedSame)
			{
				[returnFiles addObject:filename];
			}
		}
	}
	
	return ([returnFiles count] > 0) ? [[returnFiles copy] autorelease] : nil;
}
