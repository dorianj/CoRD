#import <Cocoa/Cocoa.h>
#import "ZNLog.h"


@interface PreferencesController : NSObject {
    IBOutlet NSView *connectionView;
    IBOutlet NSView *generalView;
	IBOutlet NSView *advancedView;
    IBOutlet NSWindow *preferencesWindow;
	IBOutlet NSBox *sessionBox;
	IBOutlet NSBox *devicesBox;
	IBOutlet NSBox *performanceBox;	
	IBOutlet NSUserDefaultsController *defaultsController;
	IBOutlet NSButton *showAdvancedCheckbox;

	NSUserDefaults *userDefaults;
	NSToolbar *prefsToolbar;
	NSMutableDictionary *toolbarItems;
}

-(void) mapTabsToToolbar;
-(IBAction)	changePanes: (id)sender;
-(IBAction) toggleAdvanced: (id)sender;

@end
