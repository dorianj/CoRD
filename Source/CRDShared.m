/*	Copyright (c) 2007 Dorian Johnson <arcadiclife@gmail.com>
	
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

#include "CRDShared.h"

#pragma mark -
#pragma mark Storage for externs

// Constants
const int CRDDefaultPort = 3389;
const int CRDMouseEventLimit = 15;
const NSPoint CRDWindowCascadeStart = {50.0, 20.0};
const float CRDWindowSnapSize = 30.0;
NSString *CRDRowIndexPboardType = @"CRDRowIndexPboardType";

// Globals
AppController *g_appController;

// Notifications
NSString *CRDMinimalViewDidChangeNotification = @"CRDMinimalServerListChanged";

// NSUserDefaults keys
NSString *CRDDefaultsUnifiedDrawerShown = @"show_drawer";
NSString *CRDDefaultsUnifiedDrawerSide = @"preferred_drawer_side";
NSString *CRDDefaultsUnifiedDrawerWidth = @"drawer_width";
NSString *CRDDefaultsDisplayMode = @"windowed_mode";
NSString *CRDDefaultsQuickConnectServers = @"RecentServers";
NSString *CRDDefaultsSendWindowsKey = @"SendWindowsKey";

// User-configurable NSUserDefaults keys (preferences)
NSString *CRDPrefsReconnectIntoFullScreen = @"reconnectFullScreen";
NSString *CRDPrefsReconnectOutOfFullScreen = @"ReconnectWhenLeavingFullScreen";
NSString *CRDPrefsScaleSessions = @"resizeViewToFit";
NSString *CRDPrefsMinimalisticServerList = @"MinimalServerList";
NSString *CRDPrefsIgnoreCustomModifiers = @"IgnoreModifierKeyCustomizations";

#pragma mark -
#pragma mark General purpose routines

void draw_vertical_gradient(NSColor *topColor, NSColor *bottomColor, NSRect rect)
{
	float delta, cur = rect.origin.y, limit = rect.origin.y + rect.size.height;
	while (limit - cur > .01)
	{
		// Interpolate the colors, draw a line for this pixel
		delta = (float)(cur - rect.origin.y) / rect.size.height;
		draw_horizontal_line([topColor blendedColorWithFraction:delta ofColor:bottomColor],
					NSMakePoint(rect.origin.x, cur), rect.size.width);
							
		cur += 1.0;
	}
}

inline void draw_horizontal_line(NSColor *color, NSPoint start, float width)
{
	[color set];
	NSRectFillUsingOperation( NSMakeRect(start.x, start.y, width, 1.0), NSCompositeSourceOver);
}

inline NSString * join_host_name(NSString *host, int port)
{
	if (port && port != CRDDefaultPort)
		return [NSString stringWithFormat:@"%@:%d", host, port];
	else
		return [[host retain] autorelease];
}

void split_hostname(NSString *address, NSString **host, int *port)
{ 
	NSScanner *scan = [NSScanner scannerWithString:address];
	NSCharacterSet *colonSet = [NSCharacterSet characterSetWithCharactersInString:@":"];
	[scan setCharactersToBeSkipped:colonSet];
	
	if (![scan scanUpToCharactersFromSet:colonSet intoString:host])
		*host = @"";
		
	if (![scan scanInt:port])
		*port = CRDDefaultPort;
}

NSString * convert_line_endings(NSString *orig, BOOL withCarriageReturn)
{
	if ([orig length] == 0)
		return @"";
		
	NSMutableString *new = [[orig mutableCopy] autorelease];
	NSString *replace = withCarriageReturn ? @"\n" : @"\r\n",
			 *with = withCarriageReturn ? @"\r\n" : @"\n";
	[new replaceOccurrencesOfString:replace withString:with options:NSLiteralSearch range:NSMakeRange(0, [orig length])];
	return new;
}

inline BOOL drawer_is_visisble(NSDrawer *drawer)
{
	int state = [drawer state];
	return state == NSDrawerOpenState || state == NSDrawerOpeningState;
}

inline const char * safe_string_conv(void *src)
{
	return (src) ? [(NSString *)src UTF8String] : "";
}

inline void ensure_directory_exists(NSString *path)
{
	BOOL isDir;
	if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir])
		[[NSFileManager defaultManager] createDirectoryAtPath:path attributes:nil];
}

// Keeps trying filenames until it finds one that isn't taken.. eg: given "Untitled","rdp", if  'Untitled.rdp' is taken, it will try 'Untitled 1.rdp', 'Untitled 2.rdp', etc until one is found, then it returns the found filename. Useful for duplicating files.
NSString * increment_file_name(NSString *path, NSString *base, NSString *extension)
{
	NSString *filename = [base stringByAppendingString:extension];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	int i = 0;
	while ([fileManager fileExistsAtPath:[path stringByAppendingPathComponent:filename]] && ++i<200)
		filename = [base stringByAppendingString:[NSString stringWithFormat:@" %d%@", i, extension]];
		
	return [path stringByAppendingPathComponent:filename];
}

// Returns the paths in unfilteredFiles whose extention or HFS type match the passed types
NSArray * filter_filenames(NSArray *unfilteredFiles, NSArray *types)
{
	NSMutableArray *returnFiles = [NSMutableArray arrayWithCapacity:4];
	NSEnumerator *fileEnumerator = [unfilteredFiles objectEnumerator];
	int i, typeCount = [types count];
	NSString *filename, *type, *extension, *hfsFileType;	
	while ((filename = [fileEnumerator nextObject]))
	{
		hfsFileType = [NSHFSTypeOfFile(filename) stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" '"]];
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


// Converts a NSArray of NSStrings to an array of C-strings. Everything created is put into the autorelease pool.
char ** convert_string_array(NSArray *stringArray)
{
	int i = 0;
	if ([stringArray count] == 0)
		return NULL;

	NSMutableData *data = [NSMutableData dataWithLength:(sizeof(char *) * [stringArray count])];
	char **cStringPtrArray = (char **)[data mutableBytes];
	
	NSEnumerator *enumerator = [stringArray objectEnumerator];
	id o;
	
	while ( (o = [enumerator nextObject]) )
		cStringPtrArray[i++] = (char *)[[o description] cString];
	
	
	return cStringPtrArray;
}

inline void set_attributed_string_color(NSMutableAttributedString *as, NSColor *color)
{
	[as addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, [as length])];
}

inline void set_attributed_string_font(NSMutableAttributedString *as, NSFont *font)
{
	[as addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, [as length])];
}

inline CRDInputEvent CRDMakeInputEvent(unsigned int time,
	unsigned short type, unsigned short deviceFlags, unsigned short param1, unsigned short param2)
{
	CRDInputEvent ie;
	ie.time = time;
	ie.type = type;
	ie.param1 = param1;
	ie.param2 = param2;
	ie.deviceFlags = deviceFlags;
	return ie;
}


#pragma mark -
#pragma mark AppController specific

NSToolbarItem * create_static_toolbar_item(NSString *name, NSString *label, NSString *tooltip, SEL action)
{
	NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:name] autorelease];
	[item setPaletteLabel:name];
	[item setLabel:label];
	[item setToolTip:tooltip];
	[item setAction:action];
	[item setImage:[NSImage imageNamed:[NSString stringWithFormat:@"%@.png", name]]];
		
	return item;
}


#pragma mark -
#pragma mark CRDSession specific

void fill_default_connection(RDConnectionRef conn)
{
	const char *hostString = [[[NSHost currentHost] name] cStringUsingEncoding:NSASCIIStringEncoding];
	
	conn->tcpPort = CRDDefaultPort;
	conn->screenWidth = 1024;
	conn->screenHeight = 768;
	conn->isConnected = 0;
	conn->useEncryption = 1;
	conn->useBitmapCompression = 1;
	conn->currentStatus = 1;
	conn->useRdp5 = 1;
	conn->serverBpp	= 16;
	conn->consoleSession = 0;
	conn->bitmapCache = 1;
	conn->bitmapCachePersist = 0;
	conn->bitmapCachePrecache = 1;
	conn->polygonEllipseOrders = 1;
	conn->desktopSave = 1;
	conn->serverRdpVersion = 1;
	conn->keyboardLayout = 0x409;
	conn->keyboardType = 4;
	conn->keyboardSubtype = 0;
	conn->keyboardFunctionkeys = 12;
	conn->packetNumber = 0;
	conn->licenseIssued	= 0;
	conn->pstcacheEnumerated = 0;
	conn->ioRequest	= NULL;
	conn->bmpcacheLru[0] = conn->bmpcacheLru[1] = conn->bmpcacheLru[2] = NOT_SET;
	conn->bmpcacheMru[0] = conn->bmpcacheMru[1] = conn->bmpcacheMru[2] = NOT_SET;
	conn->errorCode = 0;
	conn->rdp5PerformanceFlags = RDP5_NO_WALLPAPER | RDP5_NO_FULLWINDOWDRAG | RDP5_NO_MENUANIMATIONS;
	
	conn->rdpdrClientname = malloc(strlen(hostString) + 1);
	strcpy(conn->rdpdrClientname, hostString);
	strncpy(conn->hostname, hostString, 64);
	
	conn->rectsNeedingUpdate = NULL;
	conn->updateEntireScreen = 0;
}

