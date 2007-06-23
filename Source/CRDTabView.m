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

#import "CRDTabView.h"
 
#import "CRDShared.h"

@interface CRDTabView (Private)
//	- (void)setSelectedTabViewItem:(NSTabViewItem *)newSelection;
@end

#pragma mark -

@implementation CRDTabView

- (id)initWithFrame:(NSRect)frame
{
	if (![super initWithFrame:frame])
		return nil;
		
	_items = [[NSMutableArray alloc] init];
	itemsLock = [[NSLock alloc] init];
		
	return self;
}

- (void) dealloc
{
	_selectedItem = nil;
	[_items release];
	_items = nil;
	[super dealloc];
}

- (void)drawRect:(NSRect)rect
{
	CRDDrawVerticalGradient([NSColor colorWithDeviceWhite:.96  alpha:1.0], [NSColor colorWithDeviceWhite:0.89 alpha:1.0], [self bounds]);
}



#pragma mark -
#pragma mark Working with selection

- (void)selectItem:(id)item
{
	NSView *initialContentView = [[self selectedItem] view];
	NSView *finalContentView = [item view];
	
	[finalContentView setFrame:(NSRect){NSZeroPoint, [self bounds].size}];
	
	if ([self animatesWhenSwitchingItems])
	{
		NSLog(@"Attempting to animate");
		

	
		NSMutableArray *viewAnims = [NSMutableArray array];
		
		if (initialContentView != nil)
		{
			[viewAnims addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							initialContentView, NSViewAnimationTargetKey,
							NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey,
							nil]];
			NSLog(@"Animating the fade out");
		}
		
		if (finalContentView != nil)
		{
			[self addSubview:finalContentView];
			[viewAnims addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							finalContentView, NSViewAnimationTargetKey,
							NSViewAnimationFadeInEffect, NSViewAnimationEffectKey,
							/*[NSValue valueWithRect:[initialContentView frame]], NSViewAnimationStartFrameKey,
							[NSValue valueWithRect:CRDRectFromSize([finalContentView frame].size)], NSViewAnimationEndFrameKey, */
							nil]];
			
			NSLog(@"Animating the fade in");
		}

		if ([viewAnims count] == 0)
		{
			NSLog(@"Nothing to animate!");
			_selectedItem = item;
			return;
			
		}
			
		NSViewAnimation *viewAnim = [[NSViewAnimation alloc] initWithViewAnimations:viewAnims];
		[viewAnim setAnimationBlockingMode:NSAnimationBlocking];
		[viewAnim setDuration:2.0];
		[viewAnim setAnimationCurve:NSAnimationLinear];
		[viewAnim startAnimation];
		[viewAnim release];	
		
		[initialContentView removeFromSuperview];		
	}
	else
	{
		[self addSubview:finalContentView];
		[initialContentView removeFromSuperviewWithoutNeedingDisplay];
	}
	
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

- (IBAction)selectItemAtIndex:(unsigned)index
{
	[self selectItem:[self itemAtIndex:index]];
}

- (id)itemAtIndex:(unsigned)index
{
	if (index >= [self numberOfItems])
		return nil;
	
	return [_items objectAtIndex:index];
}

- (id)selectedItem
{
	return _selectedItem;
}

- (unsigned)indexOfItem:(id)item
{
	return [_items indexOfObject:item];
}

- (unsigned)indexOfSelectedItem
{
	return [self indexOfItem:_selectedItem];
}

- (unsigned)numberOfItems
{
	return [_items count];
}

- (void)addItem:(id)item
{
	if (item == nil)
		[NSException raise:NSInvalidArgumentException format:@"Can't add nil objects to CRDTabView"];
		
	if (![item respondsToSelector:@selector(view)])
		[NSException raise:@"InvalidCRDTabViewItem" format:@"CRDTabView items must respond to -[obj view]!"];
	
	@synchronized(itemsLock)
	{
		[_items addObject:item];
	}
}

- (void)removeItem:(id)item
{
	if ([self indexOfItem:item] == NSNotFound)
		[NSException raise:@"ItemDoesn'tExist" format:@"The receiver doesn't have %@ as an item", item];
	
	@synchronized(itemsLock)
	{
		if (_selectedItem == item)
		{
			if ([_items lastObject] == item)
				[self selectPreviousItem:self];
			else
				[self selectNextItem:self];		
		}

		[_items removeObject:item];
	}
}

- (BOOL)animatesWhenSwitchingItems
{
	return animatesWhenSwitchingItems;
}

- (void)setAnimatesWhenSwitchingItems:(BOOL)animate
{
	animatesWhenSwitchingItems = animate;
}


@end

#pragma mark -

@implementation CRDTabView (Private)

/*- (void)setSelectedTabViewItem:(NSTabViewItem *)newSelection
{
	[_selectedItem autorelease];
	_selectedItem = [newSelection retain];
}*/

@end
