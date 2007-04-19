//  Copyright (c) 2007 Dorian Johnson <arcadiclife@gmail.com>
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

/*	Purpose: various stubs which support the controller layer.
	Note: Assume that all of these functions require an NSAutoReleasePool be allocated.
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

/* User defaults (NSUserDefaults) keys */
#define DEFAULTS_SHOW_DRAWER @"show_drawer"
#define DEFAULTS_DRAWER_WIDTH @"drawer_width"
#define DEFAULTS_DISPLAY_MODE @"windowed_mode"

#define PREFS_FULLSCREEN_RECONNECT @"reconnectFullScreen"
#define PREFS_RESIZE_VIEWS @"resizeViewToFit"

#define PREFERENCE_ENABLED(prefName) [[[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:(prefName)] boolValue]

typedef enum _CRDConnectionStatus
{
   CRDConnectionClosed = 0,
   CRDConnectionConnecting = 1,
   CRDConnectionConnected = 2
} CRDConnectionStatus;

typedef enum _CRDDisplayMode
{
	CRDDisplayUnified = 0,
	CRDDisplayWindowed = 1,
	CRDDisplayFullscreen = 2
} CRDDisplayMode;


/* Global variables */
AppController *g_appController;


/* General mid-level debugging */
//#define WITH_DEBUG_KEYBOARD 1
//#define WITH_DEBUG_UI 1
//#define WITH_MID_LEVEL_DEBUG 1

#ifdef WITH_MID_LEVEL_DEBUG
	#define UNIMPL NSLog(@"Unimplemented: %s", __func__)
	#define TRACE_FUNC NSLog(@"%s (%s@%u) entered", __func__, __FILE__, __LINE__)
#else
	#define UNIMPL
	#define TRACE_FUNC
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



