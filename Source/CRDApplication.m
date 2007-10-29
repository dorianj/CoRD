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

// Purpose: Subclass of NSApplication so that command+key can be interpreted
//			as windows+key and sent to server. Additionally, the mouse is tracked
//			to allow the menu bar to be unhidden during fullscreeen

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
	BOOL viewIsFocused = (v != nil) && [[v window] isKeyWindow] && [[v window] isMainWindow] && 
			([[v window] firstResponder] == v);
	NSEventType eventType = [ev type];
	
	switch (eventType)
	{
		case NSKeyDown:	
			if (viewIsFocused)
			{
				if (![[self menu] performKeyEquivalent:ev])
					[v keyDown:ev];
				
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
			
		default:
			break;
	}
	
	
    [super sendEvent:ev];
}


@end
