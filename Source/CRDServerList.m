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

/*	Notes:
		- I could have used CoreGraphics for the gradients. Drawing my own was easier.
			It's the same exact result: a calculated gradient.
		- In its current form, this isn't as abstracted as a view object should be. 
			The delegate is assumed to respond to messages, it delves into the controller
			realm, etc.
		- Some of this code is downright ugly/hacky - especially the drag and drop code
*/

#import "CRDServerList.h"
#import "miscellany.h"
#import "AppController.h"
#import "CRDServerCell.h"
#import "RDInstance.h"


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
	- (void)createConvolvedRowRects:(float)fraction;
	- (CRDServerCell *)cellForRow:(int)row;
	- (NSDragOperation)dragOperationForSource:(id <NSDraggingInfo>)info;
	- (void)startDragForEvent:(NSEvent *)ev;
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
	
	NSColor *topColor, *bottomColor;
	if ([g_appController mainWindowIsFocused])
	{
		topColor = HIGHLIGHT_START;
		bottomColor = HIGHLIGHT_END;
	} else {
		topColor = UNFOCUSED_START;
		bottomColor = UNFOCUSED_END;	
	}
	
	NSRect drawRect = [self rectOfRow:selectedRow];
	
	[self lockFocus];	
	NSRectClip(drawRect);
	draw_vertical_gradient(topColor, bottomColor, drawRect);
	draw_horizontal_line([bottomColor blendedColorWithFraction:0.6 ofColor:topColor], 
			NSMakePoint(drawRect.origin.x, drawRect.origin.y), drawRect.size.width);
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
	int oldSelection = selectedRow;
	selectedRow = [[self delegate] tableView:self shouldSelectRow:index] ? index : -1;
	
	// Bit hacky, but works better than calling super (this way, we control the notification)
	_selectedRows = [[NSIndexSet indexSetWithIndex:selectedRow] mutableCopy];
	
	[self setNeedsDisplay:YES];
	
	if (  (oldSelection != selectedRow) )
		[[NSNotificationCenter defaultCenter] postNotificationName:NSTableViewSelectionDidChangeNotification object:self];	
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

- (int)numberOfSelectedRows
{
	return ([self selectedRow] == -1) ? 0 : 1;
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
	mouseDragStart = [ev locationInWindow];
	if ([ev clickCount] == 2 && row == [self selectedRow])
	{
		[g_appController connect:self];
		return;
	}
	
	[[self window] makeFirstResponder:self];
}

- (void)mouseUp:(NSEvent *)ev
{
	int row = [self rowAtPoint:[self convertPoint:[ev locationInWindow] fromView:nil]];

	if ([self selectedRow] != row)
	{
		[self selectRow:row];
	}
}

- (void)mouseDragged:(NSEvent *)ev
{
	if (POINT_DISTANCE(mouseDragStart, [ev locationInWindow]) < 4.0)
		return;
	
	[self startDragForEvent:ev];

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
	
	if ((rowIndex != -1) && (autoexpansionCurrentRowOrigins != nil) && ([autoexpansionCurrentRowOrigins count] > rowIndex))
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


- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	if ([self pasteboardHasValidData:[sender draggingPasteboard]])
		return YES;
	else 
	{
		[self concludeDrag];
		return NO;
	}
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	if ([self pasteboardHasValidData:[sender draggingPasteboard]])
	{
		NSString *pbDataType = [self pasteboardDataType:[sender draggingPasteboard]];
		
		int row = [self rowAtPoint:[self convertPoint:[sender draggingLocation] fromView:nil]];
		
		if (row == -1)
			row = [self numberOfRows];
		
		[[self delegate] tableView:self acceptDrop:sender row:row dropOperation:[self dragOperationForSource:sender]];
		[self createNewRowOriginsAboveRow:[self numberOfRows]];
		[self createConvolvedRowRects:1.0];
		
		return YES;
	}
	else 
	{
		[self concludeDrag];
		return NO;
	}
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	[self concludeDrag];
}

- (BOOL)wantsPeriodicDraggingUpdates
{
	return YES;
}


#pragma mark -
#pragma mark NSDraggingSource

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
	if ( (operation == NSDragOperationCopy) || (operation == NSDragOperationNone) )
	{
		[g_appController reinsertHeldSavedServer:-1];
	}
	
	[super draggedImage:anImage endedAt:aPoint operation:operation];
}

- (unsigned int)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
	return isLocal ? NSDragOperationMove : NSDragOperationCopy;
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

- (NSDragOperation)dragOperationForSource:(id <NSDraggingInfo>)info
{
	NSString *type = [self pasteboardDataType:[info draggingPasteboard]];
	
	if (type == nil)
		return NSDragOperationNone;
	if ([type isEqualToString:SAVED_SERVER_DRAG_TYPE])
		return NSDragOperationMove;
	else
		return NSDragOperationCopy;
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
		
	if ([self numberOfRows] != [autoexpansionCurrentRowOrigins count])
	{
		[autoexpansionCurrentRowOrigins release];
		autoexpansionCurrentRowOrigins = nil;
	}
		
	oldEmptyRowIndex = (emptyRowIndex == -1) ? [self numberOfRows] : emptyRowIndex;
	emptyRowIndex = rowIndex;
	
	int numRows = [self numberOfRows], i;
	float delta = [super rectOfRow:rowIndex].size.height;

	NSPoint startRowOrigin, endRowOrigin;
	NSMutableArray *endBuilder = [NSMutableArray arrayWithCapacity:numRows-emptyRowIndex];
	NSMutableArray *startBuilder = [NSMutableArray arrayWithCapacity:numRows-emptyRowIndex];
	
	for (i = 0; i < numRows; i++)
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

// Create a new autoexpansionCurrentRowOrigins by convolving the start origins to the end
- (void)createConvolvedRowRects:(float)fraction
{
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
}

- (void)startDragForEvent:(NSEvent *)ev
{	
	int row = [self rowAtPoint:[self convertPoint:mouseDragStart fromView:nil]];
	
	if (![[self delegate] tableView:self canDragRow:row])
		return;

	NSRect rowRect = [self rectOfRow:row];
	NSIndexSet *index = [NSIndexSet indexSetWithIndex:row];
	NSPoint offset = NSZeroPoint, imageStart = rowRect.origin;
	imageStart.y += rowRect.size.height;
	NSPasteboard *pboard;

	pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	[[self delegate] tableView:self writeRowsWithIndexes:index toPasteboard:pboard];

	NSImage *dragImage = [self dragImageForRowsWithIndexes:index tableColumns:nil event:ev offset:&offset];
	
	[g_appController holdSavedServer:row];
	selectedRow = -1;
	[self noteNumberOfRowsChanged];
	draggedRow = row;
	
	[self createNewRowOriginsAboveRow:draggedRow];
	[autoexpansionStartRowOrigins release];
	autoexpansionStartRowOrigins = [autoexpansionEndRowOrigins retain];
	[self createConvolvedRowRects:1.0];
	
	[self dragImage:dragImage at:imageStart offset:NSZeroSize event:ev pasteboard:pboard source:self slideBack:YES];
	
	[autoexpansionCurrentRowOrigins release];
	autoexpansionCurrentRowOrigins = nil;
}


#pragma mark -
#pragma mark NSAnimation delegate

- (void)animation:(NSAnimation*)animation didReachProgressMark:(NSAnimationProgress)progress
{
	[self createConvolvedRowRects:[animation currentValue]];
	[self setNeedsDisplay];
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




