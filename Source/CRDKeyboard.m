/*	Copyright (c) 2007-2008 Dorian Johnson <arcadiclife@gmail.com>
	
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

/*	Notes: Numlock isn't synchronized because Apple keyboards don't use it.
			CapLock needs to be properly synchronized.
*/

#import <Carbon/Carbon.h>

#import <IOKit/hidsystem/IOHIDTypes.h>
#import "ZNLog.h"

#import "CRDKeyboard.h"
#import "CRDSession.h"
#import "CRDSwappedModifiersUtility.h"
#import "rdesktop.h"
#import "CRDShared.h"

#define KEYMAP_ENTRY(n) [[virtualKeymap objectForKey:[NSNumber numberWithInt:(n)]] intValue]
#define SET_KEYMAP_ENTRY(n, v) [virtualKeymap setObject:[NSNumber numberWithInt:(v)] forKey:[NSNumber numberWithInt:(n)]]
#define GET_MODIFIER_FLAGS(f) (CRDPreferenceIsEnabled(CRDPrefsIgnoreCustomModifiers) ? [CRDSwappedModifiersUtility physicalModifiersForVirtualFlags:f] : f )


static NSDictionary *windowsKeymapTable = nil;

@interface CRDKeyboard (Private)
	- (BOOL)readKeymap;
	- (BOOL)scancodeIsModifier:(uint8)scancode;
	- (void)setRemoteModifiers:(unsigned)newMods;
@end

#pragma mark -

@implementation CRDKeyboard

- (id) init
{
	if (![super init])
		return nil;
	
	virtualKeymap = [[NSMutableDictionary alloc] init];
	
	[self readKeymap];		
	
	return self;
}

- (void)dealloc
{
	[virtualKeymap release];
	[super dealloc];
}


#pragma mark -
#pragma mark Key event handling
- (void)handleKeyEvent:(NSEvent *)ev keyDown:(BOOL)down
{
	uint16 rdflags = [CRDKeyboard modifiersForEvent:ev];
	uint16 keycode = [ev keyCode];
	
	DEBUG_KEYBOARD( (@"handleKeyEvent: virtual key 0x%x %spressed", keycode, (down) ? "" : "de") );
	
	[self setRemoteModifiers:GET_MODIFIER_FLAGS([ev modifierFlags])];
	[self sendKeycode:keycode modifiers:rdflags pressed:down];
}

- (void)handleFlagsChanged:(NSEvent *)ev
{
	DEBUG_KEYBOARD( (@"handleFlagsChanged entered") );
	
	// Filter KeyDown events for the Windows key, instead, send both on key up
	static int windowsKeySuppressed = 0;
	unsigned newMods = GET_MODIFIER_FLAGS([ev modifierFlags]);
	
	if ( (newMods & NSCommandKeyMask) && !(remoteModifiers & NSCommandKeyMask) )
	{
		// suppress keydown event for windows key
		newMods &= !NSCommandKeyMask;
		windowsKeySuppressed = 1;
		DEBUG_KEYBOARD( (@"Supressing windows key") );
	}
	else if ( !(newMods & NSCommandKeyMask) && (windowsKeySuppressed || (remoteModifiers & NSCommandKeyMask)) )
	{
		DEBUG_KEYBOARD( (@"Sending previously suppressed windows keystroke") );
		if ( !(remoteModifiers & NSCommandKeyMask))
			[self sendScancode:SCANCODE_CHAR_LWIN flags:RDP_KEYPRESS];
		[self sendScancode:SCANCODE_CHAR_LWIN flags:RDP_KEYRELEASE];
		windowsKeySuppressed = 0;
		remoteModifiers &= !NSCommandKeyMask;
		return;
	}
	
	[self setRemoteModifiers:newMods];
}


#pragma mark -
#pragma mark Sending events to server

- (void)sendKeycode:(uint8)keyCode modifiers:(uint16)rdflags pressed:(BOOL)down
{
	if ([virtualKeymap objectForKey:[NSNumber numberWithInt:keyCode]] != nil)
	{
		if (down)
			[self sendScancode:KEYMAP_ENTRY(keyCode) flags:(rdflags | RDP_KEYPRESS)];
		else
			[self sendScancode:KEYMAP_ENTRY(keyCode) flags:(rdflags | RDP_KEYRELEASE)];
			
		return;
	}
}

- (void)sendScancode:(uint8)scancode flags:(uint16)flags
{
	if ( ((scancode == SCANCODE_CHAR_LWIN) || (scancode == SCANCODE_CHAR_RWIN)) &&
		!CRDPreferenceIsEnabled(CRDDefaultsSendWindowsKey))
	{
		return;
	}
	
	if (scancode & SCANCODE_EXTENDED)
	{
		DEBUG_KEYBOARD((@"Sending extended scancode=0x%x, flags=0x%x\n", scancode & ~SCANCODE_EXTENDED, flags));
		[controller sendInputOnConnectionThread:time(NULL) type:RDP_INPUT_SCANCODE flags:(flags | KBD_FLAG_EXT) param1:(scancode & ~SCANCODE_EXTENDED) param2:0];
	}
	else
	{
		DEBUG_KEYBOARD( (@"Sending scancode=0x%x flags=0x%x", scancode, flags) );
		[controller sendInputOnConnectionThread:time(NULL) type:RDP_INPUT_SCANCODE flags:flags param1:scancode param2:0];
	}
}

#pragma mark -
#pragma mark Internal use

- (void)setRemoteModifiers:(unsigned)newMods
{
	unsigned changedMods = newMods ^ remoteModifiers;
	BOOL keySent;
		
	#define UP_OR_DOWN(b) ( (b) ? RDP_KEYPRESS : RDP_KEYRELEASE )
	
	// keySent is used because some older keyboards may not specify right or left. I don't know if it is actually needed.
	
	// Shift key
	if ( (keySent = changedMods & NX_DEVICELSHIFTKEYMASK) )
		[self sendScancode:SCANCODE_CHAR_LSHIFT flags:UP_OR_DOWN(newMods & NX_DEVICELSHIFTKEYMASK)];
	else if ( (keySent |= changedMods & NX_DEVICERSHIFTKEYMASK) )
		[self sendScancode:SCANCODE_CHAR_RSHIFT flags:UP_OR_DOWN(newMods & NX_DEVICERSHIFTKEYMASK)];

	if (!keySent && (changedMods & NSShiftKeyMask))
		[self sendScancode:SCANCODE_CHAR_LSHIFT flags:UP_OR_DOWN(newMods & NSShiftKeyMask)];


	// Control key
	if ( (keySent = changedMods & NX_DEVICELCTLKEYMASK) )
		[self sendScancode:SCANCODE_CHAR_LCTRL flags:UP_OR_DOWN(newMods & NX_DEVICELCTLKEYMASK)];
	else if ( (keySent = changedMods & NX_DEVICERCTLKEYMASK) )
		[self sendScancode:SCANCODE_CHAR_RCTRL flags:UP_OR_DOWN(newMods & NX_DEVICERCTLKEYMASK)];

	if (!keySent && (changedMods & NSControlKeyMask))
		[self sendScancode:SCANCODE_CHAR_LCTRL flags:UP_OR_DOWN(newMods & NSControlKeyMask)];


	// Alt key
	if ( (keySent = changedMods & NX_DEVICELALTKEYMASK) )
		[self sendScancode:SCANCODE_CHAR_LALT flags:UP_OR_DOWN(newMods & NX_DEVICELALTKEYMASK)];
	else if ( (keySent = changedMods & NX_DEVICERALTKEYMASK) )
		[self sendScancode:SCANCODE_CHAR_RALT flags:UP_OR_DOWN(newMods & NX_DEVICERALTKEYMASK)];

	if (!keySent && (changedMods & NSAlternateKeyMask))
		[self sendScancode:SCANCODE_CHAR_LALT flags:UP_OR_DOWN(newMods & NSAlternateKeyMask)];


	// Windows key
	if (changedMods & NSCommandKeyMask)
		[self sendScancode:SCANCODE_CHAR_LWIN flags:UP_OR_DOWN(newMods & NSCommandKeyMask)];


	// Caps lock, for which flagsChanged is only raised once
	if (changedMods & NSAlphaShiftKeyMask)
	{
		[self sendScancode:SCANCODE_CHAR_CAPSLOCK flags:RDP_KEYPRESS];
		[self sendScancode:SCANCODE_CHAR_CAPSLOCK flags:RDP_KEYRELEASE];
	}

   remoteModifiers = newMods;

   #undef UP_OR_DOWN(x)
}


#pragma mark -
#pragma mark Accessors
- (CRDSession *)controller
{
	return controller;
}

- (void)setController:(CRDSession *)cont
{
	controller = cont;
}


#pragma mark -
#pragma mark Keymap file parser
- (BOOL)readKeymap
{
	NSString *filePath = [[NSBundle mainBundle] pathForResource:@"keymap" ofType:@"txt"];
	NSArray *fileLines = [[NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:NULL] componentsSeparatedByString:@"\n"];
		
	NSCharacterSet *whiteAndHashSet  = [NSCharacterSet characterSetWithCharactersInString:@" \t#"];
	NSScanner *scanner;
	NSString *directive;
	unsigned int osxVKValue, scancode;
		
	signed lineNumber = -1;
	BOOL b = YES;
	id line;
	NSEnumerator *enumerator = [fileLines objectEnumerator];
		
	while ( (line = [enumerator nextObject]) )
	{
		lineNumber++;
		
		if (!b)
			DEBUG_KEYBOARD( (@"Uncaught keymap syntax error at line %d. Ignoring.", lineNumber - 1) );

		scanner = [NSScanner scannerWithString:line];
		b = YES;
	
		if (![scanner scanUpToCharactersFromSet:whiteAndHashSet intoString:&directive])
			continue;
		
		if ([directive isEqualToString:@"virt"])
		{
			// Virtual mapping
			b &= [scanner scanHexInt:&osxVKValue];
			b &= [scanner scanHexInt:&scancode];
			
			if (b)
				SET_KEYMAP_ENTRY(osxVKValue, scancode);
		}	
	}
	
	
	// Some manual mappings for different types of physical keyboards
	PhysicalKeyboardLayoutType physicalKeyboardType = KBGetLayoutType(LMGetKbdType());

	switch (physicalKeyboardType)
	{
		case kKeyboardISO:
			DEBUG_KEYBOARD( (@"Enabling hacks for European keyboard") );
			SET_KEYMAP_ENTRY(0x32, 0x56);
			break;
				
		default:
			break;
	}
	
	return YES;
}


#pragma mark Class methods

// This method isn't fully re-entrant but shouldn't be a problem in practice
+ (unsigned)windowsKeymapForMacKeymap:(NSString *)keymapName
{
	DEBUG_KEYBOARD((@"Loading windows keymap for %@", keymapName));
	// Load 'OSX keymap name' --> 'Windows keymap number' lookup table if it isn't already loaded
	if (windowsKeymapTable == nil)
	{
		NSMutableDictionary *dict = [[NSMutableDictionary dictionaryWithCapacity:30] retain];
		NSString *filename = [[NSBundle mainBundle] pathForResource:@"windows_keymap_table" ofType:@"txt"];
		NSArray *lines = [[NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:NULL] componentsSeparatedByString:@"\n"];
		NSScanner *scanner;
		NSString *n;
		unsigned i;
		
		id line;
		NSEnumerator *enumerator = [lines objectEnumerator];
		while ( (line = [enumerator nextObject]) )
		{
			line = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			scanner = [NSScanner scannerWithString:line];
			[scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"="]];
			[scanner scanUpToString:@"=" intoString:&n];
			[scanner scanHexInt:&i];
			
			if (i != 0 && n != nil)
			{
				[dict setObject:[NSNumber numberWithUnsignedInt:i] forKey:n];
			}
		}
		windowsKeymapTable = dict;
	}
	
	
	/* First, look up directly in the table. If not found, try a fuzzy match
		so that input types like "Arabic-QWERTY" will match "Arabic". Finally, 
		if an appropriate keymap isn't found either way, use US keymap as default.
	*/
	
	NSNumber *windowsKeymap = [windowsKeymapTable objectForKey:keymapName];
	
	if (!windowsKeymap)
	{
		NSString *prefix;
		
		id potentialKeymapName;
		NSEnumerator *enumerator = [[windowsKeymapTable allKeys] objectEnumerator];
		
		while ( (potentialKeymapName = [enumerator nextObject]) )
		{
			prefix = [keymapName commonPrefixWithString:potentialKeymapName options:NSLiteralSearch];
			if ([prefix length] >= 4)
			{ 
				windowsKeymap = [windowsKeymapTable objectForKey:potentialKeymapName];
				DEBUG_KEYBOARD( (@"windowsKeymapForMacKeymap: substituting keymap '%@' for passed '%@', giving Windows keymap '%x'", potentialKeymapName, keymapName, [windowsKeymap intValue]));
				break;
			}
		}
	}
	
	if (windowsKeymap)
		DEBUG_KEYBOARD( (@"Setting remote keymap to %@ (int value: %d)", keymapName, [windowsKeymap unsignedIntValue]) );
	else
		DEBUG_KEYBOARD( (@"Using default American keyboard layout") );
		
	return (!windowsKeymap) ? 0x409 : [windowsKeymap unsignedIntValue];
}

+ (NSString *) currentKeymapName
{
	TISInputSourceRef keyLayout;
	keyLayout = TISCopyCurrentKeyboardInputSource();
	return (NSString*)TISGetInputSourceProperty(keyLayout, kTISPropertyInputSourceID);
}

+ (uint16)modifiersForEvent:(NSEvent *)ev
{
	unsigned int eventFlags = [ev modifierFlags];
	uint16 rdFlags = 0;
	
	// Unless if a system to ensure modifiers qre correct before keypresses is added, this is uneeded
	//if (eventFlags & NSAlphaShiftKeyMask)
	// 	MASK_CHANGE_BIT(rdFlags, MapCapsLockMask, 1);
	
	if (eventFlags & NX_DEVICELSHIFTKEYMASK)
		MASK_CHANGE_BIT(rdFlags, MapLeftShiftMask, 1);
	
	if (eventFlags & NX_DEVICERSHIFTKEYMASK)
		MASK_CHANGE_BIT(rdFlags, MapLeftShiftMask, 1);

	if (eventFlags & NSControlKeyMask)
		MASK_CHANGE_BIT(rdFlags, MapLeftCtrlMask, 1);
	
	if (eventFlags & NX_DEVICELALTKEYMASK)
		MASK_CHANGE_BIT(rdFlags, MapLeftAltMask, 1);
	
	if (eventFlags & NX_DEVICERALTKEYMASK)
		MASK_CHANGE_BIT(rdFlags, MapRightAltMask, 1);

	if (eventFlags & NSCommandKeyMask)
		MASK_CHANGE_BIT(rdFlags, MapLeftWinMask, 1);

	return rdFlags;
}

@end
