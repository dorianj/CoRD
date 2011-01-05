/*	Copyright (c) 2007-2011 Dorian Johnson <2011@dorianj.net>
	
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
#include <unistd.h>


#pragma mark -
#pragma mark Storage for externs

// Constants
const NSInteger CRDDefaultPort = 3389;
const NSInteger CRDDefaultScreenWidth = 1024;
const NSInteger CRDDefaultScreenHeight = 640;
const NSInteger CRDDefaultFrameWidth = 600;
const NSInteger CRDDefaultFrameHeight = 400;
const NSInteger CRDMouseEventLimit = 20;
const NSInteger CRDInspectorMaxWidth = 500;
const NSInteger CRDForwardAudio = 0;
const NSInteger CRDLeaveAudio = 1;
const NSInteger CRDDisableAudio = 2;
const NSPoint CRDWindowCascadeStart = {50.0, 20.0};
const float CRDWindowSnapSize = 30.0;
NSString * const CRDRowIndexPboardType = @"CRDRowIndexPboardType";

// URLs for Support & Logistics
NSString * const CRDTracURL = @"http://sourceforge.net/apps/trac/cord/";
NSString * const CRDHomePageURL = @"http://cord.sourceforge.net";
NSString * const CRDSupportForumsURL = @"http://sourceforge.net/apps/phpbb/cord/";

// Globals
AppController *g_appController;

// Notifications
NSString * const CRDMinimalViewDidChangeNotification = @"CRDMinimalServerListChanged";

// NSUserDefaults keys
NSString * const CRDDefaultsUnifiedDrawerShown = @"show_drawer";
NSString * const CRDDefaultsUnifiedDrawerSide = @"preferred_drawer_side";
NSString * const CRDDefaultsUnifiedDrawerWidth = @"drawer_width";
NSString * const CRDDefaultsDisplayMode = @"windowed_mode";
NSString * const CRDDefaultsQuickConnectServers = @"RecentServers";
NSString * const CRDDefaultsSendWindowsKey = @"SendWindowsKey";


// User-configurable NSUserDefaults keys (preferences)
NSString * const CRDPrefsReconnectIntoFullScreen = @"reconnectFullScreen";
NSString * const CRDPrefsReconnectOutOfFullScreen = @"ReconnectWhenLeavingFullScreen";
NSString * const CRDPrefsScaleSessions = @"resizeViewToFit";
NSString * const CRDPrefsMinimalisticServerList = @"MinimalServerList";
NSString * const CRDPrefsIgnoreCustomModifiers = @"IgnoreModifierKeyCustomizations";
NSString * const CRDSetServerKeyboardLayout = @"SetServerKeyboardLayout";
NSString * const CRDForwardOnlyDefinedPaths = @"CRDForwardOnlyDefinedPaths";
NSString * const CRDUseSocksProxy = @"CRDUseSocksProxy";
NSString * const CRDDisableCrashReporter = @"disableCrashReporter";

#pragma mark -
#pragma mark General purpose routines

inline NSString * CRDJoinHostNameAndPort(NSString *host, NSInteger port)
{
	return (port && port != CRDDefaultPort) ? [NSString stringWithFormat:@"%@:%d", host, port] : [[host copy] autorelease];
}

void CRDSplitHostNameAndPort(NSString *address, NSString **host, NSInteger *port)
{ 
	if ([address characterAtIndex:[address length] - 1] == ']' && [address characterAtIndex:0] == '[')
	{
		address = [address substringWithRange:NSMakeRange(1, [address length] - 2)];
		*host = address;
		*port = CRDDefaultPort;
	}
	else
	{
		NSScanner *scan = [NSScanner scannerWithString:address];
		NSCharacterSet *colonSet = [NSCharacterSet characterSetWithCharactersInString:@":"];
		[scan setCharactersToBeSkipped:colonSet];
		
		if (![scan scanUpToCharactersFromSet:colonSet intoString:host])
			*host = @"";
			
		if (![scan scanInteger:port])
			*port = CRDDefaultPort;
	}
}

BOOL CRDResolutionStringIsFullscreen(NSString *screenResolution)
{
	screenResolution = [[screenResolution strip] lowercaseString];
		
	for (NSString *match in [NSArray arrayWithObjects:@"full screen", @"fullscreen", nil])
		if ([screenResolution isEqualToString:match])
			return YES;
		
	return NO;
}

void CRDSplitResolutionString(NSString *screenResolution, NSInteger *width, NSInteger *height)
{
	if (![screenResolution length])
	{
		*width = CRDDefaultScreenWidth;
		*height = CRDDefaultScreenHeight;

		return;
	}
	NSScanner *scan = [NSScanner scannerWithString:screenResolution];
	NSCharacterSet *separatorSet = [NSCharacterSet characterSetWithCharactersInString:@"x:*"];
	[scan setCharactersToBeSkipped:separatorSet];
	
	if (![scan scanInteger:width])
		*width = CRDDefaultScreenWidth;
	
	if (![scan scanInteger:height])
		*height = CRDDefaultScreenHeight;
}

NSNumber * CRDNumberForColorsText(NSString *colorsText)
{
	// This should be localized. It's being used to translate displayed values.
	
	colorsText = [colorsText lowercaseString];
	
	if ([colorsText isLike:@"*256*"])
		return [NSNumber numberWithInt:8];
	
	if ([colorsText isLike:@"*thousand*"])
		return [NSNumber numberWithInt:16];
	
	if ([colorsText isLike:@"*million*"])
		return [NSNumber numberWithInt:24];
	
	return [NSNumber numberWithInt:16];
}

inline unsigned int CRDRoundUpToEven(float n)
{
	unsigned int i = n + 0.5;
	return i % 2 ? i + 1 : i;
}

NSString * CRDConvertLineEndings(NSString *orig, BOOL withCarriageReturn)
{
	if (![orig length])
		return @"";
		
	NSMutableString *new = [[orig mutableCopy] autorelease];
	NSString *replace = withCarriageReturn ? @"\n" : @"\r\n", *with = withCarriageReturn ? @"\r\n" : @"\n";
	[new replaceOccurrencesOfString:replace withString:with options:NSLiteralSearch range:NSMakeRange(0, [orig length])];
	return new;
}

inline BOOL CRDDrawerIsVisible(NSDrawer *drawer)
{
	return ([drawer state] == NSDrawerOpenState) || ([drawer state] == NSDrawerOpeningState);
}

inline const char * CRDMakeWindowsString(NSString *str)
{
	/* returns a best effort conversion to Windows CP1250 */
	return str ? (const char *)[[str dataUsingEncoding:NSWindowsCP1250StringEncoding allowLossyConversion:YES] bytes] : "";
}

inline const char * CRDMakeUTF16LEString(NSString *str)
{
	/* returns a best effort conversion to UTF-16 Little Endian */
	return str ? (const char *)[[str dataUsingEncoding:NSUTF16LittleEndianStringEncoding allowLossyConversion:YES] bytes] : "";
}

inline int CRDGetUTF16LEStringLength(NSString *str)
{
	/* TODO: what happens on lossy conversion in CRDMakeUTF16LEString? */
	return str ? [str lengthOfBytesUsingEncoding:NSUTF16LittleEndianStringEncoding] : 0;
}

inline void CRDCreateDirectory(NSString *path)
{
	if (![[NSFileManager defaultManager] fileExistsAtPath:path])
		[[NSFileManager defaultManager] createDirectoryAtPath:path attributes:nil];
}

// Keeps trying filenames until it finds one that isn't taken.. eg: given "Untitled","rdp", if  'Untitled.rdp' is taken, it will try 'Untitled 1.rdp', 'Untitled 2.rdp', etc until one is found, then it returns the found filename. Useful for duplicating files.
NSString * CRDFindAvailableFileName(NSString *path, NSString *base, NSString *extension)
{
	NSString *filename = [base stringByAppendingString:extension];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	int i = 0;
	while ([fileManager fileExistsAtPath:[path stringByAppendingPathComponent:filename]] && ++i<200)
		filename = [base stringByAppendingString:[NSString stringWithFormat:@" %d%@", i, extension]];
		
	return [path stringByAppendingPathComponent:filename];
}

// Returns the paths in unfilteredFiles whose extention or HFS type match the passed types
NSArray * CRDFilterFilesByType(NSArray *unfilteredFiles, NSArray *types)
{
	NSMutableArray *returnFiles = [NSMutableArray arrayWithCapacity:4];
	NSString *filename, *type, *extension, *hfsFileType;	
	for (filename in unfilteredFiles)
	{
		hfsFileType = [NSHFSTypeOfFile(filename) stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" '"]];
		extension = [filename pathExtension];
		for (type in types)
		{
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
char ** CRDMakeCStringArray(NSArray *stringArray)
{
	int i = 0;
	if ([stringArray count] == 0)
		return NULL;

	NSMutableData *data = [NSMutableData dataWithLength:(sizeof(char *) * [stringArray count])];
	char **cStringPtrArray = (char **)[data mutableBytes];
	
	id o;
	
	for ( o in stringArray )
		cStringPtrArray[i++] = (char *)[[o description] UTF8String];
	
	
	return cStringPtrArray;
}

inline void CRDSetAttributedStringColor(NSMutableAttributedString *as, NSColor *color)
{
	[as addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, [as length])];
}

inline void CRDSetAttributedStringFont(NSMutableAttributedString *as, NSFont *font)
{
	[as addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, [as length])];
}

inline CRDInputEvent CRDMakeInputEvent(unsigned int time, unsigned short type, unsigned short deviceFlags, unsigned short param1, unsigned short param2)
{
	CRDInputEvent ie;
	ie.time = time;
	ie.type = type;
	ie.param1 = param1;
	ie.param2 = param2;
	ie.deviceFlags = deviceFlags;
	return ie;
}

inline NSString *CRDTemporaryFile(void)
{
	NSString *baseDir = NSTemporaryDirectory();
	
	if (baseDir == nil)
		baseDir = @"/tmp";
		
	return [baseDir stringByAppendingPathComponent:[NSString stringWithFormat:@"CoRD-TemporaryFile-%u-%u", time(NULL), rand()]];
}

BOOL CRDPathIsHidden(NSString *path)
{
	CFURLRef fileURL = CFURLCreateWithString(NULL, (CFStringRef)[@"file://" stringByAppendingString:path], NULL);	
	if (!fileURL)
		return NO;
	
	LSItemInfoRecord itemInfo;
	LSCopyItemInfoForURL(fileURL, kLSRequestAllFlags, &itemInfo);
	CFRelease(fileURL);	
	return itemInfo.flags & kLSItemInfoIsInvisible;
}

inline NSCellStateValue CRDButtonState(BOOL enabled)
{
	return enabled ? NSOnState : NSOffState;
}

inline BOOL CRDPreferenceIsEnabled(NSString *prefName)
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:prefName];
}

inline void CRDSetPreferenceIsEnabled(NSString *prefName, BOOL enabled)
{
	[[NSUserDefaults standardUserDefaults] setBool:enabled forKey:prefName];
}


NSSize CRDProportionallyScaleSize(NSSize orig, NSSize enclosure)
{
	// xxx: cleanup
	BOOL widthLarger = orig.width > enclosure.width, heightLarger = orig.height > enclosure.height;
	if (!widthLarger && !heightLarger)
		return orig;

	float origAspectRatio = orig.width / orig.height;
	// xxx: this seems to work in practice, may not be mathematically correct
	return (orig.width/enclosure.width >= orig.height/enclosure.height)
		? NSMakeSize(round(enclosure.width), round(enclosure.width * (1.0 / origAspectRatio)))
		: NSMakeSize(round(enclosure.height * origAspectRatio), round(enclosure.height));
}



#pragma mark -
#pragma mark AppController specific

NSToolbarItem *CRDMakeToolbarItem(NSString *name, NSString *label, NSString *tooltip, SEL action)
{
	NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:name] autorelease];
	[item setPaletteLabel:name];
	[item setValue:label forKey:@"label"];
	[item setToolTip:tooltip];
	[item setAction:action];
	[item setImage:[NSImage imageNamed:[NSString stringWithFormat:@"%@.png", name]]];
		
	return item;
}

NSMenuItem * CRDMakeSearchFieldMenuItem(NSString *title, NSInteger tag)
{
	NSMenuItem *menuItem = [title isEqualToString:@"-"] ? [NSMenuItem separatorItem] : [[[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""] autorelease];
	[menuItem setTag:tag];
	return menuItem;
}






#pragma mark -
#pragma mark CRDSession specific

// This is simply the bare defaults for RDConnectionRef, used for *all* new connections to a server. It doesn't have anything to do with user-set defaults.
void CRDFillDefaultConnection(RDConnectionRef conn)
{
	char hostString[_POSIX_HOST_NAME_MAX+1];
	gethostname(hostString, _POSIX_HOST_NAME_MAX);
	
	conn->tcpPort = CRDDefaultPort;
	conn->screenWidth = CRDDefaultScreenWidth;
	conn->screenHeight = CRDDefaultScreenHeight;
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
	conn->keyboardLayout = 0x409; // en-us keyboard
	conn->keyboardType = 4;
	conn->keyboardSubtype = 0;
	conn->keyboardFunctionkeys = 12;
	conn->licenseIssued	= 0;
	conn->pstcacheEnumerated = 0;
	conn->ioRequest	= NULL;
	conn->bmpcacheLru[0] = conn->bmpcacheLru[1] = conn->bmpcacheLru[2] = NOT_SET;
	conn->bmpcacheMru[0] = conn->bmpcacheMru[1] = conn->bmpcacheMru[2] = NOT_SET;
	conn->errorCode = ConnectionErrorNone;
	conn->numDevices = 0;
	conn->numChannels = 0;
	conn->rdp5PerformanceFlags = RDP5_NO_WALLPAPER | RDP5_NO_FULLWINDOWDRAG | RDP5_NO_MENUANIMATIONS;
	
	// Auto Reconnect
	conn->tryAutoReconnect = False;
	conn->autoReconnectLogonID = 0;
	conn->pendingResize = False;
	
	conn->rdpdrClientname = malloc(strlen(hostString) + 1);
	strcpy(conn->rdpdrClientname, hostString);
	strncpy(conn->hostname, hostString, 64);
	
	conn->rectsNeedingUpdate = NULL;
	conn->updateEntireScreen = 0;
}


inline NSString *CRDBugReportURL(void)
{
	return [NSString stringWithFormat:@"%@newticket?type=defect&version=%@&keywords=MenuBarSubmission,%@", CRDTracURL, [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"], [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];	
}


BOOL CRDLog(CRDLogLevel logLevel, NSString *format, ...)
{
	static NSString* logFilePath = nil;
	static BOOL logFileUnwritable = NO, forceLogToStdout = NO;
	CRDLogLevel userLogLevelThreshold = [[[NSUserDefaults standardUserDefaults] objectForKey:@"CRDLogLevel"] integerValue];
	
#ifdef CORD_DEBUG_BUILD	
	
	forceLogToStdout = YES;

	if (userLogLevelThreshold)
		userLogLevelThreshold++;
	
#endif

	if (logLevel > userLogLevelThreshold)
		return NO;

	va_list args;
    va_start(args, format);
    NSString* composedMessage = [[[NSString alloc] initWithFormat:format arguments:args] autorelease];
    va_end(args);


	if (!logFilePath)
		logFilePath = [[[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Logs/CoRD.log"] retain];

	
	if (forceLogToStdout || (![[NSFileManager defaultManager] fileExistsAtPath:logFilePath] && ![[NSFileManager defaultManager] createFileAtPath:logFilePath contents:nil attributes:nil]))
	{
		if (!forceLogToStdout && !logFileUnwritable)
		{
			NSLog(@"Log file was unwritable -- using stdout instead. Tried: %@", logFilePath);
			logFileUnwritable = YES;
		}
		
		NSLog(@"%@",composedMessage);
	}
	else
	{
		NSString* messageWithDatetime = [NSString stringWithFormat:@"%@ %@\n", [[NSDate date] descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S" timeZone:nil locale:nil], composedMessage];
		NSFileHandle* logFileHandle = [NSFileHandle fileHandleForUpdatingAtPath:logFilePath];

		[logFileHandle seekToEndOfFile];
		[logFileHandle writeData:[messageWithDatetime dataUsingEncoding:NSUTF8StringEncoding]];
		[logFileHandle closeFile];
	}
	
	return NO;
}


