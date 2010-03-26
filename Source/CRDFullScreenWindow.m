/*  Copyright (c) 2007-2010 Dorian Johnson <2010@dorianj.net>
	
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

#define CRDFullScreenTransitionDuration 0.4

#import "CRDFullScreenWindow.h"
#import "Carbon/Carbon.h"
#import "CRDShared.h"

#pragma mark -
@implementation CRDFullScreenWindow

- (id)initWithScreen:(NSScreen *)screen
{
	if (![super initWithContentRect:[screen frame] styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO])
		return nil;
	
	[self setDisplaysWhenScreenProfileChanges:YES];
	[self setBackgroundColor:[NSColor blackColor]];
	[self setAcceptsMouseMovedEvents:YES];
	[self setReleasedWhenClosed:YES];
	[self setHasShadow:NO];
	[[self contentView] setAutoresizesSubviews:NO];
	
	hideMenu = [[NSScreen screens] count] && (screen == [[NSScreen screens] objectAtIndex:0]);
	
	return self;
}

- (void)startFullScreenWithAnimation:(BOOL)animate
{
	[self setAlphaValue:0.0];
	[self setLevel:NSPopUpMenuWindowLevel];
	[self makeKeyAndOrderFront:self];
	[self display];

	NSDictionary *animDict = [NSDictionary dictionaryWithObjectsAndKeys:
						self, NSViewAnimationTargetKey,
						NSViewAnimationFadeInEffect, NSViewAnimationEffectKey,
						nil];
	NSViewAnimation *viewAnim = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:animDict]];
	[viewAnim setAnimationBlockingMode:NSAnimationBlocking];
	[viewAnim setDuration:CRDFullScreenTransitionDuration];
	[viewAnim setAnimationCurve:NSAnimationEaseIn];
	
	[viewAnim startAnimation];
	[viewAnim release];
	
	if (hideMenu)
		SetSystemUIMode(kUIModeAllHidden, kUIOptionAutoShowMenuBar); // gives auto-show/hide behavior
	
	[self setLevel:NSNormalWindowLevel];
	[self display];
}

- (void)startFullScreen
{
	[self startFullScreenWithAnimation:YES];
}

- (void)prepareForExit
{
	[self setLevel:NSPopUpMenuWindowLevel];
	
	if (hideMenu)
		SetSystemUIMode(kUIModeNormal, 0);
}

- (void)exitFullScreenWithAnimation:(BOOL)animate
{	
	if (animate)
	{
		NSDictionary *fadeWindow = [NSDictionary dictionaryWithObjectsAndKeys:
							self, NSViewAnimationTargetKey,
							NSViewAnimationFadeInEffect, NSViewAnimationEffectKey,
							nil];
		NSViewAnimation *viewAnim = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:fadeWindow]];
		[viewAnim setAnimationBlockingMode:NSAnimationBlocking];
		[viewAnim setDuration:CRDFullScreenTransitionDuration];
		[viewAnim setAnimationCurve:NSAnimationEaseOut];
			
		[viewAnim startAnimation];
		[viewAnim release];	
	}
	
	[self close];
}

- (void)exitFullScreen
{
	[self exitFullScreenWithAnimation:YES];
}

// Windows that use the NSBorderlessWindowMask can't become key by default.
- (BOOL)canBecomeKeyWindow
{
    return YES;
}

- (BOOL)canBecomeMainWindow
{
	return YES;
}


@end






