/*  Copyright (c) 2007 Dorian Johnson <arcadiclife@gmail.com>
	
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

#import "CRDFullScreenWindow.h"

@interface CRDFullScreenWindow (Private)
	- (void)toggleMenuBarVisible:(BOOL)visible;
@end


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
	
	return self;
}

- (void)startFullScreen
{
	NSDictionary *animDict = [NSDictionary dictionaryWithObjectsAndKeys:
						self, NSViewAnimationTargetKey,
						NSViewAnimationFadeInEffect, NSViewAnimationEffectKey,
						nil];
	NSViewAnimation *viewAnim = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:animDict]];
	[viewAnim setAnimationBlockingMode:NSAnimationBlocking];
	[viewAnim setDuration:0.5];
	[viewAnim setAnimationCurve:NSAnimationEaseIn];
	
	[self setAlphaValue:0.0];
	[self setLevel:NSPopUpMenuWindowLevel];
	[self makeKeyAndOrderFront:self];
	
	[viewAnim startAnimation];
	[viewAnim release];	
	
	SetSystemUIMode(kUIModeAllHidden, kUIOptionAutoShowMenuBar);
	[self setLevel:NSNormalWindowLevel];
	
	[self display];
}

- (void)prepareForExit
{
	[self setLevel:NSPopUpMenuWindowLevel];
	SetSystemUIMode(kUIModeNormal, 0);
}

- (void)exitFullScreen
{	
	NSDictionary *fadeWindow = [NSDictionary dictionaryWithObjectsAndKeys:
						self, NSViewAnimationTargetKey,
						NSViewAnimationFadeInEffect, NSViewAnimationEffectKey,
						nil];
	NSViewAnimation *viewAnim = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:fadeWindow]];
	[viewAnim setAnimationBlockingMode:NSAnimationBlocking];
	[viewAnim setDuration:0.5];
	[viewAnim setAnimationCurve:NSAnimationEaseOut];
		
	[viewAnim startAnimation];
	[viewAnim release];	
	
	[self close];
}

// Windows that use the NSBorderlessWindowMask can't become key by default.
- (BOOL)canBecomeKeyWindow
{
    return YES;
}

@end






