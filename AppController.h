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

#import <Cocoa/Cocoa.h>

@class ConnectionsController;
@class RDInstance;


@interface AppController : NSObject
{
	IBOutlet NSWindow *mainWindow;
    IBOutlet NSWindow *serversWindow;
	IBOutlet NSTabView *tabView;
	IBOutlet ConnectionsController *serversManager;
	IBOutlet NSMenuItem *previewToggleMenu;
	IBOutlet NSMenu *quickConnectMenu;
	IBOutlet NSTextField *errorField;
	
	// Toolbar stuff
	NSToolbar *toolbar;
	NSMutableDictionary *staticToolbarItems;
	NSMutableArray *currentConnections;
	
	NSUserDefaults *userDefaults;
	BOOL previewsEnabled;
}

- (IBAction)disconnect:(id)sender;
- (void)changeSelection:(id)sender;
- (IBAction)selectNext:(id)sender;
- (IBAction)selectPrevious:(id)sender;
- (IBAction)showServerManager:(id)sender;
- (void)removeItem:(id)sender;
- (void)resizeToMatchSelection;
- (void)setStatus:(NSString *)status;
- (void)connectRDInstance:(id)instance;
- (void)connectAsync:(id)instance;
- (void)completeConnection:(id)arg;
- (id)selectedConnection;
- (int)selectedConnectionIndex;
- (id)connectionForLabel:(NSString *)label;
- (int)connectionIndexForLabel:(NSString *)label;
- (IBAction)togglePreviews:(id)sender;
- (IBAction)showQuickConnect:(id)sender;
- (void)setPreviewsVisible:(BOOL)visible;
- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames;
@end