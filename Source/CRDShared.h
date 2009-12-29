/*	Copyright (c) 2007-2009 Dorian Johnson <2009@dorianj.net>
	
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


#import <Cocoa/Cocoa.h>
#import "rdesktop.h"
#import "CRDAdditions.h"

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

void CRDDrawVerticalGradient(NSColor *topColor, NSColor *bottomColor, NSRect rect);
void CRDDrawHorizontalLine(NSColor *color, NSPoint start, float width);


void CRDSplitHostNameAndPort(NSString *address, NSString **host, NSInteger *port);
NSString *CRDJoinHostNameAndPort(NSString *host, NSInteger port);

BOOL CRDResolutionStringIsFullscreen(NSString *screenResolution);
void CRDSplitResolutionString(NSString *resolution, NSInteger *width, NSInteger *height);
NSNumber *CRDNumberForColorsText(NSString * colorsText);

unsigned int CRDRoundUpToEven(float n);

BOOL CRDDrawerIsVisible(NSDrawer *drawer);

NSString *CRDConvertLineEndings(NSString *orig, BOOL withCarriageReturn);
const char *CRDMakeWindowsString(NSString *src);
const char *CRDMakeUTF16LEString(NSString *src);
int CRDGetUTF16LEStringLength(NSString *src);

void CRDCreateDirectory(NSString *directory);
NSString *CRDFindAvailableFileName(NSString *path, NSString *base, NSString *extension);
NSArray *CRDFilterFilesByType(NSArray *unfilteredFiles, NSArray *types);
NSString *CRDTemporaryFile(void);
BOOL CRDPathIsHidden(NSString *path);

char ** CRDMakeCStringArray(NSArray *conv);

void CRDSetAttributedStringColor(NSMutableAttributedString *as, NSColor *color);
void CRDSetAttributedStringFont(NSMutableAttributedString *as, NSFont *font);

CRDInputEvent CRDMakeInputEvent(unsigned int time, unsigned short type, unsigned short deviceFlags, unsigned short param1, unsigned short param2);
NSToolbarItem * CRDMakeToolbarItem(NSString *name, NSString *label, NSString *tooltip, SEL action);
NSMenuItem * CRDMakeSearchFieldMenuItem(NSString *title, NSInteger tag);


NSCellStateValue CRDButtonState(BOOL enabled);
BOOL CRDPreferenceIsEnabled(NSString *prefName);
void CRDSetPreferenceIsEnabled(NSString *prefName, BOOL enabled);

void CRDFillDefaultConnection(RDConnectionRef conn);
NSSize CRDProportionallyScaleSize(NSSize orig, NSSize enclosure);
NSString *CRDBugReportURL(void);



// Convenience macros
#define BUTTON_STATE_AS_NUMBER(b) [NSNumber numberWithInt:([(b) state] == NSOnState ? 1 : 0)]
#define CRDRectFromSize(s) ((NSRect){NSZeroPoint, (s)})
#define POINT_DISTANCE(p1, p2) ( sqrtf( powf( (p1).x - (p2).x, 2) + powf( (p1).y - (p2).y, 2) ) )
#define CGRECT_FROM_NSRECT(r) CGRectMake((r).origin.x, (r).origin.y, (r).size.width, (r).size.height)

#define LOCALS_FROM_CONN									\
	/*TRACE_FUNC;*/ \
	CRDSessionView *v = (CRDSessionView *)conn->ui;			\
	CRDSession *inst = (CRDSession *)conn->controller;


#pragma mark -
#pragma mark Constants

// Constants
extern const NSInteger CRDDefaultPort;
extern const NSInteger CRDDefaultScreenWidth, CRDDefaultScreenHeight;
extern const NSInteger CRDMouseEventLimit;
extern const NSInteger CRDInspectorMaxWidth;
extern const NSInteger CRDForwardAudio, CRDLeaveAudio, CRDDisableAudio;
extern const NSPoint CRDWindowCascadeStart;
extern const float CRDWindowSnapSize;
extern NSString * const CRDRowIndexPboardType;

// URLs for Support & Logistics
extern NSString * const CRDTracURL;
extern NSString * const CRDHomePageURL;
extern NSString * const CRDSupportForumsURL;

// Globals (used for readability in rdesktop code)
extern AppController *g_appController;

// NSUserDefaults keys
extern NSString * const CRDDefaultsUnifiedDrawerShown;
extern NSString * const CRDDefaultsUnifiedDrawerSide;
extern NSString * const CRDDefaultsUnifiedDrawerWidth;
extern NSString * const CRDDefaultsDisplayMode;
extern NSString * const CRDDefaultsQuickConnectServers;
extern NSString * const CRDDefaultsSendWindowsKey;

// User-configurable NSUserDefaults keys (preferences)
extern NSString * const CRDPrefsReconnectIntoFullScreen;
extern NSString * const CRDPrefsReconnectOutOfFullScreen;
extern NSString * const CRDPrefsScaleSessions;
extern NSString * const CRDPrefsMinimalisticServerList;
extern NSString * const CRDPrefsIgnoreCustomModifiers;
extern NSString * const CRDSetServerKeyboardLayout;
extern NSString * const CRDForwardOnlyDefinedPaths;
extern NSString * const CRDUseSocksProxy;

// Notifications
extern NSString * const CRDMinimalViewDidChangeNotification;

// Used to tack on the servers at the end of the Servers menu. There's probably a better way to do this, but this will do for now (works well enough)
#define SERVERS_SEPARATOR_TAG 19991
#define SERVERS_ITEM_TAG 20001

// Temporary use
#define USE_SOUND_FORWARDING 0



#pragma mark -
#pragma mark Controlling debugging output

//#define WITH_DEBUG_KEYBOARD
//#define WITH_DEBUG_MOUSE
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

#ifdef WITH_DEBUG_MOUSE
	#define DEBUG_MOUSE(args) NSLog args
#else
	#define DEBUG_MOUSE(args)
#endif

#if defined(CORD_RELEASE_BUILD) && (defined(WITH_MID_LEVEL_DEBUG) || defined(WITH_DEBUG_UI) || defined(WITH_DEBUG_KEYBOARD) || defined(WITH_DEBUG_MOUSE))
	#error Debugging output is enabled and building Release
#endif

#ifdef CORD_DEBUG_BUILD
	#define TRACE_FUNC NSLog(@"%s (%@@%u) entered", __func__, [[NSString stringWithCString:__FILE__ encoding:NSUTF8StringEncoding] lastPathComponent], __LINE__)
#endif


