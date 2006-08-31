#import "AppController.h"

@implementation AppController


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
	[NSApp endSheet:newServerSheet];
}

- (IBAction)cancelSheet:(id)sender {
	[NSApp endSheet:newServerSheet];
}

@end
