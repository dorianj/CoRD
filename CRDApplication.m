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

// Notes: 

#import "CRDApplication.h"

#import "AppController.h"
#import "RDInstance.h"
#import "RDCView.h"
#import "CRDFullScreenWindow.h"

@implementation CRDApplication

- (void)sendEvent:(NSEvent *)ev
{
	// This could be optimized by lazy checking of viewIsFocused, and v and/or changing
	//	some to use IB connections
	CRDFullScreenWindow *fullScreenWindow = [g_appController fullScreenWindow];
	RDInstance *inst = [g_appController viewedServer];
	RDCView *v = [inst view];
	BOOL viewIsFocused = v != nil && [g_appController mainWindowIsFocused] && 
			([[g_appController unifiedWindow] firstResponder] == v);
	NSEventType eventType = [ev type];
	
	switch (eventType)
	{
		case NSKeyDown:	
			if (viewIsFocused)
			{
				[v keyDown:ev];
				if ([[self menu] performKeyEquivalent:ev])
				{
					[v keyUp:ev];
					
					// Release all of the modifiers as well, as the flagsChanged event releasing them won't fire
					NSEvent *releaseModsEv = [NSEvent keyEventWithType:NSFlagsChanged location:[ev locationInWindow]
								modifierFlags:![ev modifierFlags] timestamp:[ev timestamp] windowNumber:0 context:nil characters:@""
								charactersIgnoringModifiers:@"" isARepeat:NO keyCode:[ev keyCode]];
					[v flagsChanged:releaseModsEv];
				}
				
				return;
			}
			break;
			
		case NSKeyUp:
			if (viewIsFocused)
			{
				[v keyUp:ev];
				return;
			}
			
			break;
			
		case NSFlagsChanged:
			if (viewIsFocused)
			{
				[v flagsChanged:ev];
				return;
			}
			break;
			
		case NSMouseMoved:
			if ([g_appController displayMode] == CRDDisplayFullscreen &&
				([fullScreenWindow pointIsInMouseHotSpot:[fullScreenWindow mouseLocationOutsideOfEventStream]] ||
				[fullScreenWindow menuVisible]) )
			{
				[fullScreenWindow mouseMoved:ev];
				return;
			}
			
			break;
		default:
			break;
	}
	
	
    [super sendEvent:ev];
}


@end
