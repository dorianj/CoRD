/*	Copyright (c) 2007-2011 Dorian Johnson <2011@dorianj.net>
	
	This file is part of CoRD.
	CoRD is free software; you can redistribute it and/or modify it under the
	terms of the GNU General Public License as published by the Free Software
	Foundation; either version 2 of the License, or (at your option) any later
	version.

	CoRD is distributed in the hope that it will be useful, but WITHOUT ANY
	WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
	FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with
	CoRD; if not, write to the Free Software Foundation, Inc., 51 Franklin St,
	Fifth Floor, Boston, MA 02110-1301 USA
*/

#import "CRDServerCell.h"

#import "CRDShared.h"
#import "CRDSession.h"
#import "AppController.h"

// Space between each line of text
#define PADDING_TEXT 0

// Space between image and text
#define PADDING_IMAGE 4

// Outside space
#define PADDING_TOP 3
#define PADDING_BOTTOM 3
#define PADDING_RIGHT 0
#define PADDING_LEFT 10

#define IMAGE_SIZE (abbreviatedSize ? SERVER_CELL_ABBREVIATED_IMAGE_SIZE : SERVER_CELL_FULL_IMAGE_SIZE)

// Initialize badge variables, based on Apple Mail.
static int BADGE_BUFFER_LEFT = 4;
static int BADGE_BUFFER_TOP = 1;
static int BADGE_BUFFER_LEFT_SMALL = 2;
static int BADGE_CIRCLE_BUFFER_RIGHT = 5;
static int BADGE_TEXT_HEIGHT = 14;
static int BADGE_X_RADIUS = 7;
static int BADGE_Y_RADIUS = 8;
static int BADGE_TEXT_SMALL = 20;


static NSDictionary *static_boldTextAttributes, *static_regularTextAttributes;
static NSColor *static_highlightedBoldColor, *static_normalBoldColor,
		*static_highlightedRegularColor, *static_normalRegularColor;

@interface CRDServerCell (Private)
	- (void)createProgressIndicator;
@end

@implementation CRDServerCell

+ (void)initialize
{
	NSMutableParagraphStyle *truncatingParagraph = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[truncatingParagraph setLineBreakMode:NSLineBreakByTruncatingTail];
	
	static_boldTextAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
			[NSFont fontWithName:@"LucidaGrande-Bold" size:11.5], NSFontAttributeName,
			truncatingParagraph, NSParagraphStyleAttributeName,
			nil] retain];
	
	static_normalBoldColor = [NSColor controlTextColor];
	static_highlightedBoldColor = [NSColor selectedControlTextColor];
	
	
	static_regularTextAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
			[NSFont fontWithName:@"LucidaGrande" size:10.5], NSFontAttributeName,
			truncatingParagraph, NSParagraphStyleAttributeName, 
			nil] retain];
		
	static_normalRegularColor = [[[NSColor textColor] colorWithAlphaComponent:0.75] retain];
	static_highlightedRegularColor = [[[NSColor selectedTextColor] colorWithAlphaComponent:0.75] retain];
}

#pragma mark -
#pragma mark NSObject

- (id)init
{
	if (![super init])
		return nil;
		
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(listStyleDidChange:) name:CRDMinimalViewDidChangeNotification object:nil];
	
	[self listStyleDidChange:nil];
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
	CRDServerCell *newInst = [super copyWithZone:zone];
	
	newInst->host = newInst->user = newInst->label = nil;
	[newInst setDisplayedText:[label string] username:[user string] address:[host string]];
		
	[newInst setImage:[image retain]];
	[newInst setStatus:status];
	
	return newInst;
}

- (void)dealloc
{
	[label release]; [user release]; [host release];
	[image release];
	[progressIndicator removeFromSuperview];
	[progressIndicator release];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[super dealloc];
}


#pragma mark -
#pragma mark NSCell

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)controlView
{	
	if (frame.size.height < 5.0)
		return;
	
 	NSRect imgRect = NSMakeRect(frame.origin.x + PADDING_LEFT, frame.origin.y + (frame.size.height / 2.0) - (IMAGE_SIZE / 2.0), IMAGE_SIZE, IMAGE_SIZE);
	CRDSession *inst = [g_appController serverInstanceForRow:[[g_appController valueForKey:@"gui_serverList"] rowAtPoint:imgRect.origin]];
	
	// Draw the image or progress indicator
	if ( ([inst status] == CRDConnectionConnecting) && (controlView != nil) )
	{
		[self createProgressIndicator];
		if ([progressIndicator superview] != controlView)
			[controlView addSubview:progressIndicator];

		[progressIndicator setControlSize:(abbreviatedSize ? NSSmallControlSize : NSRegularControlSize)];
		[progressIndicator setFrame:imgRect];
		[progressIndicator sizeToFit];
		[progressIndicator startAnimation:self];
	}
	else 
	{
		if ( (controlView != nil) && (progressIndicator != nil) )
		{
			[progressIndicator stopAnimation:self];
			[progressIndicator removeFromSuperview];
		}

		[NSGraphicsContext saveGraphicsState];
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh]; 
		[image drawInRect:imgRect fromRect:CRDRectFromSize([image size]) operation:NSCompositeSourceOver fraction:1.0];
		[NSGraphicsContext restoreGraphicsState];
	}
	
	// Set up text styling
	if (highlighted) {
		if ([[NSApp mainWindow] isKeyWindow]) {
			CRDSetAttributedStringColor(label, static_highlightedBoldColor);
			CRDSetAttributedStringColor(user, static_highlightedRegularColor);
			CRDSetAttributedStringColor(host, static_highlightedRegularColor);
		} else {
			CRDSetAttributedStringColor(label, [NSColor textColor]);
			CRDSetAttributedStringColor(user, [NSColor textColor]);
			CRDSetAttributedStringColor(host, [NSColor textColor]);			
		}
	} else {
		CRDSetAttributedStringColor(label, static_normalBoldColor);
		CRDSetAttributedStringColor(user, static_normalRegularColor);
		CRDSetAttributedStringColor(host, static_normalRegularColor);
	}
	
	if (abbreviatedSize) {
		CRDSetAttributedStringFont(label, [NSFont fontWithName:@"LucidaGrande" size:11]);
	} else {
		CRDSetAttributedStringFont(label, [NSFont fontWithName:@"LucidaGrande-Bold" size:11.5]);
	}
	
	// Position text then draw
	float textHeight = [label size].height;
	
	if (!abbreviatedSize)
		textHeight += [user size].height;
	
	float textX = imgRect.origin.x + imgRect.size.width + PADDING_IMAGE;
	float textY = frame.origin.y + ((frame.size.height-textHeight) / 4.0);  // center vertically
	float textWidth = frame.size.width - (textX - frame.origin.x) - PADDING_LEFT;

	[label drawWithRect:NSMakeRect(textX, textY, textWidth, FLT_MAX) options:NSStringDrawingUsesLineFragmentOrigin];
	
	if (!abbreviatedSize)
	{
		[user drawWithRect:NSMakeRect(textX, textY += [label size].height + PADDING_TEXT, textWidth, FLT_MAX) options:NSStringDrawingUsesLineFragmentOrigin];
		[host drawWithRect:NSMakeRect(textX, textY + [user size].height + PADDING_TEXT, textWidth, FLT_MAX) options:NSStringDrawingUsesLineFragmentOrigin];
	}
	
	// If a hotkey is set, badge the cell accordingly
	if ([inst hotkey] > -1) {
		
		// Set up badge string and size.
		NSString *badge = [NSString stringWithFormat:@"%@%d", [NSString stringWithUTF8String:"\xE2\x8C\x98"], [inst hotkey]];
		NSSize badgeNumSize = [badge sizeWithAttributes:nil];
		
		// Calculate the badge's coordinates.
		int badgeWidth = badgeNumSize.width + BADGE_BUFFER_LEFT * 2;
		if (badgeWidth < BADGE_TEXT_SMALL)
		{
			// The text is too short. Decrease the badge's size.
			badgeWidth = BADGE_TEXT_SMALL;
		}
		int badgeX = frame.origin.x + frame.size.width - BADGE_CIRCLE_BUFFER_RIGHT - badgeWidth;
		int badgeY = textY;
		int badgeNumX = badgeX + BADGE_BUFFER_LEFT;
		if (badgeWidth == BADGE_TEXT_SMALL)
		{
			badgeNumX += BADGE_BUFFER_LEFT_SMALL;
		}
		NSRect badgeRect = NSMakeRect(badgeX, badgeY, badgeWidth, BADGE_TEXT_HEIGHT);
		
		// Draw the badge and number.
		NSBezierPath *badgePath = [NSBezierPath bezierPathWithRoundedRect:badgeRect xRadius:BADGE_X_RADIUS yRadius:BADGE_Y_RADIUS];
		NSDictionary *dict;
		if (highlighted) {
			[[NSColor whiteColor] set];
			dict = static_regularTextAttributes;
		} else if (![[NSApp mainWindow] isKeyWindow]) {
			[[[NSColor selectedControlColor] colorWithAlphaComponent:0.50] set];
			dict = static_regularTextAttributes;
		} else {
			[[NSColor selectedControlColor] set];
			dict = static_regularTextAttributes;
		}
		
		[badgePath fill];
		[badge drawAtPoint:NSMakePoint(badgeNumX,badgeY) withAttributes:dict];
		

	}
	
}

- (NSSize)cellSize
{
	NSSize textSize, overallSize;
	
	/*textSize.height = [label size].height;
	
	if (abbreviatedSize)
		textSize.height += [user size].height + [host size].height + PADDING_TEXT*2;*/
		
	textSize.width  = [label size].width;

	overallSize.width = PADDING_LEFT + PADDING_RIGHT + IMAGE_SIZE + PADDING_IMAGE + textSize.width;
	overallSize.height = abbreviatedSize ? 16 : 46; //PADDING_BOTTOM + PADDING_TOP + MAX(textSize.height, IMAGE_SIZE);
	
	return overallSize;
}

- (void)setHighlighted:(BOOL)flag
{
	highlighted = flag;
}
- (BOOL)isHighlighted
{
	return highlighted;
}

- (void)setImage:(NSImage *)img
{
	[img retain];
	[image autorelease];
	image = img;
}
- (NSImage *)image
{
	return image;
}

- (void)setObjectValue:(id)obj
{
	// CRDSessionCell doesn't conform to NSCopying, thus, make sure super doesn't try to copy it here.
}


#pragma mark -
#pragma mark Working with the displayed info

- (void)setDisplayedText:(NSString *)displayName username:(NSString *)username address:(NSString *)address
{
	[label release]; [user release]; [host release];
	
	label = [[NSMutableAttributedString alloc] initWithString:displayName attributes:static_boldTextAttributes];
	user =  [[NSMutableAttributedString alloc] initWithString:username attributes:static_regularTextAttributes];
	host =  [[NSMutableAttributedString alloc] initWithString:address attributes:static_regularTextAttributes];
}

- (void)listStyleDidChange:(NSNotification *)notification
{	
	abbreviatedSize = CRDPreferenceIsEnabled(CRDPrefsMinimalisticServerList);
}

#pragma mark -
#pragma mark Internal use

- (void)createProgressIndicator
{
	if (progressIndicator != nil)
		return;
		
	progressIndicator = [[NSProgressIndicator alloc] initWithFrame:CRDRectFromSize([self cellSize])];
	[progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
}



#pragma mark -
#pragma mark Accessors
- (CRDConnectionStatus)status
{
	return status;
}

- (void)setStatus:(CRDConnectionStatus)connStatus
{
	status = connStatus;

	if (status == CRDConnectionConnecting)
        [progressIndicator startAnimation:self];
    else
        [progressIndicator stopAnimation:self];
}

@end



