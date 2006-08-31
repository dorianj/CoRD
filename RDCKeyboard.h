//
//  RDCKeyboard.h
//  Xrdc
//
//  Created by Craig Dooley on 8/15/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface RDCKeyboard : NSObject {
	NSMutableDictionary *keymap;
}

+ (RDCKeyboard *)shared;
+ (int)NSEventToRDModifiers:(NSEvent *)ev;
- (int)scancodeForKeycode:(int)keyCode;
- (void)readKeymap;
@end
