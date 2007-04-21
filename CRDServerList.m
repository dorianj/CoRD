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


#pragma mark -

@interface CRDServerList (Private)
	- (NSString *)pasteboardDataType:(NSPasteboard *)draggingPasteboard;
	- (BOOL)pasteboardHasValidData:(NSPasteboard *)draggingPasteboard;

@end


#pragma mark -
@implementation CRDServerList


#pragma mark -
#pragma mark NSTableView

// If this isn't overridden, it won't use the hightlightSelectionInClipRect method
- (id)_highlightColorForCell:(NSCell *)cell
{
	return nil;
}

- (void)highlightSelectionInClipRect:(NSRect)clipRect
{	
	int selectedRow = [self selectedRow];
	if (selectedRow == -1)
		return;
	
	RDInstance *inst = [g_appController serverInstanceForRow:selectedRow];
	NSRect drawRect = [self rectOfRow:selectedRow];
	
	NSColor *topColor, *bottomColor;
	if ([g_appController mainWindowIsFocused])
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

- (void)selectRowIndexes:(NSIndexSet *)indexes byExtendingSelection:(BOOL)extend
{
	int selectedRow, i, count;
	
	selectedRow = (indexes != nil) ? [indexes firstIndex] : -1;

	for (i = 0, count = [self numberOfRows]; i < count; i++)
		[[[[self tableColumns] objectAtIndex:0] dataCellForRow:i] setHighlighted:(i == selectedRow)];

	[super selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
	[self setNeedsDisplay:YES];
}

- (void)selectRow:(int)index
{
	if (index > -1 && [[self delegate] tableView:self shouldSelectRow:index])
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:(unsigned)index] byExtendingSelection:NO];
	else
		[self deselectAll:self];
}

- (void)deselectRow:(int)rowIndex
{
	if (rowIndex != -1)
		[[[[self tableColumns] objectAtIndex:0] dataCellForRow:rowIndex] setHighlighted:NO];
}

- (void)deselectAll:(id)sender
{
	[self selectRowIndexes:nil byExtendingSelection:NO];
	[super deselectAll:sender];
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
	else
	{
		[self selectRow:row];
	}
	
	// Don't call super so that it performs click-through selection
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
	if (inLiveDrag && (autoexpansionCurrentRowOrigins != nil))
	{
		return [[autoexpansionCurrentRowOrigins objectAtIndex:rowIndex] rectValue];
	}
	
	
	return [super rectOfRow:rowIndex];
}

#pragma mark -
#pragma mark NSDraggingDestination

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
	// todo: if the destination is one of the labels, return NSDragOperationNone
	return NSDragOperationMove;
}

- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)sender
{
	// todo: if the destination is one of the labels, return NSDragOperationNone
	return NSDragOperationMove;
}


- (void)draggingExited:(id <NSDraggingInfo>)sender
{
	// todo: if the destination is one of the labels, return NSDragOperationNone
	// todo: animate all list items moving back to their original position
	
	inLiveDrag = NO;
}

- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)sender
{
	return [self pasteboardHasValidData:[sender draggingPasteboard]];
	
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
	
	return [self pasteboardHasValidData:[sender draggingPasteboard]];
}


- (BOOL)wantsPeriodicDraggingUpdates
{
	return YES;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{

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


}

- (void)createNewRowOriginsWithStartRow:(int)rowIndex
{
	int numRows = [self numberOfRows], i;
	
	// If this row is in an altered position, assume the rest are and adjust accordingly
	float delta;
	if (autoexpansionCurrentRowOrigins != nil)
	{
		NSRect r = [self rectOfRow:rowIndex], c = [[autoexpansionCurrentRowOrigins objectAtIndex:rowIndex] rectValue];
		
		delta = r.size.height + (r.origin.y - c.origin.y);
	}
	
	NSPoint rowOrigin;
	NSMutableArray *endBuilder = [NSMutableArray arrayWithCapacity:numRows-rowIndex];
	NSMutableArray *startBuilder = [NSMutableArray arrayWithCapacity:numRows-rowIndex];
	
	for (i = rowIndex; i < numRows; i++)
	{
		rowOrigin = [self rectOfRow:i].origin;
		if (autoexpansionCurrentRowOrigins != nil)
		{
		
		}
		[startBuilder addObject:rowOrigin];
		[endBuilder addObject:[NSValue valueWithPoint:NSMakePoint(rowOrigin.x, rowOrigin.y + delta * (rowIndex - i))]];
	}
	
	
	[autoexpansionStartRowOrigins release];
	[autoexpansionEndRowOrigins release];
	
	autoexpansionStartRowOrigins = [startBuilder retain];
	autoexpansionEndRowOrigins = [endBuilder retain];
}

#pragma mark -
#pragma mark NSAnimation delegate

- (void)animation:(NSAnimation*)animation didReachProgressMark:(NSAnimationProgress)progress
{
	// Create new autoexpansionCurrentRowOrigins by convolving the start origin to the end
	

}


@end




