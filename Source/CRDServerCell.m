/*	Copyright (c) 2007-2008 Dorian Johnson <info-2008@dorianjohnson.com>
	
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

#define FULL_IMAGE_SIZE 36
#define ABBREVIATED_IMAGE_SIZE 16
#define IMAGE_SIZE (abbreviatedSize ? ABBREVIATED_IMAGE_SIZE : FULL_IMAGE_SIZE)

static NSDictionary *static_boldTextAtrributes, *static_regularTextAttributes;
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
	
	static_boldTextAtrributes = [[NSDictionary dictionaryWithObjectsAndKeys:
			[NSFont fontWithName:@"LucidaGrande-Bold" size:11.5], NSFontAttributeName,
			truncatingParagraph, NSParagraphStyleAttributeName,
			nil] retain];
	
	static_normalBoldColor = [[NSColor blackColor] retain];
	static_highlightedBoldColor = [[NSColor whiteColor] retain];
	
	
	static_regularTextAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
			[NSFont fontWithName:@"LucidaGrande" size:10.5], NSFontAttributeName,
			truncatingParagraph, NSParagraphStyleAttributeName, 
			nil] retain];
		
	static_normalRegularColor = [[NSColor colorWithDeviceRed:(115/255.0) green:(115/255.0) blue:(115/255.0) alpha:1.0] retain];
	static_highlightedRegularColor = [[NSColor colorWithDeviceRed:0.85 green:0.85 blue:0.85 alpha:1.0] retain];
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
	
	newInst->progressIndicatorTimer = [progressIndicatorTimer retain];
	newInst->progressIndicator = [progressIndicator retain];
	
	[newInst setImage:[image retain]];
	[newInst setStatus:status];
	
	return newInst;
}

- (void)dealloc
{
	[label release]; [user release]; [host release];
	[image release];
	[progressIndicatorTimer release];
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
		
		[progressIndicator setFrame:imgRect];
	}
	else 
	{
		if ( (controlView != nil) && (progressIndicator != nil) )
			[progressIndicator removeFromSuperview];
			
		[NSGraphicsContext saveGraphicsState];
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh]; 
		[image drawInRect:imgRect fromRect:CRDRectFromSize([image size]) operation:NSCompositeSourceOver fraction:1.0];
		[NSGraphicsContext restoreGraphicsState];
	}
	
	// Set up text styling
	if (highlighted) {
		CRDSetAttributedStringColor(label, static_highlightedBoldColor);
		CRDSetAttributedStringColor(user, static_highlightedRegularColor);
		CRDSetAttributedStringColor(host, static_highlightedRegularColor);
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
		textHeight += [user size].height, [host size].height;
	
	float textX = imgRect.origin.x + imgRect.size.width + PADDING_IMAGE;
	float textY = frame.origin.y + ((frame.size.height-textHeight) / 4.0);  // center vertically
	float textWidth = frame.size.width - (textX - frame.origin.x) - PADDING_LEFT;
	
	[label drawWithRect:NSMakeRect(textX, textY, textWidth, 0.0) options:NSStringDrawingUsesLineFragmentOrigin];
	
	if (!abbreviatedSize)
	{
		[user drawWithRect:NSMakeRect(textX, textY += [label size].height + PADDING_TEXT, textWidth, 0.0) options:NSStringDrawingUsesLineFragmentOrigin];
		[host drawWithRect:NSMakeRect(textX, textY += [user size].height + PADDING_TEXT, textWidth, 0.0) options:NSStringDrawingUsesLineFragmentOrigin];
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

	//NSLog(@"overallHeight=%d", overallSize.height);
	
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
	// CRDSession doesn't conform to NSCopying, thus, make sure super doesn't try to copy it here.
}


#pragma mark -
#pragma mark Working with the displayed info

- (void)setDisplayedText:(NSString *)displayName username:(NSString *)username address:(NSString *)address
{
	[label release]; [user release]; [host release];
	
	label = [[NSMutableAttributedString alloc] initWithString:displayName attributes:static_boldTextAtrributes];
	user =  [[NSMutableAttributedString alloc] initWithString:username attributes:static_regularTextAttributes];
	host =  [[NSMutableAttributedString alloc] initWithString:address attributes:static_regularTextAttributes];
}

- (void)listStyleDidChange:(NSNotification *)notification
{	
	abbreviatedSize = CRDPreferenceIsEnabled(CRDPrefsMinimalisticServerList);
}

#pragma mark -
#pragma mark Internal use

- (void)progressTimerFire:(NSTimer*)theTimer
{
	[progressIndicator animate:self];
	[g_appController cellNeedsDisplay:self];
}

- (void)createProgressIndicator
{
	if (progressIndicator != nil)
		return;
		
	progressIndicator = [[NSProgressIndicator alloc] initWithFrame:CRDRectFromSize([self cellSize])];
	[progressIndicator setIndeterminate:YES];
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
	{
		if (progressIndicatorTimer == nil)
		{
			progressIndicatorTimer = [[NSTimer scheduledTimerWithTimeInterval:(5.0/60.0) target:self selector:@selector(progressTimerFire:) userInfo:nil repeats:YES] retain];
		}
	}
	else
	{
		[progressIndicatorTimer invalidate];
		[progressIndicatorTimer release];
		progressIndicatorTimer = nil;
	}
}

@end



