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

/*	Purpose: General shared routines and values within CoRD.
	Note: All of these routines require an NSAutoReleasePool be allocated.
*/


#include <Cocoa/Cocoa.h>
#include "rdesktop.h"

@class AppController;


#pragma mark -
#pragma mark Types

typedef enum _CRDConnectionStatus
{
   CRDConnectionClosed = 0,
   CRDConnectionConnecting = 1,
   CRDConnectionConnected = 2,
   CRDConnectionDisconnecting = 3
} CRDConnectionStatus;

typedef enum _CRDDisplayMode
{
	CRDDisplayUnified = 0,
	CRDDisplayWindowed = 1,
	CRDDisplayFullscreen = 2
} CRDDisplayMode;

typedef struct _CRDInputEvent
{
	unsigned int time; 
	unsigned short type, deviceFlags, param1, param2;
} CRDInputEvent;


#pragma mark -
#pragma mark Shared routines
// General purpose
void draw_vertical_gradient(NSColor *topColor, NSColor *bottomColor, NSRect rect);
inline void draw_horizontal_line(NSColor *color, NSPoint start, float width);
inline NSString *join_host_name(NSString *host, int port);
void split_hostname(NSString *address, NSString **host, int *port);
inline NSString *join_host_name(NSString *host, int port);
NSString *convert_line_endings(NSString *orig, BOOL withCarriageReturn);
inline BOOL drawer_is_visisble(NSDrawer *drawer);
inline const char *safe_string_conv(void *src);
inline void ensure_directory_exists(NSString *directory);
NSString *increment_file_name(NSString *path, NSString *base, NSString *extension);
NSArray *filter_filenames(NSArray *unfilteredFiles, NSArray *types);
char ** convert_string_array(NSArray *conv);
inline void set_attributed_string_color(NSMutableAttributedString *as, NSColor *color);
inline void set_attributed_string_font(NSMutableAttributedString *as, NSFont *font);
inline CRDInputEvent CRDMakeInputEvent(unsigned int time,
	unsigned short type, unsigned short deviceFlags, unsigned short param1, unsigned short param2);

// AppController specific
NSToolbarItem * create_static_toolbar_item(NSString *name, NSString *label, NSString *tooltip, SEL action);

// RDInstance specific
void fill_default_connection(rdcConnection conn);

// Convenience macros
#define BOOL_AS_BSTATE(b) ( (b) ? NSOnState : NSOffState)
#define NUMBER_AS_BSTATE(b) BOOL_AS_BSTATE([(b) boolValue])
#define BUTTON_STATE_AS_NUMBER(b) [NSNumber numberWithInt:([(b) state] == NSOnState ? 1 : 0)]
#define BUTTON_STATE_AS_NUMBER_INVERSE(b) [NSNumber numberWithInt:([(b) state] == NSOnState ? 0 : 1)]
#define HEXSTRING_TO_INT(s, ret) [[NSScanner scannerWithString:(s)] scanHexInt:(ret)]
#define RECT_FROM_SIZE(r) NSMakeRect(0.0, 0.0, (r).width, (r).height)
#define PRINT_RECT(s, r) NSLog(@"%@: (%.1f, %.1f) size %.1f x %.1f", s, (r).origin.x, (r).origin.y, (r).size.width, (r).size.height)
#define PRINT_POINT(s, p) NSLog(@"%@: (%.1f, %.1f)", s, (p).x, (p).y)
#define POINT_DISTANCE(p1, p2) ( sqrt( pow( (p1).x - (p2).x, 2) + pow( (p1).y - (p2).y, 2) ) )
#define CGRECT_FROM_NSRECT(r) CGRectMake((r).origin.x, (r).origin.y, (r).size.width, (r).size.height)

#pragma mark -
#pragma mark Constants

// Constants
extern const int CRDDefaultPort;
extern const int CRDMouseEventLimit;
extern const NSPoint CRDWindowCascadeStart;
extern const float CRDWindowSnapSize;
extern NSString *CRDRowIndexPboardType;

// Globals (used for readability in rdesktop code)
extern AppController *g_appController;

// NSUserDefaults keys
extern NSString *CRDDefaultsUnifiedDrawerShown;
extern NSString *CRDDefaultsUnifiedDrawerSide;
extern NSString *CRDDefaultsUnifiedDrawerWidth;
extern NSString *CRDDefaultsDisplayMode;
extern NSString *CRDDefaultsQuickConnectServers;
extern NSString *CRDDefaultsSendWindowsKey;

// User-configurable NSUserDefaults keys (preferences)
extern NSString *CRDPrefsReconnectIntoFullScreen;
extern NSString *CRDPrefsReconnectOutOfFullScreen;
extern NSString *CRDPrefsScaleSessions;
extern NSString *CRDPrefsMinimalisticServerList;
extern NSString *CRDPrefsIgnoreCustomModifiers;

// Notifications
extern NSString *CRDMinimalViewDidChangeNotification;

// Used to tack on the servers at the end of the Servers menu. There's probably a better way to do this, but this will do for now (works well enough)
#define SERVERS_SEPARATOR_TAG 19991
#define SERVERS_ITEM_TAG 20001

// Convenience macros for preferences
#define PREFERENCE_ENABLED(pref) [[NSUserDefaults standardUserDefaults] boolForKey:(pref)]
#define SET_PREFERENCE_ENABLED(pref, b) [[NSUserDefaults standardUserDefaults] setBool:(b) forKey:(pref)]



// Temporary use
#define DISK_FORWARDING_DISABLED 1



#pragma mark -
#pragma mark Controlling debugging output

//#define WITH_DEBUG_KEYBOARD 1
//#define WITH_DEBUG_UI 1
//#define WITH_MID_LEVEL_DEBUG 1

#ifdef WITH_MID_LEVEL_DEBUG
	#define UNIMPL NSLog(@"Unimplemented: %s", __func__)
#else
	#define UNIMPL
#endif

#ifdef WITH_DEBUG_KEYBOARD
	#define DEBUG_KEYBOARD(args) NSLog args 
#else
	#define DEBUG_KEYBOARD(args)
#endif 

#ifdef WITH_DEBUG_UI
	#define DEBUG_UI(args) NSLog args
	#define CHECKOPCODE(x) if ((x)!=12 && (x) < 16) { NSLog(@"Unimplemented opcode %d in function %s", (x), __func__); }
#else
	#define DEBUG_UI(args)
	#define CHECKOPCODE(x) 
#endif


#if defined(CORD_RELEASE_BUILD) && (defined(WITH_MID_LEVEL_DEBUG) || defined(WITH_DEBUG_UI) || defined(WITH_DEBUG_KEYBOARD))
	#error Debugging output is enabled and building Release
#endif

#ifdef CORD_DEBUG_BUILD
	#define TRACE_FUNC NSLog(@"%s (%@@%u) entered", __func__, [[NSString stringWithCString:__FILE__] lastPathComponent], __LINE__)
#endif


