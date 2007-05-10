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

/*	Notes:
		- I could have used CoreGraphics for the gradients. Drawing my own was easier.
			It's the same exact result: a calculated gradient.
*/

#import "CRDServerList.h"
#import "miscellany.h"
#import "CRDServerCell.h"
#import "RDInstance.h"

// For mainWindowIsFocused
#import "AppController.h"


// Start is top, end is bottom
#define HIGHLIGHT_START [NSColor colorWithDeviceRed:(66/255.0) green:(154/255.0) blue:(227/255.0) alpha:1.0]
#define HIGHLIGHT_END [NSColor colorWithDeviceRed:(25/255.0) green:(85/255.0) blue:(205/255.0) alpha:1.0]

#define UNFOCUSED_START [NSColor colorWithDeviceRed:(150/255.0) green:(150/255.0) blue:(150/255.0) alpha:1.0]
#define UNFOCUSED_END [NSColor colorWithDeviceRed:(100/255.0) green:(100/255.0) blue:(100/255.0) alpha:1.0]

#define ANIMATION_DURATION 0.18

#pragma mark -

@interface CRDServerList (Private)
	- (BOOL)pasteboardHasValidData:(NSPasteboard *)draggingPasteboard;
	- (void)createNewRowOriginsAboveRow:(int)rowIndex;
	- (void)startAnimation;
	- (void)concludeDrag;
	- (CRDServerCell *)cellForRow:(int)row;
@end


#pragma mark -
@implementation CRDServerList

#pragma mark -
#pragma mark NSTableView

- (void)awakeFromNib
{
	draggedRow = selectedRow = emptyRowIndex = -1;
	[self setVerticalMotionCanBeginDrag:YES];
}

// If this isn't overridden, it won't use the hightlightSelectionInClipRect method
- (id)_highlightColorForCell:(NSCell *)cell
{
	return nil;
}

- (void)highlightSelectionInClipRect:(NSRect)clipRect
{	
	if (selectedRow == -1)
		return;

	NSRect drawRect = [self rectOfRow:selectedRow];
	
	NSColor *topColor, *bottomColor;
	if ([g_appController mainWindowIsFocused] || inLiveDrag)
	{
		topColor = HIGHLIGHT_START;
		bottomColor = HIGHLIGHT_END;
	} else {
		topColor = UNFOCUSED_START;
		bottomColor = UNFOCUSED_END;	
	}
	
	[self lockFocus];	
	NSRectClip(drawRect);
	draw_vertical_gradient(topColor, bottomColor, drawRect);
	draw_line([bottomColor blendedColorWithFraction:0.6 ofColor:topColor], 
			NSMakePoint(drawRect.origin.x, drawRect.origin.y),
			NSMakePoint(drawRect.origin.x + drawRect.size.width, drawRect.origin.y ));
	[self unlockFocus];
}

- (void)drawRow:(int)rowIndex clipRect:(NSRect)clipRect
{
	// Lightly highlight the visible server if not selected
	if ([[self delegate] tableView:self objectValueForTableColumn:nil row:rowIndex] == [g_appController viewedServer]
		&& (selectedRow != rowIndex) && ([g_appController displayMode] == CRDDisplayUnified) )
	{
		[NSGraphicsContext saveGraphicsState];
		[[[NSColor selectedTextBackgroundColor] blendedColorWithFraction:0.4 ofColor:[NSColor whiteColor]] set];
		[NSBezierPath fillRect:[self rectOfRow:rowIndex]];		
		[NSGraphicsContext restoreGraphicsState];	
	}
	
	[[[[self tableColumns] objectAtIndex:0] dataCellForRow:rowIndex] setHighlighted:[self isRowSelected:rowIndex]];
	
	[super drawRow:rowIndex clipRect:clipRect];
}

- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend
{
	[self selectRow:[indexes firstIndex]];
}

- (void)selectRow:(int)index
{
	selectedRow = index;	
	[self setNeedsDisplay:YES];
}

- (void)deselectRow:(int)rowIndex
{
	[self deselectAll:nil];
}

- (void)deselectAll:(id)sender
{
	[self selectRow:-1];
}

- (BOOL)isRowSelected:(int)rowIndex
{
	return rowIndex == selectedRow;
}

- (int)selectedRow
{
	return selectedRow;
}

- (NSIndexSet *)selectedRowIndexes
{
	return [NSIndexSet indexSetWithIndex:selectedRow];
}

- (NSImage *)dragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns
		event:(NSEvent*)dragEvent offset:(NSPointPointer)dragImageOffset
{
	int row = [dragRows firstIndex];
	
	if ( (row < 0) || (row >= [self numberOfRows]))
		return nil;
	
	NSRect rowRect = [self rectOfRow:row];	
	NSImage *dragImage = [[NSImage alloc] initWithSize:rowRect.size];
	[dragImage setFlipped:YES];
	
	[dragImage lockFocus];
	{
		NSAffineTransform *xform = [NSAffineTransform transform];
		[xform translateXBy:0.0 yBy:rowRect.size.height];
		[xform scaleXBy:1.0 yBy:-1.0];
		[xform concat]; 
		
		BOOL highlighted = [[self cellForRow:row] isHighlighted];
		[[self cellForRow:row] setHighlighted:NO];
		[[self cellForRow:row] drawWithFrame:RECT_FROM_SIZE(rowRect.size) inView:nil];
		[[self cellForRow:row] setHighlighted:highlighted];
		
	} [dragImage unlockFocus];
	

	return [dragImage autorelease];
}

- (BOOL)canDragRowsWithIndexes:(NSIndexSet *)rowIndexes atPoint:(NSPoint)mouseDownPoint
{
	return [[self delegate] tableView:self canDragRow:[rowIndexes firstIndex]];
}


#pragma mark -
#pragma mark NSResponder

- (void)keyDown:(NSEvent *)ev
{
	NSString *str = [ev charactersIgnoringModifiers];
	
	if ([str length] == 1)
	{
		switch ([str characterAtIndex:0])
		{
			case NSDeleteFunctionKey:
			case 0x007f: /* backward delete */
				[g_appController removeSelectedSavedServer:self];
				return;
				break;
			
			case 0x0003: // return
			case 0x000d: // numpad enter
				[g_appController connect:self];
				return;
				break;
				
			default:
				break;
		}
	}
	
	[super keyDown:ev];
}

- (void)mouseDown:(NSEvent *)ev
{
	int row = [self rowAtPoint:[self convertPoint:[ev locationInWindow] fromView:nil]];
	if ([ev clickCount] == 2 && row == [self selectedRow])
	{
		[g_appController connect:self];
		return;
	}
	else if ([self selectedRow] != row)
	{
		[self selectRow:row];
	}
	
//	[super mouseDown:ev];
}

- (void)mouseDragged:(NSEvent *)ev
{
	int row = [self rowAtPoint:[self convertPoint:[ev locationInWindow] fromView:nil]];
	NSRect rowRect = [self rectOfRow:row];
	NSIndexSet *index = [NSIndexSet indexSetWithIndex:row];
	NSPoint offset = NSZeroPoint, imageStart = rowRect.origin;
	imageStart.y+=rowRect.size.height;
	NSPasteboard *pboard;

	pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	[[self delegate] tableView:self writeRowsWithIndexes:index toPasteboard:pboard];

	NSImage *dragImage = [self dragImageForRowsWithIndexes:index tableColumns:nil event:ev offset:&offset];
	
	[g_appController holdSavedServer:row];
	[self noteNumberOfRowsChanged];
	draggedRow = row;
	[self deselectAll:nil];
	
	[self dragImage:dragImage at:imageStart offset:NSZeroSize event:ev pasteboard:pboard source:self slideBack:YES];
}

// Assure that the row the right click is over is selected so that the context menu is correct
- (void)rightMouseDown:(NSEvent *)ev
{
	int row = [self rowAtPoint:[self convertPoint:[ev locationInWindow] fromView:nil]];
	if (row != -1)
		[self selectRow:row];
		
	[super rightMouseDown:ev];
}

- (NSRect)rectOfRow:(int)rowIndex
{
	NSRect realRect = [super rectOfRow:rowIndex];
	
	if ((rowIndex != -1) && (autoexpansionCurrentRowOrigins != nil))
	{
		realRect.origin = [[autoexpansionCurrentRowOrigins objectAtIndex:rowIndex] pointValue];
	}
	
	return realRect;
}


#pragma mark -
#pragma mark NSDraggingDestination

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	if ([sender draggingSource] == self)
	{
		//NSLog(@"doing custom anim for self");
		
		emptyRowIndex = draggedRow;
		
		int numRows = [self numberOfRows], i;
		float delta = [super rectOfRow:emptyRowIndex].size.height;

		NSPoint endRowOrigin;
		NSMutableArray *endBuilder = [NSMutableArray arrayWithCapacity:numRows-emptyRowIndex];
		NSMutableArray *startBuilder = [NSMutableArray arrayWithCapacity:numRows-emptyRowIndex];
		
		for (i = 0; i <= numRows; i++)
		{
			endRowOrigin = [super rectOfRow:i].origin;
			
			if ( i >= emptyRowIndex)
				endRowOrigin.y += delta;
				
			[startBuilder addObject:[NSValue valueWithPoint:endRowOrigin]];
			[endBuilder addObject:[NSValue valueWithPoint:endRowOrigin]];
		}

		[autoexpansionStartRowOrigins release];
		[autoexpansionEndRowOrigins release];
		
		autoexpansionStartRowOrigins = [startBuilder retain];
		autoexpansionEndRowOrigins = [endBuilder retain];
		
		[self animation:nil didReachProgressMark:1.0];
		
		return NSDragOperationMove;
	}
	else
		return [self draggingUpdated:sender];
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	int row = [super rowAtPoint:[self convertPoint:[sender draggingLocation] fromView:nil]];
		
	NSDragOperation retOperation;
	BOOL innerListDrag = [sender draggingSource] == self;

	inLiveDrag = YES;
	
	if ([[self delegate] tableView:self canDropAboveRow:row])
		retOperation = innerListDrag ? NSDragOperationMove : NSDragOperationCopy;
	else 
		return NSDragOperationNone;
		
//	NSLog(@"row=%d, dragged=%d, empty=%d", row, draggedRow, emptyRowIndex);
	
	if ( (row != -1) && (row != emptyRowIndex) )
	{
		[self createNewRowOriginsAboveRow:row];
		[self startAnimation];
	}
	else if ( (row == -1) && (emptyRowIndex != [self numberOfRows]) )
	{
		[self createNewRowOriginsAboveRow:[self numberOfRows]];
		[self startAnimation];	
	}
	
	return retOperation;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	[self concludeDrag];
}

/*
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return [super prepareForDragOperation:sender];
}


- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	NSString *pbDataType = [self pasteboardDataType:sender];
	
	if (pbDataType == nil)
		return NO;
	
	if ([pbDataType isEqualToString:SAVED_SERVER_DRAG_TYPE])
	{
	
	
	}
	else if ([pbDataType isEqualToString:NSFilenamesPboardType])
	{
	
	
	}
	else if ([pbDataType isEqualToString:NSFilesPromisePboardType])
	{
	
	
	}
	
	
	return YES;
}*/

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	[super concludeDragOperation:sender];
	[self concludeDrag];
}


- (BOOL)wantsPeriodicDraggingUpdates
{
	return YES;
}


#pragma mark -
#pragma mark NSDraggingSource

- (void)draggedImage:(NSImage *)anImage beganAt:(NSPoint)point
{
	int row = [self rowAtPoint:point];
	
	[super draggedImage:anImage beganAt:point];	
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
	[super draggedImage:anImage endedAt:aPoint operation:operation];
}


#pragma mark -
#pragma mark Dragging internal use

- (NSString *)pasteboardDataType:(NSPasteboard *)draggingPasteboard
{
	NSArray *supportedTypes = [NSArray arrayWithObjects:SAVED_SERVER_DRAG_TYPE,
			NSFilenamesPboardType, NSFilesPromisePboardType, nil];
			
	return [draggingPasteboard availableTypeFromArray:supportedTypes];
}

- (BOOL)pasteboardHasValidData:(NSPasteboard *)draggingPasteboard
{
	return [self pasteboardDataType:draggingPasteboard] != nil;
}

- (void)startAnimation
{
	if (autoexpansionAnimation != nil)
	{
		[autoexpansionAnimation stopAnimation];
		[autoexpansionAnimation release];
	}

	float frameRate = 30.0;
	
	autoexpansionAnimation = [[NSAnimation alloc] initWithDuration:ANIMATION_DURATION
			animationCurve:NSAnimationLinear];
	
	[autoexpansionAnimation setFrameRate:frameRate];
	[autoexpansionAnimation setAnimationBlockingMode:NSAnimationNonblocking];
	[autoexpansionAnimation setDelegate:self];
	
	// Make sure animation:didReachProgressMark: gets called on each frame	
	for (int i = 0; i < (int)frameRate; i++)
		[autoexpansionAnimation addProgressMark:(i / frameRate)];
		
	[autoexpansionAnimation startAnimation];
}

- (void)createNewRowOriginsAboveRow:(int)rowIndex
{
	if (emptyRowIndex == rowIndex || rowIndex == -1) 
		return;
		
	oldEmptyRowIndex = (emptyRowIndex == -1) ? [self numberOfRows] : emptyRowIndex;
	emptyRowIndex = rowIndex;
	
	int numRows = [self numberOfRows], i;
	float delta = [super rectOfRow:rowIndex].size.height;

	NSPoint startRowOrigin, endRowOrigin;
	NSMutableArray *endBuilder = [NSMutableArray arrayWithCapacity:numRows-emptyRowIndex];
	NSMutableArray *startBuilder = [NSMutableArray arrayWithCapacity:numRows-emptyRowIndex];
	
	for (i = 0; i <= numRows; i++)
	{
		startRowOrigin = [self rectOfRow:i].origin;
		endRowOrigin = [super rectOfRow:i].origin;
		
		if ( i >= emptyRowIndex)
			endRowOrigin.y += delta;
			
		[startBuilder addObject:[NSValue valueWithPoint:startRowOrigin]];
		[endBuilder addObject:[NSValue valueWithPoint:endRowOrigin]];
	}

	[autoexpansionStartRowOrigins release];
	[autoexpansionEndRowOrigins release];
	
	autoexpansionStartRowOrigins = [startBuilder retain];
	autoexpansionEndRowOrigins = [endBuilder retain];
}

- (void)concludeDrag
{
	if (inLiveDrag)
	{
		if (emptyRowIndex != [self numberOfRows])
		{
			[self createNewRowOriginsAboveRow:[self numberOfRows]];
			[self startAnimation];
		}
		inLiveDrag = NO;
	}
	else
	{
		[autoexpansionCurrentRowOrigins release];
		[autoexpansionEndRowOrigins release];
		[autoexpansionCurrentRowOrigins release];
		autoexpansionCurrentRowOrigins = autoexpansionEndRowOrigins = autoexpansionStartRowOrigins = nil;
		
		[autoexpansionAnimation stopAnimation];
		[autoexpansionAnimation release];
		autoexpansionAnimation = nil;
		
		emptyRowIndex = oldEmptyRowIndex = -1;
	}

	[self setNeedsDisplay];
}


#pragma mark -
#pragma mark NSAnimation delegate

- (void)animation:(NSAnimation*)animation didReachProgressMark:(NSAnimationProgress)progress
{
	// Create new autoexpansionCurrentRowOrigins by convolving the start origins to the end
	float fraction = [animation currentValue];

	NSMutableArray *currentPointsBuilder = [[NSMutableArray alloc] init];
	
	NSEnumerator *startEnum = [autoexpansionStartRowOrigins objectEnumerator],
			*endEnum = [autoexpansionEndRowOrigins objectEnumerator];
	id startValue, endValue;
	NSPoint convolvedPoint, startOrigin, endOrigin;
		
	while ( (startValue = [startEnum nextObject]) && (endValue = [endEnum nextObject]))
	{
		startOrigin = [startValue pointValue];
		endOrigin = [endValue pointValue];
		convolvedPoint = NSMakePoint(startOrigin.x * (1.0 - fraction) + endOrigin.x * fraction,
									 startOrigin.y * (1.0 - fraction) + endOrigin.y * fraction);
		
		[currentPointsBuilder addObject:[NSValue valueWithPoint:convolvedPoint]];
	}
	
	[autoexpansionCurrentRowOrigins release];
	autoexpansionCurrentRowOrigins = [currentPointsBuilder retain];
	
	[self setNeedsDisplay:YES];
}


- (void)animationDidEnd:(NSAnimation*)animation
{
	oldEmptyRowIndex = -1;
	
	if (!inLiveDrag)
		[self concludeDrag];
}


#pragma mark -
#pragma mark Internal use
- (CRDServerCell *)cellForRow:(int)row
{
	return [[[self tableColumns] objectAtIndex:0] dataCellForRow:row];

}
@end




