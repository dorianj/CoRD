//
//  RDCKeyboard.m
//  Xrdc
//
//  Created by Craig Dooley on 8/15/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "RDCKeyboard.h"
#import "constants.h"

static RDCKeyboard *shared = nil;

@implementation RDCKeyboard
+ (RDCKeyboard *)shared {
	return shared;
}

- (id) init {
	if (shared != nil) {
		return shared;
	}
	
	self = [super init];
	if (self) {
		keymap = [[NSMutableDictionary alloc] init];
		[self readKeymap];
		shared = self;
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
