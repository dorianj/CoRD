//  Copyright (c) 2007 Dorian Johnson <arcadiclife@gmail.com>, Craig Dooley <xlnxminusx@gmail.com>
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

#import <IOKit/hidsystem/IOHIDTypes.h>

#import "RDCKeyboard.h"
#import "RDInstance.h"
#import "rdesktop.h"
#import "scancodes.h"
#import "miscellany.h"

#define KEYMAP_ENTRY(n) [[virtualKeymap objectForKey:[NSNumber numberWithInt:(n)]] intValue]
#define SET_KEYMAP_ENTRY(n, v) [virtualKeymap setObject:[NSNumber numberWithInt:(v)] forKey:[NSNumber numberWithInt:(n)]]

// Static class variables
static NSDictionary *isoNameTable = nil;

@interface RDCKeyboard (Private)
	- (BOOL)parse_readKeymap;
	- (BOOL)scancodeIsModifier:(uint8)scancode;
@end

#pragma mark -

@implementation RDCKeyboard

#pragma mark NSObject methods
- (id) init
{
	if (![super init])
		return nil;
	
	virtualKeymap = [[NSMutableDictionary alloc] init];
	
	[self parse_readKeymap];		
	
	return self;
}

- (void)dealloc
{
	[virtualKeymap release];
	[isoNameTable release];
	[super dealloc];
}


#pragma mark Key event handling
- (void)handleKeyEvent:(NSEvent *)ev keyDown:(BOOL)down
{
	uint16 rdflags = [RDCKeyboard modifiersForEvent:ev];
	uint16 keycode = [ev keyCode];
	
	DEBUG_KEYBOARD( (@"handleKeyEvent: virtual key 0x%x %spressed", keycode, (down) ? "" : "de") );

	[self sendKeycode:keycode modifiers:rdflags pressed:down];

	DEBUG_KEYBOARD( (@"\n") );
}


- (void)handleFlagsChanged:(NSEvent *)ev
{
	static unsigned lastMods = 0;
	int newMods = [ev modifierFlags], changedMods = newMods ^ lastMods;
	BOOL keySent;
	
	#define UP_OR_DOWN(b) ( (b) ? RDP_KEYPRESS : RDP_KEYRELEASE )
	
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
	if ( (keySent = changedMods & NX_DEVICELCMDKEYMASK) )
		[self sendScancode:SCANCODE_CHAR_LWIN flags:UP_OR_DOWN(newMods & NX_DEVICELCMDKEYMASK)];
	else if ( (keySent = changedMods & NX_DEVICERCMDKEYMASK) )
		[self sendScancode:SCANCODE_CHAR_RWIN flags:UP_OR_DOWN(newMods & NX_DEVICERCMDKEYMASK)];

	if (!keySent && (changedMods & NSCommandKeyMask))
		[self sendScancode:SCANCODE_CHAR_LWIN flags:UP_OR_DOWN(newMods & NSCommandKeyMask)];

   lastMods = newMods;

   #undef UP_OR_DOWN(x)
}

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


// Returns YES if any keys are handled, otherwise NO
- (BOOL) handleSpecialKeys:(NSEvent *)ev
{
	uint16 flags = [RDCKeyboard modifiersForEvent:ev];
	uint16 keycode = [ev keyCode];
	
	/* This may be needed in the future for things like pause/break */
	
	return NO;
}

- (void)sendScancode:(uint8)scancode flags:(uint16)flags
{
	if (scancode & SCANCODE_EXTENDED)
	{
		DEBUG_KEYBOARD((@"Sending extended scancode=0x%x, flags=0x%x\n", scancode & ~SCANCODE_EXTENDED, flags));
		[controller sendInput:RDP_INPUT_SCANCODE flags:(flags | KBD_FLAG_EXT) param1:(scancode & ~SCANCODE_EXTENDED) param2:0];
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
- (BOOL)parse_readKeymap
{
	NSString *filePath = [[NSBundle mainBundle] pathForResource:@"keymap" ofType:@"txt"];
	NSArray *fileLines = [[NSString stringWithContentsOfFile:filePath] componentsSeparatedByString:@"\n"];
		
	NSCharacterSet *whitespaceSet    = [NSCharacterSet whitespaceCharacterSet],
				   *whiteAndHashSet  = [NSCharacterSet characterSetWithCharactersInString:@" \t#"];
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
			DEBUG_KEYBOARD( (@"Uncaught keymap syntax at line %d. Ignoring.", lineNumber - 1) );

		scanner = [NSScanner scannerWithString:line];
		b = YES;
	
		if (![scanner scanUpToCharactersFromSet:whiteAndHashSet intoString:&directive])
			continue;
		
		if ([directive isEqualToString:@"virt"])
		{
			// Virtual mapping
			b &= [scanner scanHexInt:&osxVKValue];
			b &= [scanner scanHexInt:&scancode];
			
			if (b && osxVKValue)
				SET_KEYMAP_ENTRY(osxVKValue, scancode);
		}	
	}
	
	return YES;
}


#pragma mark Class methods
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

@end
