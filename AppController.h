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

@interface AppController : NSObject
{
	IBOutlet NSWindow *mainWindow;
    IBOutlet NSWindow *newServerSheet;
	IBOutlet NSBox *box;
	IBOutlet NSBox *box2;
	IBOutlet NSComboBox *host;
	IBOutlet NSPopUpButton *screenResolution;
	IBOutlet NSPopUpButton *colorDepth;
	IBOutlet NSButton *forwardDisks;
	IBOutlet NSPopUpButton *forwardAudio;
	IBOutlet NSButton *cacheBitmaps;
	IBOutlet NSButton *drawDesktop;
	IBOutlet NSButton *windowDrags;
	IBOutlet NSButton *windowAnimation;
	IBOutlet NSButton *themes;
	IBOutlet NSTabView *tabView;
	IBOutlet NSArrayController *arrayController;
	IBOutlet NSButton *disclosure;
}

- (IBAction)newServer:(id)sender;
- (IBAction)hideOptions:(id)sender;
- (IBAction)connectSheet:(id)sender;
- (IBAction)cancelSheet:(id)sender;
@end
