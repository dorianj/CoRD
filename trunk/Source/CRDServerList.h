/*	Copyright (c) 2007-2009 Dorian Johnson <2009@dorianj.net>
	
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

#import <Cocoa/Cocoa.h>


@interface CRDServerList : NSTableView
{
	// Animated dragging
	NSAnimation *autoexpansionAnimation;
	BOOL inLiveDrag;
	NSInteger emptyRowIndex, oldEmptyRowIndex, draggedRow;
	
	NSInteger selectedRow;
	
	NSPoint mouseDragStart;
	
	// Arrays of NSValues encapsulating NSPoints
	NSArray *autoexpansionStartRowOrigins, *autoexpansionEndRowOrigins, *autoexpansionCurrentRowOrigins;
}
- (void)selectRow:(NSInteger)index;
- (NSString *)pasteboardDataType:(NSPasteboard *)draggingPasteboard;

@end


@interface NSObject (CRDServerListDataSource)
	- (BOOL)tableView:(NSTableView *)aTableView canDragRow:(NSUInteger)rowIndex;
	- (BOOL)tableView:(NSTableView *)aTableView canDropAboveRow:(NSUInteger)rowIndex;
@end
