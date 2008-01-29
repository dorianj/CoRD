/*	Copyright (c) 2008 Dorian Johnson <info-2008@dorianjohnson.com>
	
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

#import "CRDAdditions.h"

@implementation NSView (CRDAdditions)

- (NSImage *)cacheDisplayInRectAsImage:(NSRect)rect
{
	NSBitmapImageRep *imageRep = [self bitmapImageRepForCachingDisplayInRect:rect];
	[self cacheDisplayInRect:rect toBitmapImageRep:imageRep];
	NSImage *img = [[[NSImage alloc] initWithSize:rect.size] autorelease];
	[img addRepresentation:imageRep];
	
	
/*

	NSEnumerator *enumerator = [[self subviews] objectEnumerator];
	NSView *childView;
	
	while ( (childView = [enumerator nextObject]) )
	{
		NSImage *cachedChildView = [childView cacheDisplayInRectAsImage:[childView visibleRect]];
		
		[img lockFocus]; {
			NSLog(@"drawing %@, Orig: %@, translated: %@", childView, NSStringFromPoint([childView frame].origin), NSStringFromPoint([self convertPoint:[childView frame].origin fromView:nil]));
			//[cachedChildView setFlipped:[childView isFlipped]];
			[cachedChildView drawAtPoint:[self convertPoint:[childView frame].origin fromView:nil] fromRect:(NSRect){NSZeroPoint, [cachedChildView size]} operation:NSCompositeSourceOver fraction:1.0];		
		} [img unlockFocus];
	}
	
	[[img TIFFRepresentation] writeToFile:@"/users/dorian/desktop/bah.tif" atomically:YES];
	*/
	return img;
}

@end
