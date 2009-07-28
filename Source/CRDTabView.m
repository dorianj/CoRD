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


#import "CRDTabView.h" 
#import "CRDShared.h"

#pragma mark -

@implementation CRDTabView

- (id)initWithFrame:(NSRect)frame
{
	if (![super initWithFrame:frame])
		return nil;
		
	_items = [[NSMutableArray alloc] init];
		
	return self;
}

- (void)dealloc
{
	_selectedItem = nil;
	[_items release];
	_items = nil;
	[super dealloc];
}

- (void)drawRect:(NSRect)rect
{
//	CRDDrawVerticalGradient([NSColor colorWithDeviceWhite:0.93  alpha:1.0], [NSColor colorWithDeviceWhite:0.875 alpha:1.0], [self bounds]);
}


#pragma mark -
#pragma mark Working with selection

- (void)selectItem:(id)item
{
	NSView *currentContentView = [[self selectedItem] tabItemView], *newContentView = [item tabItemView];
	
	[newContentView setFrame:(NSRect){NSZeroPoint, [self bounds].size}];
	
	[currentContentView removeFromSuperviewWithoutNeedingDisplay];
	[self addSubview:newContentView];
	[self setNeedsDisplay:YES];
	
	_selectedItem = item;
}

- (IBAction)selectFirstItem:(id)sender
{
	[self selectItemAtIndex:0];
}

- (IBAction)selectLastItem:(id)sender
{
	[self selectItemAtIndex:([self numberOfItems]-1)];
}

- (IBAction)selectNextItem:(id)sender
{
	[self selectItemAtIndex:([self indexOfSelectedItem]+1)];
}

- (IBAction)selectPreviousItem:(id)sender
{
	[self selectItemAtIndex:([self indexOfSelectedItem]-1)];
}

- (IBAction)selectItemAtIndex:(NSInteger)index
{
	if (index >= [_items count])
		index = 0;
	else if (index < 0)
		index = [_items count] - 1;
		
	[self selectItem:[self itemAtIndex:index]];
}

- (id)itemAtIndex:(NSInteger)index
{
	if (index >= (NSInteger)[self numberOfItems])
		return nil;
	
	return [_items objectAtIndex:index];
}

- (id)selectedItem
{
	return _selectedItem;
}

- (NSInteger)indexOfItem:(id)item
{
	return [_items indexOfObject:item];
}

- (NSInteger)indexOfSelectedItem
{
	return [self indexOfItem:_selectedItem];
}

- (NSInteger)numberOfItems
{
	return (NSInteger)[_items count];
}

- (void)addItem:(id)item
{
	if (item == nil)
		[NSException raise:NSInvalidArgumentException format:@"Can't add nil objects to CRDTabView"];
		
	if (![item respondsToSelector:@selector(tabItemView)])
		[NSException raise:@"InvalidCRDTabViewItem" format:@"CRDTabView items must respond to -[obj tabItemView]!"];
	
	@synchronized(_items)
	{
		[_items addObject:item];
	}
}

- (void)removeItem:(id)item
{
	if ([self indexOfItem:item] == NSNotFound)
		[NSException raise:@"ItemDoesntExist" format:@"The receiver doesn't have %@ as an item", item];
	
	
	NSDisableScreenUpdates();
	
	if ([_items count] > 1)
		[self selectNextItem:self];
	else
		[[[self selectedItem] tabItemView] removeFromSuperviewWithoutNeedingDisplay];
	
	@synchronized(_items)
	{
		[_items removeObject:item];
	}
		
	NSEnableScreenUpdates();
}

- (void)removeAllItems
{
	[[[self selectedItem] tabItemView] removeFromSuperviewWithoutNeedingDisplay];
	_selectedItem = nil;
	
	@synchronized(_items)
	{
		[_items removeAllObjects];
	}
}

@end

