/*	Copyright (c) 2007-2011 Dorian Johnson <2011@dorianj.net>
	
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

@interface NSObject (CRDTabViewItem)
	- (NSView *)tabItemView;
@end


@interface CRDTabView : NSView
{
	IBOutlet id delegate;
	
	id _selectedItem;
	NSMutableArray *_items;
}

@property (readonly) id selectedItem;

- (IBAction)selectFirstItem:(id)sender;
- (IBAction)selectLastItem:(id)sender;
- (IBAction)selectNextItem:(id)sender;
- (IBAction)selectPreviousItem:(id)sender;
- (IBAction)selectItem:(id)item;

- (void)selectItemAtIndex:(NSInteger)index;
- (id)itemAtIndex:(NSInteger)index;

- (NSInteger)indexOfItem:(id)item;
- (NSInteger)indexOfSelectedItem;

- (NSInteger)numberOfItems;

- (void)addItem:(id)item;
- (void)removeItem:(id)item;
- (void)removeAllItems;

@end


