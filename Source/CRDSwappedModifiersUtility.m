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

/*	Purpose: Changes modifiers from a flagsChanged event into the physical keyboard modifiers, according to they keys the user has changed in System Preferences
	Notes: This class is fully thread-safe because only class methods are used.
*/

#import "CRDSwappedModifiersUtility.h"
#import "IOKit/hidsystem/IOLLEvent.h"

// Constants
static NSString *SwappedModifiersRootKey = @"com.apple.keyboard.modifiermapping";
static NSString *SwappedModifiersSourceKey = @"HIDKeyboardModifierMappingSrc";
static NSString *SwappedModifiersDestinationKey = @"HIDKeyboardModifierMappingDst";
static NSString *KeyFlagRight = @"KeyFlagRight";
static NSString *KeyFlagLeft = @"KeyFlagLeft";
static NSString *KeyFlagDeviceIndependent = @"KeyFlagDeviceIndependent";

typedef enum _CRDSwappedModifiersKeyCode
{
	CRDSwappedModifiersCapsLockKey = 0,
	CRDSwappedModifiersControlKey = 10,
	CRDSwappedModifiersOptionKey = 11,
	CRDSwappedModifiersCommandKey = 12
} CRDSwappedModifiersKeyCode;

// Convenience macros
#define MakeNum(n) [NSNumber numberWithInt:(n)]
#define MakeInt(num) [num intValue]
#define GetFlagForKey(keyNum, flag) MakeInt([[keyFlagTable objectForKey:MakeNum(keyNum)] objectForKey:flag])


static NSLock *keyTranslatorLock;
static NSDictionary *keyFlagTable, *modifierTranslator, *keyDisplayNames;


#define KEY_NAMED(n) [keyDisplayNames objectForKey:MakeNum(n)]

@implementation CRDSwappedModifiersUtility

+ (void)initialize
{
	#define CREATE_KEY_FLAG(r, l, di) \
		[NSDictionary dictionaryWithObjectsAndKeys:MakeNum(r), KeyFlagRight, MakeNum(l), KeyFlagLeft, MakeNum(di), KeyFlagDeviceIndependent, nil]
		
	keyFlagTable = [[NSDictionary dictionaryWithObjectsAndKeys:
			CREATE_KEY_FLAG(0, 0, NSAlphaShiftKeyMask), MakeNum(CRDSwappedModifiersCapsLockKey),
			CREATE_KEY_FLAG(NX_DEVICERCTLKEYMASK, NX_DEVICELCTLKEYMASK, NSControlKeyMask), MakeNum(CRDSwappedModifiersControlKey),
			CREATE_KEY_FLAG(NX_DEVICERALTKEYMASK, NX_DEVICELALTKEYMASK, NSAlternateKeyMask), MakeNum(CRDSwappedModifiersOptionKey),
			CREATE_KEY_FLAG(NX_DEVICERCMDKEYMASK, NX_DEVICELCMDKEYMASK, NSCommandKeyMask), MakeNum(CRDSwappedModifiersCommandKey),
			nil] retain];
	
	keyDisplayNames =  [[NSDictionary dictionaryWithObjectsAndKeys:
			@"Caps Lock", MakeNum(CRDSwappedModifiersCapsLockKey),
			@"Control", MakeNum(CRDSwappedModifiersControlKey),
			@"Option", MakeNum(CRDSwappedModifiersOptionKey),
			@"Command", MakeNum(CRDSwappedModifiersCommandKey),
			nil] retain];
			
	[CRDSwappedModifiersUtility loadStandardTranslation];
}


+ (void)loadStandardTranslation
{
	NSMutableDictionary *modifiersBuilder = [[NSMutableDictionary alloc] initWithCapacity:4];
	NSDictionary *rawTable = nil;
	
	if (![CRDSwappedModifiersUtility modifiersAreSwapped])
	{
		// Load default table
		[modifiersBuilder setObject:MakeNum(CRDSwappedModifiersCapsLockKey) forKey:MakeNum(CRDSwappedModifiersCapsLockKey)];
		[modifiersBuilder setObject:MakeNum(CRDSwappedModifiersControlKey) forKey:MakeNum(CRDSwappedModifiersControlKey)];
		[modifiersBuilder setObject:MakeNum(CRDSwappedModifiersOptionKey) forKey:MakeNum(CRDSwappedModifiersOptionKey)];
		[modifiersBuilder setObject:MakeNum(CRDSwappedModifiersCommandKey) forKey:MakeNum(CRDSwappedModifiersCommandKey)];
	}
	else
	{
		// Load Apple table from user defaults
		rawTable = [[NSUserDefaults standardUserDefaults] objectForKey:SwappedModifiersRootKey];
		
		NSEnumerator *enumerator = [rawTable objectEnumerator];
		id item;
		while ( (item = [enumerator nextObject]) )
		{
			[modifiersBuilder setObject:[item objectForKey:SwappedModifiersDestinationKey] forKey:[item objectForKey:SwappedModifiersSourceKey]];	
		}
	}
	
	[modifierTranslator release];
	modifierTranslator = modifiersBuilder;
}

+ (unsigned)physicalModifiersForVirtualFlags:(unsigned)flags
{	
	#define TEST_THEN_SWAP(realKeyFlag, virtKeyFlag) if (flags & virtKeyFlag) newFlags |= realKeyFlag;
	//	NSLog(@"Swapping? %s", (flags & virtKeyFlag) ? "Yes." : "No.");

	int keys[4] = {CRDSwappedModifiersCapsLockKey, CRDSwappedModifiersControlKey, CRDSwappedModifiersOptionKey, CRDSwappedModifiersCommandKey};
	unsigned newFlags = 0, i, realKeyNum;
	
	for (i = 0; i < 4; i++)
	{	
		realKeyNum = MakeInt([modifierTranslator objectForKey:MakeNum(keys[i])]);
		TEST_THEN_SWAP(GetFlagForKey(keys[i], KeyFlagLeft), GetFlagForKey(realKeyNum, KeyFlagRight));
		TEST_THEN_SWAP(GetFlagForKey(keys[i], KeyFlagLeft), GetFlagForKey(realKeyNum, KeyFlagLeft));
		TEST_THEN_SWAP(GetFlagForKey(keys[i], KeyFlagDeviceIndependent), GetFlagForKey(realKeyNum, KeyFlagDeviceIndependent));		
	}

	return newFlags;
}

+ (BOOL)modifiersAreSwapped
{
	[[NSUserDefaults standardUserDefaults] synchronize];
	return [[NSUserDefaults standardUserDefaults] objectForKey:SwappedModifiersRootKey] != nil;
}

@end
