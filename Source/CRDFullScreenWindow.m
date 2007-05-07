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

#import "CRDFullScreenWindow.h"
#import "miscellany.h"
#import "AppController.h"
#import "CRDApplication.h"


@interface CRDFullScreenWindow (Private)
	- (void)toggleMenuBarVisible:(BOOL)visible;
@end


#pragma mark -
@implementation CRDFullScreenWindow

- (id)initWithScreen:(NSScreen *)screen
{
	if (![super initWithContentRect:[screen frame] styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO])
	{
		return nil;
	}
	
	[self setDisplaysWhenScreenProfileChanges:YES];
	[self setBackgroundColor:[NSColor blackColor]];
	[self setAcceptsMouseMovedEvents:YES];
	[self setReleasedWhenClosed:YES];
	[self setHasShadow:NO];
	[[self contentView] setAutoresizesSubviews:NO];
	
	// Could use NSScreenSaverWindowLevel, but NSPopUpMenuWindowLevel achieves the same effect while
	//	allowing the menu to display over it. Change to NSNormalWindowLevel for debugging fullscreen
	[self setLevel:NSPopUpMenuWindowLevel];
	
	return self;
}

- (void)dealloc
{
	[NSMenu setMenuBarVisible:YES];
	[super dealloc];
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
	[self makeKeyAndOrderFront:self];
	
	[viewAnim startAnimation];
	[viewAnim release];	
	
	[self display];
	[self toggleMenuBarVisible:NO];
}

// Windows that use the NSBorderlessWindowMask can't become key by default.
- (BOOL) canBecomeKeyWindow
{
    return YES;
}


- (void)menuHotspotTracker:(NSTimer*)timer
{
	if ([timeMouseEnteredMenuHotspot timeIntervalSinceNow] < -MENU_HOTSPOT_WAIT &&
		[self pointIsInMouseHotSpot:[self mouseLocationOutsideOfEventStream]])
	{
		[self toggleMenuBarVisible:YES];
	}
}

- (void)mouseMoved:(NSEvent *)ev
{
	if ([self pointIsInMouseHotSpot:[ev locationInWindow]])
	{
		NSDate *curTime = [NSDate date];
		if (timeMouseEnteredMenuHotspot == nil && !menuVisible)
		{
			timeMouseEnteredMenuHotspot = [curTime retain];
			
			// Schedule a check back in case the mouse doesn't move again
			[NSTimer scheduledTimerWithTimeInterval:MENU_HOTSPOT_WAIT target:self selector:@selector(menuHotspotTracker:) userInfo:nil repeats:NO];
		}
		else if ([curTime timeIntervalSinceDate:timeMouseEnteredMenuHotspot] > MENU_HOTSPOT_WAIT && !menuVisible)
		{
			[self toggleMenuBarVisible:YES];
		}
	} 
	else if (!menuVisible || ([self frame].size.height - [ev locationInWindow].y > [NSMenuView menuBarHeight]))
	{
		[self toggleMenuBarVisible:NO];
		
		[timeMouseEnteredMenuHotspot release];
		timeMouseEnteredMenuHotspot = nil;
	}
	
	[[self firstResponder] mouseMoved:ev];
}

- (BOOL)pointIsInMouseHotSpot:(NSPoint)point
{
	return [self frame].size.height - point.y <= MENU_HOTSPOT_HEIGHT;
}

- (void)toggleMenuBarVisible:(BOOL)visible
{
	if (visible == menuVisible)
		return;

	[timeMouseEnteredMenuHotspot release];
	timeMouseEnteredMenuHotspot = nil;
	
	// -[NSMenu menuBarHeight] has a bug in OS X 10.4 and always returns 0.0
	float menuBarHeight = [NSMenuView menuBarHeight];
		
	NSRect winFrame = [self frame];
	winFrame.origin.y += (visible ? -1 : 1) * menuBarHeight;
	
	if (visible)
		[NSMenu setMenuBarVisible:YES];
		
	[self setFrame:winFrame display:NO animate:YES];
	
	if (!visible)
		[NSMenu setMenuBarVisible:NO];
	
	menuVisible = visible;
}


- (BOOL)menuVisible
{
	return menuVisible;
}

@end






