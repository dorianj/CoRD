/*	Copyright (c) 2007-2011 Dorian Johnson <2011@dorianj.net>
	
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

/*	Purpose: Changes modifiers from a flagsChanged event into the physical keyboard modifiers, according to the keys the user has changed in System Preferences
	Notes: This class is fully thread-safe because only class methods are used.
		I'm currently trying to get it to stay in sync with user defaults without calling -[NSUserDefaults synchronize] each time. I can't find a way to use KVO - NSUserDefaultsController refuses to addObserver for com.apple.keyboard.modifiermapping and NSUserDefaults doesn't ever inform us of changes
	Modifier key codes:
		*  None: -1
		* Caps Lock: 0
		* Left Shift: 1
		* Left Control: 2
		* Left Option: 3
		* Left Command: 4
		* Keypad 0: 5
		* Help: 6
		* Right Shift: 9
		* Right Control: 10
		* Right Option: 11
		* Right Command: 12
*/

#import "CRDSwappedModifiersUtility.h"
#import "IOKit/hidsystem/IOLLEvent.h"

// Constants
static NSString * const SwappedModifiersRootKey = @"com.apple.keyboard.modifiermapping";
static NSString * const SwappedModifiersSourceKey = @"HIDKeyboardModifierMappingSrc";
static NSString * const SwappedModifiersDestinationKey = @"HIDKeyboardModifierMappingDst";
static NSString * const KeyFlagRight = @"KeyFlagRight";
static NSString * const KeyFlagLeft = @"KeyFlagLeft";
static NSString * const KeyFlagDeviceIndependent = @"KeyFlagDeviceIndependent";

typedef enum _CRDSwappedModifiersKeyCode
{
	CRDSwappedModifiersCapsLockKey = 0,
	CRDSwappedModifiersShiftKey = 9,
	CRDSwappedModifiersControlKey = 10,
	CRDSwappedModifiersOptionKey = 11,
	CRDSwappedModifiersCommandKey = 12
} CRDSwappedModifiersKeyCode;

// Convenience macros
#define MakeNum(n) [NSNumber numberWithInt:(n)]
#define MakeInt(num) [num intValue]
#define GetFlagForKey(keyNum, flag) MakeInt([[keyFlagTable objectForKey:MakeNum(keyNum)] objectForKey:flag])

static CRDSwappedModifiersUtility *sharedInstance;
static NSDictionary *keyFlagTable, *modifierTranslator, *keyDisplayNames;
static NSArray *rawDefaultTable;


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
			CREATE_KEY_FLAG(NX_DEVICERSHIFTKEYMASK, NX_DEVICELSHIFTKEYMASK, NSShiftKeyMask), MakeNum(CRDSwappedModifiersShiftKey),
			nil] retain];
	
	// Just for debug purposes
	keyDisplayNames =  [[NSDictionary dictionaryWithObjectsAndKeys:
			@"Caps Lock", MakeNum(CRDSwappedModifiersCapsLockKey),
			@"Control", MakeNum(CRDSwappedModifiersControlKey),
			@"Option", MakeNum(CRDSwappedModifiersOptionKey),
			@"Command", MakeNum(CRDSwappedModifiersCommandKey),
			@"Shift", MakeNum(CRDSwappedModifiersShiftKey),
			nil] retain];
		
	// xxx: doesn't actually inform us of changes
	[[NSUserDefaults standardUserDefaults] addObserver:[[[CRDSwappedModifiersUtility alloc] init] autorelease] forKeyPath:SwappedModifiersRootKey options:0 context:NULL];	
	[CRDSwappedModifiersUtility loadStandardTranslation];
}

+ (void)loadStandardTranslation
{
	NSMutableDictionary *modifiersBuilder = [[NSMutableDictionary alloc] initWithCapacity:4];
	NSArray *userDefaultTable = nil;
	
	[[NSUserDefaults standardUserDefaults] synchronize];
	userDefaultTable = [[NSUserDefaults standardUserDefaults] objectForKey:SwappedModifiersRootKey];

	if ( (userDefaultTable != nil) && ![userDefaultTable isEqualToArray:rawDefaultTable])
	{		
		[rawDefaultTable release];
		rawDefaultTable = [userDefaultTable retain];
		
		id item;
		for ( item in rawDefaultTable )
		{
			[modifiersBuilder setObject:[item objectForKey:SwappedModifiersDestinationKey] forKey:[item objectForKey:SwappedModifiersSourceKey]];	
		}
	}
	
	if ([modifiersBuilder count] == 0)
	{
		[modifiersBuilder setObject:MakeNum(CRDSwappedModifiersCapsLockKey) forKey:MakeNum(CRDSwappedModifiersCapsLockKey)];
		[modifiersBuilder setObject:MakeNum(CRDSwappedModifiersControlKey) forKey:MakeNum(CRDSwappedModifiersControlKey)];
		[modifiersBuilder setObject:MakeNum(CRDSwappedModifiersOptionKey) forKey:MakeNum(CRDSwappedModifiersOptionKey)];
		[modifiersBuilder setObject:MakeNum(CRDSwappedModifiersCommandKey) forKey:MakeNum(CRDSwappedModifiersCommandKey)];
		[modifiersBuilder setObject:MakeNum(CRDSwappedModifiersShiftKey) forKey:MakeNum(CRDSwappedModifiersShiftKey)];
	}
	
	[modifierTranslator release];
	modifierTranslator = modifiersBuilder;
}

+ (unsigned)physicalModifiersForVirtualFlags:(unsigned)flags
{	
	[CRDSwappedModifiersUtility loadStandardTranslation];

	#define TEST_THEN_SWAP(realKeyFlag, virtKeyFlag) if (flags & virtKeyFlag) newFlags |= realKeyFlag;
	//	CRDLog(CRDLogLevelInfo, @"Swapping? %s", (flags & virtKeyFlag) ? "Yes." : "No.");

	int keys[5] = {CRDSwappedModifiersCapsLockKey, CRDSwappedModifiersControlKey, CRDSwappedModifiersOptionKey, CRDSwappedModifiersCommandKey, CRDSwappedModifiersShiftKey};
	unsigned newFlags = 0, i, realKeyNum;
	
	for (i = 0; i < 5; i++)
	{	
		realKeyNum = MakeInt([modifierTranslator objectForKey:MakeNum(keys[i])]);
		TEST_THEN_SWAP(GetFlagForKey(keys[i], KeyFlagRight), GetFlagForKey(realKeyNum, KeyFlagRight));
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




- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:SwappedModifiersRootKey])
	{
		[CRDSwappedModifiersUtility loadStandardTranslation];
    }
}

@end
