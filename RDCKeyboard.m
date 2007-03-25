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

#import <Carbon/Carbon.h>

#import "RDCKeyboard.h"
#import "RDInstance.h"
#import "rdesktop.h"
#import "scancodes.h"
#import "miscellany.h"

// Static class variables
static NSDictionary *isoNameTable = nil;

@interface RDCKeyboard (PrivateMethods)
	- (BOOL)parse_readKeymap:(NSString *)isoName;
	- (uni_key_translation *)parse_addUnicodeMapping:(uint16)uni scancode:(uint8)scan modifiers:(uint16)mods;
	- (void)sendKeys:(uint16)unicode keycode:(uint8)keyCode modifiers:(uint16)rdflags pressed:(BOOL)down nesting:(int)nesting;
	- (void)saveRemoteModifers:(uint8)scancode;
	- (void)restoreRemoteModifiers:(uint8)scancode;
	- (BOOL)scancodeIsModifier:(uint8)scancode;
	- (void)ensureRemoteModifiers:(uni_key_translation)kt;
	- (void)updateModifierState:(uint8)scancode pressed:(BOOL)down;
@end

#pragma mark -

@implementation RDCKeyboard

#pragma mark NSObject methods
- (id) init
{
	return [self initWithKeymap:[RDCKeyboard currentKeymapName]];
}

- (id) initWithKeymap:(NSString *)keymapName
{
	self = [super init];
	if (self != nil)
	{
		// Initialization stuff
		memset(unicodeKeymap, 0, 0xffff * sizeof(int *));
		memset(virtualKeymap, 0, 0xff * sizeof(uint8));
			
		// Load the keymap
		NSString *isoFileName = [RDCKeyboard isoFileNameForKeymap:keymapName];
		
		if (isoFileName == nil)
			return nil;

		[self parse_readKeymap:isoFileName];		
	}
	return self;
}

- (void)dealloc
{
	[isoNameTable release];
	
	// Empty the unicodeKeymap table, following sequences
	uni_key_translation *kt;
	int i;
	for (i = 0; i < 0xffff; i++)
		free_key_translation(unicodeKeymap[i]);
	
	[super dealloc];
}


#pragma mark Key event handling
- (void)handleKeyEvent:(NSEvent *)ev keyDown:(BOOL)down
{
	static UInt32 deadKeyState = 0, keyTranslateState = 0, initialized = 0;
	static SInt32 lastKeyLayoutID = 0;
	
	UCKeyboardLayout	*uchrData;
	void				*KCHRData;
	SInt32				keyLayoutKind, keyLayoutID;
	KeyboardLayoutRef	keyLayout;
	UInt32				charCode;
	UniCharCount		actualStringLength;
	UniChar				unicodeString[4];
	unsigned char code1, code2;
	uint16 uniChar = 0;
	BOOL composing = YES;
	
	UInt16 keyCode = [ev keyCode], kchrKeyCode;
	unsigned int mods = [ev modifierFlags];
	
	KLGetCurrentKeyboardLayout(&keyLayout);
	KLGetKeyboardLayoutProperty(keyLayout, kKLKind, (const void **)&keyLayoutKind);
	KLGetKeyboardLayoutProperty(keyLayout, kKLIdentifier, (const void**)&keyLayoutID);
	
	
	/* if changing keymaps while in use is to be supported, this will be needed
	if (lastKeyLayoutID != keyLayoutID || !initialized) {
		deadKeyState = keyTranslateState = 0;
		initialized = 1;
		lastKeyLayoutID = keyLayoutID;
	}*/
	
	if (keyLayoutKind == kKLKCHRKind) 
	{
		kchrKeyCode = (keyCode & 0x7f) | (mods & 0xffff00ff);
		kchrKeyCode = (down) ? (kchrKeyCode & 0xff7f) : (kchrKeyCode | 0x80);
		KLGetKeyboardLayoutProperty(keyLayout, kKLKCHRData, (const void **)&KCHRData);
		charCode = KeyTranslate(KCHRData, kchrKeyCode, &keyTranslateState);
		
		// ignore code1, it's normally gibberish
		//code1 = (charCode & 0xff0000) >> 16;
		code2 = (charCode & 0xff); 
		
		if (keyTranslateState == 0 && code2 != '\0') {
			// This character is finished composing and should be sent
			const char chrs[2] = {code2, '\0'}; 
			uniChar = [[NSString stringWithCString:chrs] characterAtIndex:0];
			composing = NO;
		}
	}
	else 
	{
		KLGetKeyboardLayoutProperty(keyLayout, kKLuchrData, (const void **)&uchrData);
		UCKeyTranslate(uchrData, keyCode, kUCKeyActionDown, [ev modifierFlags], 
					   LMGetKbdType(), 0, &deadKeyState,
					   4, &actualStringLength, unicodeString);
		if (deadKeyState == 0 || deadKeyState == 65536) {
			// This character is finished composing and should be sent
			uniChar = unicodeString[0];	
			composing = NO;
		}
	}
	
	
	
	
	// Try to translate the key to a scancode and send it to the server
	uint16 rdflags = [RDCKeyboard modifiersForEvent:ev];
	
	if (!composing) {
		DEBUG_KEYBOARD( (@"KeyEvent: '%C' (virtual key 0x%x, unicode 0x%x) %spressed", uniChar, keyCode, uniChar, (down) ? "" : "de") );
		[self sendKeys:uniChar keycode:keyCode modifiers:rdflags pressed:down];
	} else {
		DEBUG_KEYBOARD( (@"KeyEvent: currently composing, ignoring event") );
	}
	DEBUG_KEYBOARD( (@"\n") );
}


- (void)handleFlagsChanged:(NSEvent *)ev
{
	static unsigned lastMods = 0;
	int newMods = [ev modifierFlags];
	int changedMods = newMods ^ lastMods;
	BOOL pressed;
	
	#define UP_OR_DOWN(b) ( (b) ? RDP_KEYPRESS : RDP_KEYRELEASE )
	
	// Don't need to bother with capslock, it's handled by unicode mapping
	
	if (changedMods & NSShiftKeyMask)
		[self sendScancode:SCANCODE_CHAR_LSHIFT flags:UP_OR_DOWN(newMods & NSShiftKeyMask)];
		
	if (changedMods & NSControlKeyMask)
		[self sendScancode:SCANCODE_CHAR_LCTRL flags:UP_OR_DOWN(newMods & NSControlKeyMask)];
	
	if (changedMods & NSAlternateKeyMask)
		[self sendScancode:SCANCODE_CHAR_LALT flags:UP_OR_DOWN(newMods & NSAlternateKeyMask)];
	
	if (changedMods & NSCommandKeyMask)
		[self sendScancode:SCANCODE_CHAR_LWIN flags:UP_OR_DOWN(newMods & NSCommandKeyMask)];
	
	lastMods = newMods;
	
	#undef UP_OR_DOWN(x)
}

- (void)sendKeys:(uint16)unicode keycode:(uint8)keyCode modifiers:(uint16)rdflags pressed:(BOOL)down {
	[self sendKeys:unicode keycode:keyCode modifiers:rdflags pressed:down nesting:0];
}

- (void)sendKeys:(uint16)unicode keycode:(uint8)keyCode modifiers:(uint16)rdflags pressed:(BOOL)down nesting:(int)nesting
{
	if (keyCode && virtualKeymap[keyCode]) {
		// It's in the virtual key map, use that directly
		if (down)
			[self sendScancode:virtualKeymap[keyCode] flags:rdflags | RDP_KEYPRESS];
		else
			[self sendScancode:virtualKeymap[keyCode] flags:rdflags | RDP_KEYRELEASE];
			
		return;
	}
	else if (unicode && unicodeKeymap[unicode] != NULL)
	{
		uni_key_translation *kt = unicodeKeymap[unicode], *uk;
		
		if (kt->next == NULL) 
		{
			// single key, send it
			if (down)
			{
				[self saveRemoteModifers:kt->scancode];
				[self ensureRemoteModifiers:*kt];
				[self sendScancode:kt->scancode flags:RDP_KEYPRESS];
				[self restoreRemoteModifiers:kt->scancode];
			} 
			else
			{
				[self sendScancode:kt->scancode flags:RDP_KEYRELEASE];
			}
		}
		else if (down) 
		{
			DEBUG_KEYBOARD( (@"Sending keystroke sequence...") );
			nesting++;
				
			if (nesting >= 32) {
				DEBUG_KEYBOARD( (@"Too high of nesting: exiting sendKey. Likely culprit is a self-referring sequence (ex 'sequence 0x60 0x60 0x20'") );
				return;
			}
			
			// part of a sequence
			while ( (kt = kt->next) != NULL) // && (uk = unicodeKeymap[kt->seq_unicode]) != NULL)
			{					
				if ((uk = unicodeKeymap[kt->seq_unicode]) != NULL) {
					[self sendKeys:uk->unicode keycode:0 modifiers:uk->modifiers pressed:YES nesting:nesting];
					[self sendKeys:uk->unicode keycode:0 modifiers:uk->modifiers pressed:NO  nesting:nesting];
					
				} else {
					DEBUG_KEYBOARD( (@"Sequence 0x%x specified an unavailable unicode character, 0x%x",
										unicode, kt->seq_unicode) );
					break;
				}
			}
			
			
		}
	} else {
		DEBUG_KEYBOARD( (@"Unicode 0x%x (virt key 0x%x) had no mapping. Ignoring.", unicode, keyCode) );
	}
}


// Returns YES if any keys are handled, otherwise NO
- (BOOL) handleSpecialKeys:(NSEvent *)ev
{
	uint16 flags = [RDCKeyboard modifiersForEvent:ev];
	uint16 keycode = [ev keyCode];
	
	/* This may be needed in the future for things like pause/break */
	
	return NO;
}


- (void)saveRemoteModifers:(uint8)scancode
{
	if ([self scancodeIsModifier:scancode])
		return;
	
	savedRemoteModiferState = remoteModiferState;
}

- (void)restoreRemoteModifiers:(uint8)scancode
{
	uni_key_translation dummy;
	if ([self scancodeIsModifier:scancode])
		return;
	
	dummy.scancode = 0;
	dummy.modifiers = savedRemoteModiferState;
	[self ensureRemoteModifiers:dummy];

}

- (BOOL)scancodeIsModifier:(uint8)scancode
{
	switch (scancode)
	{
		case SCANCODE_CHAR_LSHIFT:
		case SCANCODE_CHAR_RSHIFT:
		case SCANCODE_CHAR_LCTRL:
		case SCANCODE_CHAR_RCTRL:
		case SCANCODE_CHAR_LALT:
		case SCANCODE_CHAR_RALT:
		case SCANCODE_CHAR_LWIN:
		case SCANCODE_CHAR_RWIN:
		case SCANCODE_CHAR_NUMLOCK:
			return YES;
		default:
			break;
	}
	return NO;
}

- (void)ensureRemoteModifiers:(uni_key_translation)kt
{
	if ([self scancodeIsModifier:kt.scancode])
		return;


	/* NumLock */
	if (MASK_HAS_BITS(kt.modifiers, MapNumLockMask) != MASK_HAS_BITS(remoteModiferState, MapNumLockMask))
	{
		uint16 newRemoteState;
		if (MASK_HAS_BITS(kt.modifiers, MapNumLockMask))
		{
			newRemoteState = KBD_FLAG_NUMLOCK;
			remoteModiferState = MapNumLockMask;
		}
		else
		{
			remoteModiferState = newRemoteState = 0;
		}

		[controller sendInput:RDP_INPUT_SYNCHRONIZE flags:0 param1:newRemoteState param2:0];
	}
	
	
	/* Shift */
	if (MASK_HAS_BITS(kt.modifiers, MapShiftMask) != MASK_HAS_BITS(remoteModiferState, MapShiftMask))
	{
		if (MASK_HAS_BITS(kt.modifiers, MapLeftShiftMask))
			[self sendScancode:SCANCODE_CHAR_LSHIFT flags:RDP_KEYPRESS];
		else if (MASK_HAS_BITS(kt.modifiers, MapRightShiftMask))
			[self sendScancode:SCANCODE_CHAR_RSHIFT flags:RDP_KEYPRESS];
		else
		{
			if (MASK_HAS_BITS(remoteModiferState, MapLeftShiftMask))
				[self sendScancode:SCANCODE_CHAR_LSHIFT flags:RDP_KEYRELEASE];
			else
				[self sendScancode:SCANCODE_CHAR_RSHIFT flags:RDP_KEYRELEASE];
		}
	}
	
	/* AltGr */
	if (MASK_HAS_BITS(kt.modifiers, MapAltGrMask) != MASK_HAS_BITS(remoteModiferState, MapAltGrMask))
	{
		if (MASK_HAS_BITS(kt.modifiers, MapAltGrMask))
			[self sendScancode:SCANCODE_CHAR_RALT flags:RDP_KEYPRESS];
		else
			[self sendScancode:SCANCODE_CHAR_RALT flags:RDP_KEYRELEASE];
	}
}


- (void)updateModifierState:(uint8)scancode pressed:(BOOL)down
{
	switch (scancode)
	{
		case SCANCODE_CHAR_LSHIFT:
			MASK_CHANGE_BIT(remoteModiferState, MapLeftShiftMask, down);
			break;
		case SCANCODE_CHAR_RSHIFT:
			MASK_CHANGE_BIT(remoteModiferState, MapRightShiftMask, down);
			break;
		case SCANCODE_CHAR_LCTRL:
			MASK_CHANGE_BIT(remoteModiferState, MapLeftCtrlMask, down);
			break;
		case SCANCODE_CHAR_RCTRL:
			MASK_CHANGE_BIT(remoteModiferState, MapRightCtrlMask, down);
			break;
		case SCANCODE_CHAR_LALT:
			MASK_CHANGE_BIT(remoteModiferState, MapLeftAltMask, down);
			break;
		case SCANCODE_CHAR_RALT:
			MASK_CHANGE_BIT(remoteModiferState, MapRightAltMask, down);
			break;
		case SCANCODE_CHAR_LWIN:
			MASK_CHANGE_BIT(remoteModiferState, MapLeftWinMask, down);
			break;
		case SCANCODE_CHAR_RWIN:
			MASK_CHANGE_BIT(remoteModiferState, MapRightWinMask, down);
			break;
		case SCANCODE_CHAR_NUMLOCK:
			/* xxx: not handling numlock
				KeyReleases for NumLocks are sent immediately. Toggle the
				modifier state only on Keypress 
			if (down && !g_numlock_sync)
			{
				BOOL newNumLockState;
				newNumLockState =
					(MASK_HAS_BITS
					 (remote_modifier_state, MapNumLockMask) == False);
				MASK_CHANGE_BIT(remote_modifier_state,
						MapNumLockMask, newNumLockState);
			}*/
			break;
	}


}



- (void)sendScancode:(uint8)scancode flags:(uint16)flags
{
	[self updateModifierState:scancode pressed:!(flags & RDP_KEYRELEASE)];

	if (scancode & SCANCODE_EXTENDED)
	{
		DEBUG_KEYBOARD((@"Sending extended scancode=0x%x, flags=0x%x\n", scancode & ~SCANCODE_EXTENDED, flags));
		[controller sendInput:RDP_INPUT_SCANCODE flags:flags | KBD_FLAG_EXT param1:scancode & ~SCANCODE_EXTENDED param2:0];
	}
	else
	{
		DEBUG_KEYBOARD( (@"Sending scancode=0x%x flags=0x%x", scancode, flags) );
		[controller sendInput:RDP_INPUT_SCANCODE flags:flags param1:scancode param2:0];
	}
}


#pragma mark Accessors
- (RDInstance *)controller
{
	return controller;
}

- (void)setController:(RDInstance *)cont
{
	controller = cont;
}




#pragma mark Keymap file parser
- (BOOL)parse_readKeymap:(NSString *)isoName
{
	DEBUG_KEYBOARD( (@"Reading keymap '%@'", isoName) );
	
	NSString *filePath = [[NSBundle mainBundle] pathForResource:isoName
														 ofType:nil
													inDirectory:@"keymaps"];
	NSArray *fileLines = [[NSString stringWithContentsOfFile:filePath] componentsSeparatedByString:@"\n"];
	
	if (fileLines == nil) {
		DEBUG_KEYBOARD( (@"Error reading keymap '%@'. File probably doesn't exist.", isoName) );
		return NO;
	}
	
	NSCharacterSet *whitespaceSet    = [NSCharacterSet whitespaceCharacterSet],
				   *whiteAndHashSet  = [NSCharacterSet characterSetWithCharactersInString:@" \t#"];
	NSScanner *scanner;
	NSString *directive, *s, *name;
	unsigned int unicodeValue, osxVKValue, scancode, modifiers, i;
	uni_key_translation *keyTrans, *cur, *kt;
	
	
	signed lineNumber = -1;
	BOOL b = YES, addUpper;
	id line;
	NSEnumerator *enumerator = [fileLines objectEnumerator];
		
	while ( (line = [enumerator nextObject]) )
	{
		lineNumber++;
		if (!b)
			DEBUG_KEYBOARD( (@"Uncaught keymap syntax error in '%@' at line %d. Ignoring.", isoName, lineNumber - 1) );
	
		scanner = [NSScanner scannerWithString:line];
		b = YES;
	
		if (![scanner scanUpToCharactersFromSet:whiteAndHashSet intoString:&directive])
			continue;
		
		
		if ([directive isEqualToString:@"virt"])
		{
			// Virtual mapping
			b &= [scanner scanHexInt:&osxVKValue];
			b &= [scanner scanHexInt:&scancode];
			
			if (b && osxVKValue < 256) {
				virtualKeymap[osxVKValue] = scancode;
			}
		}
		else if ([directive isEqualToString:@"char"])
		{
			keyTrans = malloc(sizeof(uni_key_translation));
			
			// Unicode mapping
			b &= [scanner scanHexInt:&unicodeValue];
			b &= [scanner scanHexInt:&scancode];
			
			if (!b)
				continue;
			
			modifiers = 0;
			
			// read modifiers
			addUpper = NO;
			while ([scanner scanUpToCharactersFromSet:whiteAndHashSet intoString:&s])
			{
				if ([s isEqualToString:@"addupper"])
					addUpper = YES;
			
				if ([s isEqualToString:@"altgr"])
					MASK_ADD_BITS(modifiers, MapAltGrMask);
				
				if ([s isEqualToString:@"inhibit"])
					MASK_ADD_BITS(modifiers, MapInhibitMask);
				
				if ([s isEqualToString:@"shift"])
					MASK_ADD_BITS(modifiers, MapLeftShiftMask);
					
				if ([s isEqualToString:@"numlock"])
					MASK_ADD_BITS(modifiers, MapNumLockMask);
				
				if ([s isEqualToString:@"localstate"])
					MASK_ADD_BITS(modifiers, MapLocalStateMask);
			}
			
			[self parse_addUnicodeMapping:unicodeValue scancode:scancode modifiers:modifiers];
			
			if (addUpper) {
				MASK_ADD_BITS(modifiers, MapLeftShiftMask);
				unicodeValue = toupper(unicodeValue);
				[self parse_addUnicodeMapping:unicodeValue scancode:scancode modifiers:modifiers];
			}
			
		}
		else if ([directive isEqualToString:@"include"])
		{
			// Include another keymap
			b &= [scanner scanUpToCharactersFromSet:whitespaceSet intoString:&s];
			if (b)
				[self parse_readKeymap:s];
		}
		else if ([directive isEqualToString:@"sequence"])
		{
			b &= [scanner scanHexInt:&unicodeValue];
			
			if (!b)
				continue;
			
			cur = keyTrans = [self parse_addUnicodeMapping:unicodeValue scancode:scancode modifiers:0];
			while ([scanner scanUpToCharactersFromSet:whiteAndHashSet intoString:&s])
			{
				if (HEXSTRING_TO_INT(s, &i)) {
					kt = malloc(sizeof(uni_key_translation));
					kt->scancode = kt->unicode = kt->modifiers = 0;
					kt->seq_unicode = i;
					cur = cur->next = kt;
				} else {
					DEBUG_KEYBOARD( (@"Syntax error in '%@' keymap on line %d: unrecognized item '%@' in sequence. Ignoring.",
										isoName, lineNumber, s) );
				}
			//	DEBUG_KEYBOARD( (@"Sequence item unicode 0x%x added for '%@'", i, s) );
			}
			cur->next = NULL;
		//	DEBUG_KEYBOARD( (@"Sequence for unicode 0x%x added .", unicodeValue) );
		} else {
			DEBUG_KEYBOARD( (@"Syntax error in '%@' keymap on line %d: unrecognized directive '%@'. Ignoring.",
								isoName, lineNumber, directive) );
		}
	}
	
	return YES;
}

- (uni_key_translation *) parse_addUnicodeMapping:(uint16)uni scancode:(uint8)scan modifiers:(uint16)mods
{
	uni_key_translation *uk = unicodeKeymap[uni];
	if (uk == NULL) {
		uk = malloc(sizeof(uni_key_translation));
		uk->seq_unicode = 0;
		uk->next = NULL;		
	}
	
	uk->unicode = uni;
	uk->scancode = scan;
	uk->modifiers = mods;
	return unicodeKeymap[uni] = uk;
}



#pragma mark Finding appropriate keymaps

// This method isn't threadsafe.
+ (NSString *) isoFileNameForKeymap:(NSString *)keymapName {
	
	// Load 'ISO language name' --> 'OSX keymap name'lookup table if it isn't already loaded
	if (isoNameTable == nil)
	{
		NSMutableDictionary *dict = [[NSMutableDictionary dictionaryWithCapacity:30] retain];
		NSString *filename = [[NSBundle mainBundle] pathForResource:@"iso_names" ofType:@"txt"];
		NSArray *lines = [[NSString stringWithContentsOfFile:filename] componentsSeparatedByString:@"\n"];
		NSScanner *scanner;
		NSString *i, *n;
		
		id line;
		NSEnumerator *enumerator = [lines objectEnumerator];
		while ( (line = [enumerator nextObject]) )
		{
			line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			scanner = [NSScanner scannerWithString:line];
			[scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@" \t="]];
			[scanner scanUpToString:@"=" intoString:&i];
			[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@""] intoString:&n];
			
			if (i != nil && n != nil) {
				// store it 'OS X name'=>'iso'
				[dict setObject:i forKey:n];			
			}
		}
		isoNameTable = dict;
	}
	
	
	
	// Look up in table
	
	NSString *isoName = nil;
	
	// try a direct match
	isoName = [isoNameTable objectForKey:keymapName];
	
	
	if (isoName == nil)
	{
		// try a fuzzy match - if this keymap and one in the table have at least the
		//	first four characters alike, use it. This allows things like 'Arabic-QWERTY'
		//	to be implicitly used when only 'Arabic' is in the table
		
		NSString *prefix;
		
		id potentialKeymapName;
		NSEnumerator *enumerator = [[isoNameTable allKeys] objectEnumerator];
		
		while ( (potentialKeymapName = [enumerator nextObject]) )
		{
			prefix = [keymapName commonPrefixWithString:potentialKeymapName
												options:NSLiteralSearch];
			if ([prefix length] >= 4) { 
				isoName = [isoNameTable objectForKey:potentialKeymapName];
				DEBUG_KEYBOARD( (@"isoFileNameForKeymap: substituting keymap '%@' for passed '%@', giving iso '%@'",
					  potentialKeymapName, keymapName, isoName));
				break;
			}
		}
	}
	
	return isoName;
}


#pragma mark Other class methods
+ (uint16)modifiersForEvent:(NSEvent *)ev {
	unsigned int eventFlags = [ev modifierFlags];
	uint16 rdFlags = 0;
	
	if (eventFlags & NSAlphaShiftKeyMask)
		MASK_CHANGE_BIT(rdFlags, MapCapsLockMask, 1);
	
	if (eventFlags & NSShiftKeyMask)
		MASK_CHANGE_BIT(rdFlags, MapLeftShiftMask, 1);

	if (eventFlags & NSControlKeyMask)
		MASK_CHANGE_BIT(rdFlags, MapLeftCtrlMask, 1);
	
	if (eventFlags & NSAlternateKeyMask)
		MASK_CHANGE_BIT(rdFlags, MapLeftAltMask, 1);

	if (eventFlags & NSCommandKeyMask)
		MASK_CHANGE_BIT(rdFlags, MapLeftWinMask, 1);

	return rdFlags;
}

+ (NSString *) currentKeymapName
{
	CFStringRef *name;
	KeyboardLayoutRef keyLayout;
	KLGetCurrentKeyboardLayout(&keyLayout);
	KLGetKeyboardLayoutProperty(keyLayout, kKLLocalizedName, (const void **)&name);
	
	return (NSString *)name;
}

@end
