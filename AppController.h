/* AppController */

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
