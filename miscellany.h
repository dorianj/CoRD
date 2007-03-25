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
*/


#include <Cocoa/Cocoa.h>
#include "rdesktop.h"

/* General purpose */
const char *safe_string_conv(void *src);

/* AppController */
NSToolbarItem * create_static_toolbar_item(NSView *view, NSString *name, NSString *tooltip, SEL action);
int wrap_array_index(int start, int count, signed int modifier);

/* ConnectionsController */
void ensureDirectoryExists(NSString *directory, NSFileManager *manager);
NSNumber * buttonStateAsNumber(NSButton * button);
NSNumber * buttonStateAsNumberInverse(NSButton * button);
NSString * findAvailableFileName(NSString *path, NSString *base, NSString *extension);
void split_hostname(NSString *address, NSString **host, int *port);
NSArray *filter_filenames(NSArray *unfilteredFiles, NSArray *types);
#define BOOL_AS_BUTTON_STATE(b) ((b) ? NSOnState : NSOffState)
#define BUTTON_STATE_AS_NUMBER(b) [NSNumber numberWithInt:([(b) state] == NSOnState ? 1 : 0)]
#define BUTTON_STATE_AS_NUMBER_INVERSE(b) [NSNumber numberWithInt:([(b) state] == NSOnState ? 0 : 1)]

/* RDCKeyboard */
void free_key_translation(uni_key_translation *);
void print_bitfield(unsigned v, int bits);
#define HEXSTRING_TO_INT(s, ret) [[NSScanner scannerWithString:(s)] scanHexInt:(ret)]

/* RDInstance */
char **convert_string_array(NSArray *conv);


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
	#define CHECKOPCODE(x) if ((x)!=12 && (x) < 16) { NSLog(@"Unimplemented opcode %d in function %s", (x), __func__); }
#else
	#define CHECKOPCODE(x) 
#endif



