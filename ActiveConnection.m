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

/*	Purpose: Encapsulates RDInstance, RDView, a toolbar view (with or without thumnbnails),
		and a tab view
*/

#import "ActiveConnection.h"
#import "Definitions.h"

@implementation ActiveConnection


/* accessors */
-(NSString *)label						{ return [rd valueForKey:@"displayName"]; }
-(NSToolbarItem *)toolbarRepresentation { return toolbarRepresentation; }
-(NSTabViewItem *)tabViewRepresentation { return tabViewRepresentation; }
-(RDInstance *)rd						{ return rd; }

-(void)enableThumbnailView
{
	[thumbnailView setTag:1];
	[[rd valueForKey:@"view"] paintAuxiliaryViews];
}
-(void)disableThumbnailView
{
	[thumbnailView setTag:0];
}

-(id)initFromRDInstance:(RDInstance *)inst scroll:(NSScrollView *)scroll preview:(BOOL)preview
		target:(id)controller
{
	[super init];
	rd = [inst retain];
	NSString *label = [rd valueForKey:@"displayName"];
	SEL action = @selector(changeSelection:);
	
	// Create the tab view for it, scroll that surrounds it, add to tabview
	[scroll setDocumentView:[rd valueForKey:@"view"]];
	[scroll setHasVerticalScroller:YES];
	[scroll setHasHorizontalScroller:YES];
	[scroll setAutohidesScrollers:YES];
	[scroll setBorderType:NSNoBorder];
	tabViewRepresentation = [[NSTabViewItem alloc] initWithIdentifier:label];
	[tabViewRepresentation setView:scroll];
	[tabViewRepresentation setLabel:label];	
	
	// Create the thumbnail view for it
	NSRect size = NSMakeRect(0.0, 0.0, THUMBNAIL_WIDTH, THUMBNAIL_HEIGHT);
	thumbnailView = [[NSButton alloc] initWithFrame:size];
	NSImage *img = [[NSImage alloc] initWithSize:size.size];
	[img setFlipped:YES];
	[thumbnailView setImage:img];
	[thumbnailView setButtonType:NSMomentaryLight];
	[thumbnailView setAction:action];
	[thumbnailView setTitle:label];
	[thumbnailView setBordered:NO];
	[thumbnailView setImagePosition:NSImageOnly];
	[[rd valueForKey:@"view"] addAuxiliaryView:thumbnailView];
	
	// Create the toolbar item for it
	toolbarRepresentation = [[NSToolbarItem alloc] initWithItemIdentifier:label];
	[toolbarRepresentation setTarget:controller];
	[toolbarRepresentation setAction:action];
	[toolbarRepresentation setLabel:label];
	[toolbarRepresentation setView:thumbnailView];
	[toolbarRepresentation setMinSize:[thumbnailView bounds].size];
	[toolbarRepresentation setMaxSize:[thumbnailView bounds].size];
	NSMenuItem *menuForm = [[NSMenuItem alloc] initWithTitle:label
			action:action keyEquivalent:@""];
	[toolbarRepresentation setMenuFormRepresentation:menuForm];
	
	if (preview) [self enableThumbnailView];
	else [self disableThumbnailView];
	return self;
}

// Meant to be called by the thread whose run loop the RDInstance's input stream attached.
-(void)startInputRunLoop
{
	// Run the run loop, allocating/releasing a pool occasionally
	running = YES;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	BOOL gotInput;
	unsigned x = 0;
	do {
		if (x % 10 == 0) {
			[pool release];
			pool = [[NSAutoreleasePool alloc] init];
		}
		gotInput = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode 
					beforeDate:[NSDate dateWithTimeIntervalSinceNow:10.0]];
		x++;
	} while (running && gotInput);
	[pool release];
}


-(void)disconnect {
	running = NO;
}

-(void) dealloc {
	running = NO;
	[rd release];
	[[thumbnailView image] release]; 
	[thumbnailView release];
	[toolbarRepresentation release];
	[tabViewRepresentation release];
	[super dealloc];
}

/*
-(id)retain
{
	NSLog(@"AC was retained, new retain count is %d", [self retainCount]+1);
	return [super retain];
}

- (oneway void)release
{
	NSLog(@"AC was released, new retain count is %d", [self retainCount]-1);
	return [super release];
}*/


@end
