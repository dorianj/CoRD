/*	Copyright (c) 2006 Craig Dooley <xlnxminusx@gmail.com>
	
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

#import "RDInstance.h"
#import "RDCView.h"
#import "RDCKeyboard.h"
#import "CRDServerCell.h"
#import "keychain.h"

// for sharedDocumentIcon
#import "AppController.h"

// Number of polls per second to check IO
#define NOTIFY_POLL_SPEED 10.0

@interface RDInstance (Private)
	- (void)updateKeychainData:(NSString *)newHost user:(NSString *)newUser password:(NSString *)newPassword force:(BOOL)force;
	- (void)setStatus:(CRDConnectionStatus)status;
	- (void)createScrollEnclosure:(NSRect)frame;
@end

#pragma mark -

@implementation RDInstance

#pragma mark NSObject methods
- (id)init
{
	preferredRowIndex = -1;
	screenDepth = 16;
	themes = cacheBitmaps = YES;
	fileEncoding = NSASCIIStringEncoding;
	
	return [self initWithRDPFile:nil];
}

- (void)dealloc
{
	if (connectionStatus == CRDConnectionConnected)
		[self disconnect];
	
	[label release];
	[hostName release];
	[username release];
	[password release];
	[domain release];
	[otherAttributes release];
	[rdpFilename release];
		
	[cellRepresentation release];
	[super dealloc];
}

- (id)initWithRDPFile:(NSString *)path
{
	if (![super init])
		return nil;
	
	// Use some safe defaults. The docs say it's fine to release a static string (@"").
	label = hostName = username = password = domain = @"";
	temporary = YES;
	[self setStatus:CRDConnectionClosed];
	
	// Other initializations
	otherAttributes = [[NSMutableDictionary alloc] init];
	cellRepresentation = [[CRDServerCell alloc] init];
	
	[cellRepresentation setImage:[AppController sharedDocumentIcon]];
	
	if (path != nil && ![self readRDPFile:path])
	{
		[self autorelease];
		return nil;
	}
	
	return self;
}

- (id)valueForUndefinedKey:(NSString *)key
{
	return [otherAttributes objectForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key
{
	if ([self valueForKey:key] != value)
	{
		modified |= ![key isEqualToString:@"view"];
		[super setValue:value forKey:key];
	}
}


#pragma mark -
#pragma mark Working with rdesktop

// Invoked on incoming data arrival, starts the processing of incoming packets
- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)streamEvent
{
	if (streamEvent == NSStreamEventErrorOccurred)
	{
		[g_appController performSelectorOnMainThread:@selector(disconnectInstance:)
				withObject:self waitUntilDone:NO];
		return;
	}

	uint8 type;
	STREAM s;
	uint32 ext_disc_reason;
	
	if (connectionStatus != CRDConnectionConnected)
		return;
	
	do
	{
		s = rdp_recv(conn, &type);
		if (s == NULL)
		{
			[g_appController performSelectorOnMainThread:@selector(disconnectInstance:)
					withObject:self waitUntilDone:NO];
			return;
		}
		
		switch (type)
		{
			case RDP_PDU_DEMAND_ACTIVE:
				process_demand_active(conn, s);
				break;
			case RDP_PDU_DEACTIVATE:
				DEBUG(("RDP_PDU_DEACTIVATE\n"));
				break;
			case RDP_PDU_DATA:
				if (process_data_pdu(conn, s, &ext_disc_reason))
				{
					[g_appController performSelectorOnMainThread:@selector(disconnectInstance:)
							withObject:self waitUntilDone:NO];
					return;
				}
				break;
			case 0:
				break;
			default:
				unimpl("PDU %d\n", type);
		}
		
	} while ( (conn->nextPacket < s->end) && (connectionStatus == CRDConnectionConnected) );
}

// Using the current properties, attempt to connect to a server. Blocks until timeout or failure.
- (BOOL) connect
{
	if (connectionStatus == CRDConnectionDisconnecting)
	{
		while (connectionStatus == CRDConnectionDisconnecting)
			usleep(1000);
	}
	else if (connectionStatus != CRDConnectionClosed)
		return NO;
		
	free(conn);
	conn = malloc(sizeof(struct rdcConn));
	fill_default_connection(conn);
	conn->controller = self;
	
	// Fail quickly if it's a totally bogus host
	if ([hostName length] < 2)
	{
		conn->errorCode = ConnectionErrorHostResolution;
		return NO;
	}
	
	// Set status to connecting. Do on main thread so that the cell's progress
	//	indicator timer is on the main thread.
	[self performSelectorOnMainThread:@selector(setStatusAsNumber:)
			withObject:[NSNumber numberWithInt:CRDConnectionConnecting] waitUntilDone:NO];
	
	[g_appController performSelectorOnMainThread:@selector(validateControls)
			withObject:nil waitUntilDone:NO];

	// RDP5 performance flags
	int performanceFlags = RDP5_DISABLE_NOTHING;
	if (!windowDrags)
		performanceFlags |= RDP5_NO_FULLWINDOWDRAG;
	
	if (!themes)
		performanceFlags |= RDP5_NO_THEMING;
	
	if (!drawDesktop)
		performanceFlags |= RDP5_NO_WALLPAPER;
	
	if (!windowAnimation)
		performanceFlags |= RDP5_NO_MENUANIMATIONS;
	
	conn->rdp5PerformanceFlags = performanceFlags;
	

	// RDP logon flags
	int logonFlags = RDP_LOGON_NORMAL;
	if ([username length] > 0 && ([password length] > 0 || savePassword))
		logonFlags |= RDP_LOGON_AUTO;
	
	// Other various settings
	conn->bitmapCache = cacheBitmaps;
	conn->serverBpp = (screenDepth==8 || screenDepth==24) ? screenDepth : 16;
	conn->consoleSession = consoleSession;
	conn->screenWidth = screenWidth ? screenWidth : 1024;
	conn->screenHeight = screenHeight ? screenHeight : 768;
	conn->tcpPort = (!port || port>=65536) ? DEFAULT_PORT : port;
	strncpy(conn->username, safe_string_conv(username), sizeof(conn->username));
	
	// Set remote keymap to match local OS X input type
	conn->keyboardLayout = [RDCKeyboard windowsKeymapForMacKeymap:[RDCKeyboard currentKeymapName]];

	// Set up disk redirection
	if (forwardDisks && !DISK_FORWARDING_DISABLED)
	{
		NSArray *localDrives = [[NSWorkspace sharedWorkspace] mountedLocalVolumePaths];
		NSMutableArray *validDrives = [NSMutableArray arrayWithCapacity:5];
		NSMutableArray *validNames = [NSMutableArray arrayWithCapacity:5];
		
		NSFileManager *fm = [NSFileManager defaultManager];
		NSEnumerator *volumeEnumerator = [localDrives objectEnumerator];
		id anObject;
		while ( (anObject = [volumeEnumerator nextObject]) )
		{
			if ([anObject characterAtIndex:0] != '.')
			{
				[validDrives addObject:anObject];
				[validNames addObject:[fm displayNameAtPath:anObject]];
			}
		}
		
		disk_enum_devices(conn, convert_string_array(validDrives),
						  convert_string_array(validNames), [validDrives count]);
	}
	
	rdpdr_init(conn);
	
	cliprdr_init(conn);
	
	// Make the connection
	BOOL connected = rdp_connect(conn, safe_string_conv(hostName), 
							logonFlags, 
							safe_string_conv(domain), 
							safe_string_conv(password), 
							"",  /* xxx: command on logon */
							"" /* xxx: session directory*/ );
							
	// Upon success, set up the input socket
	if (connected)
	{
		[self setStatus:CRDConnectionConnected];
		
		inputRunLoop = [NSRunLoop currentRunLoop];
	
		NSStream *is = conn->inputStream;
		[is setDelegate:self];
		[is scheduleInRunLoop:inputRunLoop forMode:NSDefaultRunLoopMode];
		
		view = [[RDCView alloc] initWithFrame:NSMakeRect(0.0, 0.0, conn->screenWidth, conn->screenHeight)];
		[view setController:self];
		[view performSelectorOnMainThread:@selector(setNeedsDisplay:)
							   withObject:[NSNumber numberWithBool:YES]
							waitUntilDone:NO];
		conn->ui = view;
	}
	else
	{	
		[self setStatus:CRDConnectionClosed];
	}
	
	return connected;
}

- (void) disconnect
{
	[self retain];
	[self disconnectAsync:[NSNumber numberWithBool:NO]];
}

- (void) disconnectAsync:(NSNumber *)block
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self setStatus:CRDConnectionDisconnecting];
	if (inputLoopFinished || [block boolValue])
	{
		while (!inputLoopFinished)
			usleep(1000);
		
		// Low level removal
		tcp_disconnect(conn);
		
		// UI cleanup
		[window close];
		[window release];
		window = nil;
		[tabViewRepresentation release];
		tabViewRepresentation = nil;	
		[scrollEnclosure release];
		scrollEnclosure = nil;
		[view release];
		view = nil;
		
		// Clear out the bitmap cache
		int i, k;
		for (i = 0; i < NBITMAPCACHE; i++)
		{
			for (k = 0; k < NBITMAPCACHEENTRIES; k++)
			{	
				ui_destroy_bitmap(conn->bmpcache[i][k].bitmap);
				conn->bmpcache[i][k].bitmap = NULL;
			}
		}
		
		memset(conn, 0, sizeof(struct rdcConn));
		free(conn);
		conn = NULL;
		[self setStatus:CRDConnectionClosed];
	}
	else
	{
		[self retain];
		[NSThread detachNewThreadSelector:@selector(disconnectAsync:) toTarget:self
					withObject:[NSNumber numberWithBool:YES]];	
	}
	
	[pool release];
	[self release];
}

- (void) sendInput:(uint16) type flags:(uint16)flags param1:(uint16)param1 param2:(uint16)param2
{
	if (connectionStatus == CRDConnectionConnected)
		rdp_send_input(conn, time(NULL), type, flags, param1, param2);
}

- (void)pollDiskNotifyRequests:(NSTimer *)timer
{
	if (connectionStatus != CRDConnectionConnected)
	{
		[timer invalidate];
		return;
	}
	
	ui_select(conn);
}

#pragma mark -
#pragma mark Working with the input run loop
- (void)startInputRunLoop
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	inputLoopFinished = NO;
	
	if (forwardDisks && !DISK_FORWARDING_DISABLED)
	{
		[NSTimer scheduledTimerWithTimeInterval:(1.0/NOTIFY_POLL_SPEED) target:self
					selector:@selector(pollDiskNotifyRequests:) userInfo:nil repeats:YES];
	}
	
	BOOL gotInput;
	unsigned x = 0;
	do
	{
		if (x++ % 10 == 0)
		{
			[pool release];
			pool = [[NSAutoreleasePool alloc] init];
		}
		gotInput = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode 
					beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
	} while (connectionStatus == CRDConnectionConnected && gotInput);
	
	if (conn != NULL)
		[(id)conn->inputStream removeFromRunLoop:inputRunLoop forMode:NSDefaultRunLoopMode];
	
	
	inputLoopFinished = YES;
	
	[pool release];
}


#pragma mark - 
#pragma mark Clipboard synchronization

- (void)announceNewClipboardData
{
	cliprdr_send_simple_native_format_announce(conn, CF_UNICODETEXT);
}

// Assures that the remote clipboard is the same as the passed pasteboard, sending new
//	clipboard as needed
- (void)setRemoteClipboard:(int)suggestedFormat
{
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	if ([pb availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]])
	{
		NSString *pasteContent = convert_line_endings([pb stringForType:NSStringPboardType], YES);
		
		if (![remoteClipboardContents isEqualToString:pasteContent])
		{
			NSData *unicodePasteContent = [pasteContent dataUsingEncoding:NSUnicodeStringEncoding allowLossyConversion:YES];
			
			if ([unicodePasteContent length] > 0)
			{
				cliprdr_send_data(conn, (unsigned char *)[unicodePasteContent bytes] + 2 /* skip endianess marker */,
						[unicodePasteContent length]);
				
				[remoteClipboardContents release];
				remoteClipboardContents = [pasteContent retain];
			}
		}
	}
}

- (void)requestRemoteClipboardData
{
	conn->clipboardRequestType = CF_UNICODETEXT;
	cliprdr_send_data_request(conn, CF_UNICODETEXT);
}

// Sets the local clipboard to match the server provided data
- (void)setLocalClipboard:(NSData *)data format:(int)format
{
	if ( ((format != CF_UNICODETEXT) && (format != CF_AUTODETECT)) || ([data length] == 0) )
		return;
	
	NSMutableData *rawClipboardData = [[NSMutableData alloc] initWithCapacity:[data length]];
	
	unsigned char endiannessMarker[] = {0xFF, 0xFE};
	[rawClipboardData appendBytes:endiannessMarker length:2];
	[rawClipboardData appendBytes:[data bytes] length:[data length]-2];
	
	NSPasteboard *pb = [NSPasteboard generalPasteboard];
	[pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	
	NSString *temp = [[NSString alloc] initWithData:rawClipboardData encoding:NSUnicodeStringEncoding];
	
	[rawClipboardData release];
	
	NSString *remoteStr = convert_line_endings(temp, NO);

	[remoteClipboardContents release];
	remoteClipboardContents = [remoteStr retain];
	
	[pb setString:remoteStr forType:NSStringPboardType];	
}


#pragma mark -
#pragma mark Working with the represented file

// This probably isn't safe to call from anywhere other than initWith.. in its current form
- (BOOL) readRDPFile:(NSString *)path
{
	if (path == nil || ![[NSFileManager defaultManager] isReadableFileAtPath:path])
		return NO;

	NSString *fileContents = [NSString stringWithContentsOfFile:path usedEncoding:&fileEncoding error:NULL];
			
	if (!fileContents)
		fileContents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
	
	NSArray *fileLines = [fileContents componentsSeparatedByString:@"\r\n"];

	if (fileLines == nil)
	{
		NSLog(@"Couldn't open RDP file '%@'!", path);
		return NO;
	}
		
	[self setRdpFilename:path];
		
	NSScanner *scan;
	NSCharacterSet *colonSet = [NSCharacterSet characterSetWithCharactersInString:@":"],
				   *emptySet = [NSCharacterSet characterSetWithCharactersInString:@""];
				   
	NSString *name, *type, *value;
	int numVal = 0;
	BOOL b;
	
	// Loop through each line, extracting the name, type, and value
	NSEnumerator *enumerator = [fileLines objectEnumerator];
	id line;
	while ( (line = [enumerator nextObject]) )
	{
		scan = [NSScanner scannerWithString:line];
		[scan setCharactersToBeSkipped:colonSet];
		
		b = YES;
		b &= [scan scanUpToCharactersFromSet:colonSet intoString:&name];
		b &= [scan scanUpToCharactersFromSet:colonSet intoString:&type];
		
		if (![scan scanUpToCharactersFromSet:emptySet intoString:&value])
			value = @"";
		
		// This doesn't use key-value coding because none of the side effects
		//	in the setters are desirable at load time
		
		if (b)
		{
			if ([type isEqualToString:@"i"])
				numVal = [value intValue];
			
			if ([name isEqualToString:@"connect to console"])
				consoleSession = numVal;
			else if ([name isEqualToString:@"bitmapcachepersistenable"]) 
				cacheBitmaps = numVal;
			else if ([name isEqualToString:@"redirectdrives"])
				forwardDisks = numVal;
			else if ([name isEqualToString:@"disable wallpaper"])
				drawDesktop = !numVal;
			else if ([name isEqualToString:@"disable full window drag"])
				windowDrags = !numVal;
			else if ([name isEqualToString:@"disable menu anims"])
				windowAnimation = !numVal;
			else if ([name isEqualToString:@"disable themes"])
				themes = !numVal;
			else if ([name isEqualToString:@"audiomode"])
				forwardAudio = numVal;
			else if ([name isEqualToString:@"desktopwidth"]) 
				screenWidth = numVal;
			else if ([name isEqualToString:@"desktopheight"]) 
				screenHeight = numVal;
			else if ([name isEqualToString:@"session bpp"]) 
				screenDepth = numVal;
			else if ([name isEqualToString:@"username"])
				username = [value retain];
			else if ([name isEqualToString:@"cord save password"]) 
				savePassword = numVal;
			else if ([name isEqualToString:@"domain"])
				domain = [value retain];
			else if ([name isEqualToString:@"startdisplay"])
				startDisplay = numVal;
			else if ([name isEqualToString:@"cord label"])
				label = [value retain];			
			else if ([name isEqualToString:@"cord row index"])
				preferredRowIndex = numVal;
			else if ([name isEqualToString:@"full address"]) {
				split_hostname(value, &hostName, &port);
				[hostName retain];
			}
			else if ([name isEqualToString:@"cord fullscreen"]) {
				fullscreen = numVal;
			}
			else
			{
				if ([type isEqualToString:@"i"])
					[otherAttributes setObject:[NSNumber numberWithInt:numVal] forKey:name];
				else
					[otherAttributes setObject:value forKey:name];				
			}
		}		
	}
		
	modified = NO;
	[self setTemporary:NO];
	
	if (savePassword)
	{
		const char *pass = keychain_get_password([hostName UTF8String], [username UTF8String]);
		if (pass != NULL)
		{
			password = [[NSString stringWithUTF8String:pass] retain];
			free((void*)pass);
		}
	}
	
	[self updateCellData];
	
	return YES;
}

// Saves all of the current settings to a Microsoft RDC client compatible file
- (BOOL) writeRDPFile:(NSString *)path
{
	#define write_int(n, v)	 [o appendString:[NSString stringWithFormat:@"%@:i:%d\r\n", (n), (v)]]
	#define write_string(n, v) [o appendString:[NSString stringWithFormat:@"%@:s:%@\r\n", (n), (v) ? (v) : @""]]
	
	if (path == nil && (path = [self rdpFilename]) == nil)
		return nil;

	NSMutableString *o = [[NSMutableString alloc] init];
	
	write_int(@"connect to console", consoleSession);
	write_int(@"bitmapcachepersistenable", cacheBitmaps);
	write_int(@"redirectdrives", forwardDisks);
	write_int(@"disable wallpaper", !drawDesktop);
	write_int(@"disable full window drag", !windowDrags);
	write_int(@"disable menu anims", !windowAnimation);
	write_int(@"disable themes", !themes);
	write_int(@"audiomode", forwardAudio);
	write_int(@"desktopwidth", screenWidth);
	write_int(@"desktopheight", screenHeight);
	write_int(@"session bpp", screenDepth);
	write_int(@"cord save password", savePassword);
	write_int(@"startdisplay", startDisplay);
	write_int(@"cord fullscreen", fullscreen);
	write_int(@"cord row index", preferredRowIndex);
	
	write_string(@"full address", full_host_name(hostName, port));
	write_string(@"username", username);
	write_string(@"domain", domain);
	write_string(@"cord label", label);
	
	// Write all entries in otherAttributes
	NSEnumerator *enumerator = [otherAttributes keyEnumerator];
	id key, value;
	while ( (key = [enumerator nextObject]) && (value = [otherAttributes valueForKey:key]) )
	{
		if ([value isKindOfClass:[NSNumber class]])
			write_int(key, [value intValue]);
		else
			write_string(key, value);	
	}
	
	BOOL success = [o writeToFile:path atomically:YES encoding:fileEncoding error:NULL];
	
	if (!success)
		success = [o writeToFile:path atomically:YES encoding:(fileEncoding = NSUTF8StringEncoding) error:NULL];

	if (!success)
		NSLog(@"Error writing to '%@'", path);
	else
	{
		NSDictionary *newAttrs = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:'RDP ']
					forKey:NSFileHFSTypeCode];
		[[NSFileManager defaultManager] changeFileAttributes:newAttrs atPath:path];
	}
	
	[o release];

	modified = NO;
	
	return success;
	
	#undef write_int(n, v)
	#undef write_string(n, v)
}


#pragma mark -
#pragma mark Working with GUI

// Updates the CRDServerCell this instance manages to match the current details.
- (void)updateCellData
{
	// Update the text
	NSString *fullHost = (port && port != DEFAULT_PORT) ? [NSString stringWithFormat:@"%@:%d", hostName, port] : hostName;
	[cellRepresentation setDisplayedText:label username:username address:fullHost];
	
	// Update the image
	NSImage *base = [AppController sharedDocumentIcon];
	NSImage *icon = [[[NSImage alloc] initWithSize:NSMakeSize(CELL_IMAGE_WIDTH, CELL_IMAGE_HEIGHT)] autorelease];

	[icon lockFocus]; {
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
		[base drawInRect:RECT_FROM_SIZE([icon size]) fromRect:RECT_FROM_SIZE([base size]) operation:NSCompositeSourceOver fraction:1.0];	
	} [icon unlockFocus];
	
	
	// If this is temporary, badge the lower right corner of the image
	if ([self temporary])
	{
		[icon lockFocus]; {
		
			NSImage *clockIcon = [NSImage imageNamed:@"Clock icon.png"];
			NSSize clockSize = [clockIcon size], iconSize = [icon size];
			NSRect src = NSMakeRect(0.0, 0.0, clockSize.width, clockSize.height);
			NSRect dest = NSMakeRect(iconSize.width - clockSize.width - 1.0, iconSize.height - clockSize.height, clockSize.width, clockSize.height);
			[clockIcon drawInRect:dest fromRect:src operation:NSCompositeSourceOver fraction:0.9];
			
		} [icon unlockFocus];
	}
	
	[cellRepresentation setImage:icon];
			
}

- (void)createWindow:(BOOL)useScrollView
{
	[window release];
	NSRect sessionScreenSize = [view bounds];
	window = [[NSWindow alloc] initWithContentRect:sessionScreenSize
			styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask)
			backing:NSBackingStoreBuffered defer:NO];
	
	[window setContentMaxSize:sessionScreenSize.size];
	[window setTitle:label];
	[window setAcceptsMouseMovedEvents:YES];
	[window setDelegate:self];
	[window setReleasedWhenClosed:NO];
	[[window contentView] setAutoresizesSubviews:YES];
	[window setContentMinSize:NSMakeSize(100.0, 75.0)];
	
	[view setFrameOrigin:NSZeroPoint];
	[view removeFromSuperview];
	
	if (useScrollView)
	{
		[self createScrollEnclosure:[[window contentView] bounds]];
		[[window contentView] addSubview:scrollEnclosure];
	}
	else
	{
		[view setFrameSize:[[window contentView] frame].size];
		[view setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
		[window setContentAspectRatio:sessionScreenSize.size];	
		[[window contentView] addSubview:view];
		[view setNeedsDisplay:YES];
	}
	
	[window makeFirstResponder:view];
	[window display];
}


- (void)createUnified:(BOOL)useScrollView enclosure:(NSRect)enclosure
{	
	[tabViewRepresentation release];
	tabViewRepresentation = [[NSTabViewItem alloc] initWithIdentifier:label];
	[tabViewRepresentation setLabel:label];	
	
	if (useScrollView)
	{
		[self createScrollEnclosure:enclosure];
		[tabViewRepresentation setView:scrollEnclosure];
	}
	else
	{
		[view setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
		[tabViewRepresentation setView:view];
	}	
}

- (void)destroyUnified
{
	[tabViewRepresentation release];
	tabViewRepresentation = nil;
}

- (void)destroyWindow
{
	[window setDelegate:nil];
	[window close];
	window = nil;
}


- (void)createScrollEnclosure:(NSRect)frame
{
	[scrollEnclosure release];
	scrollEnclosure = [[NSScrollView alloc] initWithFrame:frame];
	[view setAutoresizingMask:NSViewNotSizable];
	[scrollEnclosure setAutoresizingMask:(NSViewMinXMargin|NSViewMaxXMargin|NSViewMinYMargin|
				NSViewMaxYMargin|NSViewWidthSizable|NSViewHeightSizable)];
	[scrollEnclosure setDocumentView:view];
	[scrollEnclosure setHasVerticalScroller:YES];
	[scrollEnclosure setHasHorizontalScroller:YES];
	[scrollEnclosure setAutohidesScrollers:YES];
	[scrollEnclosure setBorderType:NSNoBorder];
	[scrollEnclosure setDrawsBackground:NO];
}


#pragma mark -
#pragma mark NSWindow delegate

- (void)windowWillClose:(NSNotification *)aNotification
{
	if (connectionStatus == CRDConnectionConnected)
		[g_appController disconnectInstance:self];
}

- (void)windowDidBecomeKey:(NSNotification *)sender
{
	if ([sender object] == window)
	{
		[self announceNewClipboardData];
	}
}

- (void)windowDidResignKey:(NSNotification *)sender
{
	if ([sender object] == window)
	{
		[self requestRemoteClipboardData];
	}
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
	NSSize realSize = [view bounds].size;
	realSize.height += [sender frame].size.height - [[sender contentView] frame].size.height;
	
	if (realSize.width-proposedFrameSize.width <= SNAP_WINDOW_SIZE &&
		realSize.height-proposedFrameSize.height <= SNAP_WINDOW_SIZE)
	{
		return realSize;	
	}
		
	return proposedFrameSize;
}


#pragma mark -
#pragma mark Working With CoRD

- (void)cancelConnection
{
	if ( (connectionStatus != CRDConnectionConnecting) || (conn == NULL))
		return;
	
	conn->errorCode = ConnectionErrorCanceled;
}

- (NSComparisonResult)compareUsingPreferredOrder:(id)compareTo
{
	int otherOrder = [[compareTo valueForKey:@"preferredRowIndex"] intValue];
	
	if (preferredRowIndex == otherOrder)
		return [[compareTo label] compare:label];
	else
		return (preferredRowIndex - otherOrder > 0) ? NSOrderedDescending : NSOrderedAscending;
}


#pragma mark -
#pragma mark Keychain

// Force makes it save data to keychain regardless if it has changed. savePassword  is always respected.
- (void)updateKeychainData:(NSString *)newHost user:(NSString *)newUser password:(NSString *)newPassword force:(BOOL)force
{
	if (savePassword && (force || ![hostName isEqualToString:newHost] || 
		![username isEqualToString:newUser] || ![password isEqualToString:newPassword]) )
	{
		keychain_update_password([hostName UTF8String], [username UTF8String],
				[newHost UTF8String], [newUser UTF8String], [newPassword UTF8String]);
	}
}

- (void)clearKeychainData
{
	keychain_clear_password([hostName UTF8String], [username UTF8String]);
}


#pragma mark -
#pragma mark Accessors
- (rdcConnection)conn
{
	return conn;
}

- (NSString *)label
{
	return label;
}

- (RDCView *)view
{
	return view;
}

- (NSString *)rdpFilename
{
	return rdpFilename;
}

- (void)setRdpFilename:(NSString *)path
{
	[path retain];
	[rdpFilename release];
	rdpFilename = path;
}

- (BOOL)temporary
{
	return temporary;
}

- (void)setTemporary:(BOOL)temp
{
	temporary = temp;
	[self updateCellData];
}

- (CRDServerCell *)cellRepresentation
{
	return cellRepresentation;
}

- (NSTabViewItem *)tabViewRepresentation
{
	return tabViewRepresentation;
}

- (BOOL)modified
{
	return modified;
}

- (CRDConnectionStatus)status
{
	return connectionStatus;
}

- (NSWindow *)window
{
	return window;
}

- (void)setStatus:(CRDConnectionStatus)status
{
	[cellRepresentation setStatus:status];
	connectionStatus = status;
}

// Status needs to be set on the main thread when setting it to Connecting
//	so the the CRDServerCell will create its progress indicator timer in the main run loop
- (void)setStatusAsNumber:(NSNumber *)status
{
	[self setStatus:[status intValue]];
}


/* Do a few simple setters that would otherwise be caught by key-value coding so that
	updateCellData can be called and keychain data can be updated. Keychain data
	must be done here and not at save time because the keychain item might already 
	exist so it has to be edited.
*/
- (void)setLabel:(NSString *)s
{
	[label autorelease];
	label = [s retain];
	[self updateCellData];
}

- (void)setHostName:(NSString *)s
{
	[self updateKeychainData:s user:username password:password force:NO];
	[hostName autorelease];
	hostName = [s retain];
	[self updateCellData];
}

- (void)setUsername:(NSString *)s
{
	[username autorelease];
	username = [s retain];
	[self updateCellData];
}

- (void)setPassword:(NSString *)pass
{
	[self updateKeychainData:hostName user:username password:pass force:NO];
	[password autorelease];
	password = [pass retain];
}

- (void)setPort:(int)newPort
{
	port = newPort;
	[self updateCellData];
}

- (void)setSavePassword:(BOOL)saves
{
	savePassword = saves;
	
	if (!savePassword)	
		[self clearKeychainData];
	else
		[self updateKeychainData:hostName user:username password:password force:YES];
}

@end


