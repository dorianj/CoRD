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
	[scroll setBorderType:NSGrooveBorder];
	NSRect newFrame = NSMakeRect(0, 0, 1227, 772);
	[mainWindow setContentMaxSize:newFrame.size];
	
	NSTabViewItem *item = [[NSTabViewItem alloc] initWithIdentifier:[instance valueForKey:@"view"]];	
	[item setView:scroll];
	[item setLabel:[instance valueForKey:@"name"]];
	[tabView addTabViewItem:item];
	
	[arrayController addObject:instance];
	
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
