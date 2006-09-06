//  Copyright (c) 2006 Craig Dooley <xlnxminusx@gmail.com>
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


#import "AppController.h"
#import "RDInstance.h"

@implementation AppController
- (id)init {
	if (self = [super init]) {
	}
	
	return self;
}

- (void)awakeFromNib {
	[mainWindow setAcceptsMouseMovedEvents:YES];
}

- (IBAction)newServer:(id)sender {
	[NSApp beginSheet:newServerSheet 
	   modalForWindow:mainWindow
		modalDelegate:self
	   didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) 
		  contextInfo:NULL];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
	[sheet orderOut:self];
}

- (IBAction)hideOptions:(id)sender {
	NSRect windowFrame, boxFrame;

	boxFrame = [box frame];
	windowFrame = [newServerSheet frame];

	if (![sender state]) {
		[box setHidden:YES];
	}
	
	if ([sender state]) {
		windowFrame.size.height += boxFrame.size.height + 5.0;
		windowFrame.origin.y -= boxFrame.size.height + 5.0;
	} else {
		windowFrame.size.height -= boxFrame.size.height + 5.0;
		windowFrame.origin.y += boxFrame.size.height + 5.0;
	}
	
	[newServerSheet setFrame:windowFrame display:YES animate:YES];
	
	if ([sender state]) {
		[box setHidden:NO];
	}
}

- (IBAction)connectSheet:(id)sender {
	RDInstance *instance = [[RDInstance alloc] init];
	[instance setValue:[host stringValue] forKey:@"name"];
	[instance setValue:[host stringValue] forKey:@"displayName"];
	[instance setValue:[screenResolution titleOfSelectedItem] forKey:@"screenResolution"];
	[instance setValue:[colorDepth titleOfSelectedItem] forKey:@"colorDepth"];
	[instance setValue:[NSNumber numberWithInt:[forwardDisks intValue]] forKey:@"forwardDisks"];
	[instance setValue:[forwardAudio titleOfSelectedItem] forKey:@"forwardAudio"];
	[instance setValue:[NSNumber numberWithInt:[cacheBitmaps intValue]] forKey:@"cacheBitmaps"];
	[instance setValue:[NSNumber numberWithInt:[drawDesktop intValue]] forKey:@"drawDesktop"];
	[instance setValue:[NSNumber numberWithInt:[windowDrags intValue]] forKey:@"windowDrags"];
	[instance setValue:[NSNumber numberWithInt:[windowAnimation intValue]] forKey:@"windowAnimation"];
	[instance setValue:[NSNumber numberWithInt:[themes intValue]] forKey:@"themes"];
	
	[instance connect];
	
	NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:[tabView frame]];
	[scroll setDocumentView:[instance valueForKey:@"view"]];
	[scroll setHasVerticalScroller:YES];
	[scroll setHasHorizontalScroller:YES];
	[scroll setAutohidesScrollers:YES];
	[scroll setBorderType:NSNoBorder];

	
	NSTabViewItem *item = [[NSTabViewItem alloc] initWithIdentifier:[instance valueForKey:@"view"]];	
	[item setView:scroll];
	[item setLabel:[instance valueForKey:@"name"]];
	[tabView addTabViewItem:item];
	[mainWindow makeFirstResponder:[instance valueForKey:@"view"]];
	
	[arrayController addObject:instance];
	NSSize s = [[instance valueForKey:@"view"] frame].size;
	NSRect newFrame = NSMakeRect(0, 0, s.width + 251, s.height);
	[mainWindow setContentMaxSize:newFrame.size];
	
	NSMutableArray *recent = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:@"RecentServers"]];
	if (![recent containsObject:[host stringValue]]) {
		[recent addObject:[host stringValue]];
		[[NSUserDefaults standardUserDefaults] setObject:recent forKey:@"RecentServers"];
	}
	
	[NSApp endSheet:newServerSheet];
}

- (IBAction)cancelSheet:(id)sender {
	[NSApp endSheet:newServerSheet];
}

- (void)dealloc {
	[super dealloc];
}

@end
