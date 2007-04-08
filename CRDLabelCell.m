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
