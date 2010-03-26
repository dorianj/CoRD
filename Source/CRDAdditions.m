/*	Copyright (c) 2008-2010 Dorian Johnson <2010@dorianj.net>
	
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
#import "CRDShared.h"

@implementation NSView (CRDAdditions)

- (NSImage *)cacheDisplayInRectAsImage:(NSRect)rect
{
	NSBitmapImageRep *imageRep = [self bitmapImageRepForCachingDisplayInRect:rect];
	[self cacheDisplayInRect:rect toBitmapImageRep:imageRep];
	NSImage *img = [[[NSImage alloc] initWithSize:rect.size] autorelease];
	[img addRepresentation:imageRep];
	
	// code that enumerates through children is in svn revision 210
	return img;
}

@end

#pragma mark -

@implementation NSString (CRDAdditions)

- (NSString *)stringByDeletingCharactersInSet:(NSCharacterSet *)characterSet
{
	NSMutableString *cleanedString = [[self mutableCopy] autorelease];
	for (int i = 0; i < [cleanedString length]; )
	{
		if ([characterSet characterIsMember:[cleanedString characterAtIndex:i]])
			[cleanedString deleteCharactersInRange:NSMakeRange(i, 1)];
		else
			i++;
	}

	return cleanedString;
}

- (NSString *)stringByDeletingFileSystemCharacters
{
	return [self stringByDeletingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/~:"]];
}

- (NSString *)lowercaseFirst
{
	if (![self length])
		return @"";

	NSMutableString *resultantString = [[self mutableCopy] autorelease];
	[resultantString replaceCharactersInRange:NSMakeRange(0, 1) withString:[[self substringToIndex:1] lowercaseString]];
	return resultantString;
}

- (NSComparisonResult)compareScreenResolution:(NSString*)otherResolution
{
	NSString *resolution1 = self, *resolution2 = otherResolution;
	NSInteger w1, h1, w2, h2;
	BOOL fullscreen1, fullscreen2;

	fullscreen1 = CRDResolutionStringIsFullscreen(resolution1);
	fullscreen2 = CRDResolutionStringIsFullscreen(resolution2);
	
	if (fullscreen1 && fullscreen2)
		return NSOrderedSame;
	if (fullscreen1 && !fullscreen2)
		return NSOrderedAscending;
	if (!fullscreen1 && fullscreen2)
		return NSOrderedDescending;
	
	CRDSplitResolutionString(resolution1, &w1, &h1);
	CRDSplitResolutionString(resolution2, &w2, &h2);
	
	if (w1 == w2 && h1 == h2)
		return NSOrderedSame;
	
	if (w1 > w2)
		return NSOrderedDescending;
	
	if (w1 < w2)
		return NSOrderedAscending;
	
	return (h1 > h2) ? NSOrderedDescending : NSOrderedAscending;
}


- (NSString *)strip
{
	return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end

#pragma mark -

@implementation NSTableView (CRDAdditions)
- (void)editSelectedRow:(NSNumber *)column
{
	NSInteger columnIndex = (column) ? [column integerValue] : 0;
	[self editColumn:columnIndex row:[self selectedRow] withEvent:nil select:YES];
}

@end