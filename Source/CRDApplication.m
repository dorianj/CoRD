/*	Copyright (c) 2007 Dorian Johnson <arcadiclife@gmail.com>, 2007-2008 Dorian Johnson <info-2008@dorianjohnson.com>
	
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

// Purpose: Subclass of NSApplication so that command+key can be interpreted as windows+key and sent to server.

#import "CRDApplication.h"

#import "AppController.h"
#import "CRDSession.h"
#import "CRDSessionView.h"

@implementation CRDApplication

- (void)sendEvent:(NSEvent *)ev
{
	if ( ([ev type] == NSKeyDown) && [[self menu] performKeyEquivalent:ev])
		return;
		
	NSResponder *forwardEventTo = ([[self delegate] application:self shouldForwardEvent:ev]);
	
	if ( (forwardEventTo != nil) && [forwardEventTo tryToPerform:[CRDApplication selectorForEvent:ev] with:ev])
		return;

	[super sendEvent:ev];
}


+ (SEL)selectorForEvent:(NSEvent *)ev
{
	switch ([ev type])
	{
		case NSKeyDown:	
			return @selector(keyDown:);

		case NSKeyUp:
			return @selector(keyUp:);

		case NSFlagsChanged:
			return @selector(flagsChanged:);
			
		default:
			return NULL;
	}
}

@end
