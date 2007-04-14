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

// Purpose: Subclass of NSApplication so that command+key can be interpreted
//			as windows+key and sent to server. This will be enabled in the furture,
//			some RDCKeyboard modifications are needed and this is low priority

#import "CRDApplication.h"

#import "AppController.h"
#import "RDInstance.h"
#import "RDCView.h"

@implementation CRDApplication

- (void)sendEvent:(NSEvent *)ev
{
	
	RDCView *v = [[g_appController viewedServer] view];
	BOOL viewIsFocused = v != nil && [g_appController mainWindowIsFocused] && 
			([[g_appController valueForKey:@"gui_mainWindow"] firstResponder] == v);
			
	if (viewIsFocused)
	{
		switch ([ev type])
		{
			case NSKeyDown:
				// Catch fullscreen command
				if ([ev keyCode] == 0x24 && ([ev modifierFlags] &  NSCommandKeyMask) && ([ev modifierFlags] & NSAlternateKeyMask))
					break;
			
				// This functionality can be unintuitive and should only be used if 
				//	there's a user-settable way to control it
				//if (![[self menu] performKeyEquivalent:ev])
				
				[v keyDown:ev];
				
				return;
				
			case NSKeyUp:
				[v keyUp:ev];
				return;
				
			case NSFlagsChanged:
				[v flagsChanged:ev];
				return;
						
			default:
				break;
		}
	}
	
    [super sendEvent:ev];
}


@end
