#import <Cocoa/Cocoa.h>
#import "ZNLog.h"


@interface PreferencesController : NSObject {
    IBOutlet NSView *connectionView;
    IBOutlet NSView *generalView;
    IBOutlet NSWindow *preferencesWindow;
    IBOutlet NSTabView *tabView;
	IBOutlet NSBox *generalBox;
	IBOutlet NSBox *sessionBox;
	IBOutlet NSBox *devicesBox;
	IBOutlet NSBox *performanceBox;	
	
	NSToolbar *prefsToolbar;
	NSMutableDictionary *toolbarItems;
}

-(void) mapTabsToToolbar;
-(IBAction)	changePanes: (id)sender;

@end
