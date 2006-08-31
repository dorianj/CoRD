/* AppController */

#import <Cocoa/Cocoa.h>

@interface AppController : NSObject
{
	IBOutlet NSWindow *mainWindow;
    IBOutlet NSWindow *newServerSheet;
	IBOutlet NSBox *box;
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
	NSArrayController *arr;
}
- (IBAction)newServer:(id)sender;
- (IBAction)hideOptions:(id)sender;
- (IBAction)connectSheet:(id)sender;
- (IBAction)cancelSheet:(id)sender;
@end
