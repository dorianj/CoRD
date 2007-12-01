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

#include "miscellany.h"

#pragma mark -
#pragma mark General purpose
const char *safe_string_conv(void *src)
{
	return (src) ? [(NSString *)src UTF8String] : "";
}

// Must be called with a view focused
void draw_vertical_gradient(NSColor *topColor, NSColor *bottomColor, NSRect rect)
{
	float delta, cur = rect.origin.y, limit = rect.origin.y + rect.size.height;
	while (limit - cur > .01)
	{
		// Interpolate the colors, draw a line for this pixel
		delta = (float)(cur - rect.origin.y) / rect.size.height;
		draw_line([topColor blendedColorWithFraction:delta ofColor:bottomColor],
					NSMakePoint(rect.origin.x, cur),
					NSMakePoint(rect.origin.x + rect.size.width, cur));
							
		cur += 1.0;
	}
}

// Must be called with a view focused. Note that this is optimized for drawing horizontal lines
void draw_line(NSColor *color, NSPoint start, NSPoint end)
{
	[color set];
	
	// Make sure the stroke is centered on the pixel so we get a clean line
	start.y = (int)start.y + 0.5;
	end.y = (int)end.y + 0.5;

	[NSBezierPath strokeLineFromPoint:start toPoint:end];
}

NSString *full_host_name(NSString *host, int port)
{
	if (port && port != DEFAULT_PORT)
		return [NSString stringWithFormat:@"%@:%d", host, port];
	else
		return [[host retain] autorelease];
}

void print_bitfield(unsigned v, int bits)
{
	int i;
	for (i = sizeof(int) - (sizeof(int)-bits)-1; i >= 0; i--)
	{
		printf("%u", (v >> i) & 1);
		if (i % 4 == 0)
			printf(" ");
	}
	printf("\n");
}

NSString *convert_line_endings(NSString *orig, BOOL withCarriageReturn)
{
	if ([orig length] == 0)
		return nil;
		
	NSMutableString *new = [[orig mutableCopy] autorelease];
	NSString *replace = withCarriageReturn ? @"\n" : @"\r\n",
			 *with = withCarriageReturn ? @"\r\n" : @"\n";
	[new replaceOccurrencesOfString:replace withString:with options:NSLiteralSearch range:NSMakeRange(0, [orig length])];
	return new;
}


#pragma mark -
#pragma mark AppController
NSToolbarItem *create_static_toolbar_item(NSString *name, NSString *label, NSString *tooltip, SEL action)
{
	NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:name] autorelease];
	[item setPaletteLabel:name];
	[item setLabel:label];
	[item setToolTip:tooltip];
	[item setAction:action];
	[item setImage:[NSImage imageNamed:[NSString stringWithFormat:@"%@.png", name]]];
		
	return item;
}

BOOL drawer_is_visisble(NSDrawer *drawer)
{
	int state = [drawer state];
	return state == NSDrawerOpenState || state == NSDrawerOpeningState;
}


#pragma mark -
#pragma mark ServersManager
void ensure_directory_exists(NSString *path, NSFileManager *manager)
{
	BOOL isDir;
	if (![manager fileExistsAtPath:path isDirectory:&isDir])
		[manager createDirectoryAtPath:path attributes:nil];
}

/* Keeps trying filenames until it finds one that isn't taken.. eg: given "Untitled","rdp", if 
	'Untitled.rdp' is taken, it will try 'Untitled 1.rdp', 'Untitled 2.rdp', etc until one is found,
	then it returns the found filename. Useful for duplicating files. */
NSString *increment_file_name(NSString *path, NSString *base, NSString *extension)
{
	NSString *filename = [base stringByAppendingString:extension];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	int i = 0;
	while ([fileManager fileExistsAtPath:[path stringByAppendingPathComponent:filename]] && ++i<100)
		filename = [base stringByAppendingString:[NSString stringWithFormat:@" %d%@", i, extension]];
		
	return [path stringByAppendingPathComponent:filename];
}

void split_hostname(NSString *address, NSString **host, int *port)
{ 
	NSScanner *scan = [NSScanner scannerWithString:address];
	NSCharacterSet *colonSet = [NSCharacterSet characterSetWithCharactersInString:@":"];
	[scan setCharactersToBeSkipped:colonSet];
	
	if (![scan scanUpToCharactersFromSet:colonSet intoString:host])
		*host = @"";
	if (![scan scanInt:port])
		*port = DEFAULT_PORT;
}

// Returns the paths in unfilteredFiles that are one of types. Extention and 
//	HFS file type are checked.
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

#pragma mark -
#pragma mark RDInstance

// Converts a NSArray of strings to an array of C strings. You are responsible to 
//	free the returned array of pointers (but not the data themselves).
char **convert_string_array(NSArray *conv)
{
	int count, i = 0;
	if (conv != nil && (count = [conv count]) > 0)
	{
		char **strings = malloc(sizeof(char *) * count);
		NSEnumerator *enumerator = [conv objectEnumerator];
		id o;
		while ( (o = [enumerator nextObject]) )
			strings[i++] = (char *)[[o description] UTF8String];
		return strings;
	}
	
	return NULL;
}

void fill_default_connection(rdcConnection conn)
{
	NSString *host = [[NSHost currentHost] name];
	conn->tcpPort		= TCP_PORT_RDP;
	conn->screenWidth	= 1024;
	conn->screenHeight	= 768;
	conn->isConnected	= 0;
	conn->useEncryption	= 1;
	conn->useBitmapCompression	= 1;
	conn->currentStatus = 1;
	conn->useRdp5		= 1;
	conn->serverBpp		= 16;
	conn->consoleSession	= 0;
	conn->bitmapCache	= 1;
	conn->bitmapCachePersist	= 0;
	conn->bitmapCachePrecache	= 1;
	conn->polygonEllipseOrders	= 1;
	conn->desktopSave	= 1;
	conn->serverRdpVersion	= 1;
	conn->keyboardLayout		= 0x409;
	conn->packetNumber	= 0;
	conn->licenseIssued	= 0;
	conn->pstcacheEnumerated	= 0;
	conn->rdpdrClientname	= NULL; // xxx: need to set to hostname?
	conn->ioRequest	= NULL;
	conn->bmpcacheLru[0] = conn->bmpcacheLru[1] = conn->bmpcacheLru[2] = NOT_SET;
	conn->bmpcacheMru[0] = conn->bmpcacheMru[1] = conn->bmpcacheMru[2] = NOT_SET;
	conn->errorCode = 0;
	memcpy(conn->hostname, [host UTF8String], [host length] + 1);
	conn->rdp5PerformanceFlags	= RDP5_NO_WALLPAPER | RDP5_NO_FULLWINDOWDRAG | RDP5_NO_MENUANIMATIONS;
	conn->rectsNeedingUpdate = NULL;
	conn->updateEntireScreen = 0;
}

