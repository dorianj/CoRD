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

#import "CRDLabelCell.h"

#define PADDING_TOP 4
#define PADDING_LEFT 6
#define PADDING_RIGHT 5
#define PADDING_BOTTOM 5

#define TEXT_COLOR [NSColor colorWithDeviceRed:(120/255.0) green:(120/255.0) blue:(135/255.0) alpha:1.0]
#define TEXT_SIZE 11.0

static NSDictionary *textAttributes;

@implementation CRDLabelCell

- (id) initTextCell:(NSString *)text
{
	self = [super initTextCell:text];
	if (self != nil)
	{
		if (textAttributes == nil)
		{
			textAttributes = [[NSMutableDictionary dictionaryWithObjectsAndKeys:
					TEXT_COLOR, NSForegroundColorAttributeName,
					[NSFont fontWithName:@"LucidaGrande" size:TEXT_SIZE], NSFontAttributeName,
					nil] retain];
		}
	}
	return self;
}


- (NSRect) titleRectForBounds:(NSRect)bounds
{
	NSSize titleSize = [[self title] sizeWithAttributes:textAttributes];
	NSRect titleRect = bounds;
	
	titleRect.origin.x += PADDING_LEFT;
	titleRect.origin.y += PADDING_TOP + (bounds.size.height - titleSize.height) / 2;
	titleRect.size.width -= PADDING_RIGHT;
	titleRect.size.height -= PADDING_BOTTOM;
	
	return titleRect;
}

- (void) drawWithFrame:(NSRect)frame inView:(NSView *)controlView
{
	[[textAttributes objectForKey:NSForegroundColorAttributeName] set];
	[[[self title] capitalizedString] drawInRect:[self titleRectForBounds:frame] withAttributes:textAttributes];
	
}

- (NSSize)cellSize
{
	NSSize s = [[self title] sizeWithAttributes:textAttributes];
	return NSMakeSize(s.width + PADDING_RIGHT + PADDING_LEFT, s.height + PADDING_BOTTOM + PADDING_TOP);
}

@end
