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

/*	Purpose: various stubs which support the controller layer.
	Note: All of these functions require an NSAutoReleasePool be allocated.
*/


#include <Cocoa/Cocoa.h>
#include "rdesktop.h"

@class AppController;

/* General purpose */
const char *safe_string_conv(void *src);
void draw_vertical_gradient(NSColor *topColor, NSColor *bottomColor, NSRect rect);
void draw_line(NSColor *color, NSPoint start, NSPoint end);
#define RECT_FROM_SIZE(r) NSMakeRect(0.0, 0.0, (r).width, (r).height)
#define PRINT_RECT(s, r) NSLog(@"%@: (%.1f, %.1f) size %.1f x %.1f", s, (r).origin.x, (r).origin.y, (r).size.width, (r).size.height)
#define PRINT_POINT(s, p) NSLog(@"%@: (%.1f, %.1f)", s, (p).x, (p).y)
#define POINT_DISTANCE(p1, p2) ( sqrt( pow( (p1).x - (p2).x, 2) + pow( (p1).y - (p2).y, 2) ) )
NSString *convert_line_endings(NSString *orig, BOOL withCarriageReturn);

NSString *full_host_name(NSString *host, int port);

/* AppController */
NSToolbarItem * create_static_toolbar_item(NSString *name, NSString *label, NSString *tooltip, SEL action);
BOOL drawer_is_visisble(NSDrawer *drawer);
void ensure_directory_exists(NSString *directory, NSFileManager *manager);
NSString *increment_file_name(NSString *path, NSString *base, NSString *extension);
void split_hostname(NSString *address, NSString **host, int *port);
NSArray *filter_filenames(NSArray *unfilteredFiles, NSArray *types);
#define NUMBER_AS_BSTATE(b) ( ([(b) boolValue]) ? NSOnState : NSOffState)
#define BUTTON_STATE_AS_NUMBER(b) [NSNumber numberWithInt:([(b) state] == NSOnState ? 1 : 0)]
#define BUTTON_STATE_AS_NUMBER_INVERSE(b) [NSNumber numberWithInt:([(b) state] == NSOnState ? 0 : 1)]

/* RDCKeyboard */
void print_bitfield(unsigned v, int bits);
#define HEXSTRING_TO_INT(s, ret) [[NSScanner scannerWithString:(s)] scanHexInt:(ret)]

/* RDInstance */
char **convert_string_array(NSArray *conv);
void fill_default_connection(rdcConnection conn);

/* Constants */
#define DEFAULT_PORT 3389
#define WINDOW_START_X 50
#define WINDOW_START_Y 20
#define SAVED_SERVER_DRAG_TYPE @"savedServerDragType"
#define SNAP_WINDOW_SIZE 30.0
#define MOUSE_EVENTS_PER_SEC 15.0
#define SERVERS_SEPARATOR_TAG 19991
#define SERVERS_ITEM_TAG 20001

/* User defaults (NSUserDefaults) keys */
#define DEFAULTS_SHOW_DRAWER @"show_drawer"
#define DEFAULTS_DRAWER_SIDE @"preferred_drawer_side"
#define DEFAULTS_DRAWER_WIDTH @"drawer_width"
#define DEFAULTS_DISPLAY_MODE @"windowed_mode"
#define DEFAULTS_RECENT_SERVERS @"RecentServers"
#define DEFAULTS_UNIFIED_AUTOSAVE @"UnfiedWindowFrameAutosave"
#define DEFAULTS_INSPECTOR_AUTOSAVE @"InspectorWindowFrameAutosave"

#define PREFS_FULLSCREEN_RECONNECT @"reconnectFullScreen"
#define PREFS_RESIZE_VIEWS @"resizeViewToFit"

#define PREFERENCE_ENABLED(prefName) [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:(prefName)] boolValue]

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


/* Globals */
AppController *g_appController;

#define DISK_FORWARDING_DISABLED 1

/* General mid-level debugging */
//#define WITH_DEBUG_KEYBOARD 1
//#define WITH_DEBUG_UI 1
//#define WITH_MID_LEVEL_DEBUG 1

#ifdef WITH_MID_LEVEL_DEBUG
	#define UNIMPL NSLog(@"Unimplemented: %s", __func__)
	#define TRACE_FUNC NSLog(@"%s (%@@%u) entered", __func__, [[NSString stringWithCString:__FILE__] lastPathComponent], __LINE__)
	#define WITH_ANY_DEBUG 1
#else
	#define UNIMPL
	#define TRACE_FUNC
#endif

#ifdef WITH_DEBUG_KEYBOARD
	#define DEBUG_KEYBOARD(args) NSLog args 
	#define WITH_ANY_DEBUG 1
#else
	#define DEBUG_KEYBOARD(args)
#endif 

#ifdef WITH_DEBUG_UI
	#define DEBUG_UI(args) NSLog args
	#define CHECKOPCODE(x) if ((x)!=12 && (x) < 16) { NSLog(@"Unimplemented opcode %d in function %s", (x), __func__); }
	#define WITH_ANY_DEBUG 1
#else
	#define DEBUG_UI(args)
	#define CHECKOPCODE(x) 
#endif


#if defined(WITH_ANY_DEBUG) && defined(CORD_RELEASE_BUILD)
	#error Debugging is enabled and building release
#endif
