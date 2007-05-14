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






