//
//  RDCKeyboard.m
//  Remote Desktop
//
//  Created by Craig Dooley on 8/15/06.

//  Copyright (c) 2006 Craig Dooley <xlnxminusx@gmail.com>
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

#import "RDCKeyboard.h"
#import "constants.h"

static RDCKeyboard *shared = nil;

@implementation RDCKeyboard
+ (RDCKeyboard *)shared {
	if (!shared) {
		shared = [[RDCKeyboard alloc] init];
	}
	
	return shared;
}

- (id) init {
	
	self = [super init];
	if (self) {
		keymap = [[NSMutableDictionary alloc] init];
		[self readKeymap];
	}
	
	return self;
}

- (void)readKeymap {
	NSString *path = [[NSBundle mainBundle] pathForResource:@"keymap" ofType:@"txt"];
	NSString *file = [NSString stringWithContentsOfFile:path];
	NSArray *lines = [file componentsSeparatedByString:@"\n"];
	NSEnumerator *e = [lines objectEnumerator];
	NSString *line;
	
	while ((line = [e nextObject]) != nil) {
		unsigned key, scan;
		NSScanner *scanner = [NSScanner scannerWithString:line];
		[scanner scanHexInt:&key];
		[scanner scanHexInt:&scan];
		
		[keymap setObject:[NSNumber numberWithInt:scan] forKey:[NSNumber numberWithInt:key]];
	}
}

- (int)scancodeForKeycode:(int)keyCode {
	NSNumber *scan;
	
	if ((scan = [keymap objectForKey:[NSNumber numberWithInt:keyCode]]) != nil) {
		return [scan intValue];
	}
	
	return 0;
}

+ (int)NSEventToRDModifiers:(NSEvent *)ev {
	int NSFlags = [ev modifierFlags];
	int RDFlags = 0;
	
	if (NSFlags & NSAlphaShiftKeyMask) {
		MASK_CHANGE_BIT(RDFlags, MapCapsLockMask, 1);
	}
	
	if (NSFlags & NSShiftKeyMask) {
		MASK_CHANGE_BIT(RDFlags, MapLeftShiftMask, 1);
	}
	
	if (NSFlags & NSControlKeyMask) {
		MASK_CHANGE_BIT(RDFlags, MapLeftCtrlMask, 1);
	}
	
	if (NSFlags & NSAlternateKeyMask) {
		MASK_CHANGE_BIT(RDFlags, MapLeftAltMask, 1);
	}
	
	if (NSFlags & NSCommandKeyMask) {
		MASK_CHANGE_BIT(RDFlags, MapLeftWinMask, 1);
	}
	
	return RDFlags;
}

- (void)dealloc {
	[keymap release];
	[super dealloc];
}
@end
