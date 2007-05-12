//  Copyright (c) 2007 Dorian Johnson <arcadiclife@gmail.com>
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

#import "CRDServerCell.h"

#import "miscellany.h"
#import "AppController.h"

// padding between each line of text
#define TEXT_PADDING 0

// padding on outer border
#define OUTER_PADDING 3

// Extra padding from the left
#define PADDING_LEFT 6

// Padding between image and text
#define SEPARATOR_PADDING 4

@implementation CRDServerCell

static NSDictionary *boldTextAtrributes;
static NSColor *highlightedBold, *normalBold;
static NSDictionary *regularTextAttributes;
static NSColor *highlightedRegular, *normalRegular;
static BOOL staticsInitialized;

#pragma mark NSObject Methods
- (id) init
{
	if (![super init])
		return nil;
	
	if (!staticsInitialized)
	{
		NSMutableParagraphStyle *truncatingParagraph = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
		[truncatingParagraph setLineBreakMode:NSLineBreakByTruncatingTail];
		
		boldTextAtrributes = [[NSDictionary dictionaryWithObjectsAndKeys:
				[NSFont fontWithName:@"LucidaGrande-Bold" size:11.5], NSFontAttributeName,
				truncatingParagraph, NSParagraphStyleAttributeName,
				nil] retain];
		
		normalBold = [[NSColor blackColor] retain];
		highlightedBold = [[NSColor whiteColor] retain];
		
		
		regularTextAttributes = [[NSDictionary dictionaryWithObjectsAndKeys:
				[NSFont fontWithName:@"LucidaGrande" size:10.5], NSFontAttributeName,
				truncatingParagraph, NSParagraphStyleAttributeName, 
				nil] retain];
			
		normalRegular = [[NSColor colorWithDeviceRed:(115/255.0) green:(115/255.0) blue:(115/255.0) alpha:1.0] retain];
		highlightedRegular = [[NSColor colorWithDeviceRed:0.85 green:0.85 blue:0.85 alpha:1.0] retain];
		
		staticsInitialized = YES;
	}
	
	progressIndicator = [[NSProgressIndicator alloc] initWithFrame:RECT_FROM_SIZE([self cellSize])];
	[progressIndicator setIndeterminate:YES];
	[progressIndicator setStyle:NSProgressIndicatorSpinningStyle];
		
	return self;
}

- (void) dealloc
{
	[label release]; [user release]; [host release];
	[image release];
	[progressIndicatorTimer release];
	[progressIndicator removeFromSuperview];
	[progressIndicator release];
	[super dealloc];
}


#pragma mark -
#pragma mark NSCell

- (void) drawWithFrame:(NSRect)frame inView:(NSView *)controlView
{	
	if (frame.size.height < 5.0)
		return;
	
 	NSRect imgRect = NSMakeRect(frame.origin.x + OUTER_PADDING + PADDING_LEFT, frame.origin.y + (frame.size.height / 2.0) - (CELL_IMAGE_HEIGHT / 2.0), CELL_IMAGE_WIDTH, CELL_IMAGE_HEIGHT);
	RDInstance *inst = [g_appController serverInstanceForRow:[[g_appController valueForKey:@"gui_serverList"] rowAtPoint:imgRect.origin]];
	
	// Draw the image or progress indicator
	if ( ([inst status] == CRDConnectionConnecting) && (controlView != nil) )
	{
		if([progressIndicator superview] != controlView)
			[controlView addSubview:progressIndicator];
		
		[progressIndicator setFrame:imgRect];
	}
	else 
	{
		if (controlView != nil)
			[progressIndicator removeFromSuperview];
		[image drawInRect:imgRect fromRect:RECT_FROM_SIZE([image size]) operation:NSCompositeSourceOver fraction:1.0];
	}
	

	// Draw the text
	float textX = frame.origin.x + PADDING_LEFT + OUTER_PADDING + CELL_IMAGE_WIDTH + SEPARATOR_PADDING;
	float textY = frame.origin.y + OUTER_PADDING; 
	float textWidth = frame.size.width - (textX - frame.origin.x) - OUTER_PADDING;
	
	if (highlighted)
	{
		[label addAttribute:NSForegroundColorAttributeName value:highlightedBold range:NSMakeRange(0, [label length])];
		[user  addAttribute:NSForegroundColorAttributeName value:highlightedRegular range:NSMakeRange(0, [user length])];
		[host  addAttribute:NSForegroundColorAttributeName value:highlightedRegular range:NSMakeRange(0, [host length])];
	}
	else
	{
		[label addAttribute:NSForegroundColorAttributeName value:normalBold range:NSMakeRange(0, [label length])];
		[user  addAttribute:NSForegroundColorAttributeName value:normalRegular range:NSMakeRange(0, [user length])];
		[host  addAttribute:NSForegroundColorAttributeName value:normalRegular range:NSMakeRange(0, [host length])];
	}
	
	[label drawWithRect:NSMakeRect(textX, textY, textWidth, 0.0) options:NSStringDrawingUsesLineFragmentOrigin];
	[user drawWithRect:NSMakeRect(textX, textY += [label size].height + TEXT_PADDING, textWidth, 0.0) options:NSStringDrawingUsesLineFragmentOrigin];
	[host drawWithRect:NSMakeRect(textX, textY += [user size].height + TEXT_PADDING, textWidth, 0.0) options:NSStringDrawingUsesLineFragmentOrigin];
	
}

- (NSSize)cellSize
{
	int textHeight = [label size].height + [user size].height + [host size].height + TEXT_PADDING*2;
	int textWidth  = MAX( MAX([label size].width, [user size].width), [host size].width);
	
	int overallWidth = PADDING_LEFT + OUTER_PADDING*2 + CELL_IMAGE_WIDTH + SEPARATOR_PADDING + textWidth;
	int overallHeight = OUTER_PADDING*2 + MAX(textHeight, CELL_IMAGE_HEIGHT);
	
	return NSMakeSize(overallWidth, /*overallHeight*/ 46); 
}

- (void)setHighlighted:(BOOL)flag
{
	highlighted = flag;
}
- (BOOL)highlighted
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
	// RDInstance doesn't conform to NSCopying, thus, make sure super doesn't try to copy it here
}

#pragma mark -

- (void)setDisplayedText:(NSString *)displayName username:(NSString *)username address:(NSString *)address
{
	[label release]; [user release]; [host release];
	
	label = [[NSMutableAttributedString alloc] initWithString:displayName attributes:boldTextAtrributes];
	user =  [[NSMutableAttributedString alloc] initWithString:username attributes:regularTextAttributes];
	host =  [[NSMutableAttributedString alloc] initWithString:address attributes:regularTextAttributes];
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

#pragma mark -
#pragma mark Other methods

- (void)progressTimerFire:(NSTimer*)theTimer
{
	[progressIndicator animate:self];
	[g_appController cellNeedsDisplay:self];
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
			progressIndicatorTimer = [[NSTimer scheduledTimerWithTimeInterval:(5.0/60.0) target:self
					selector:@selector(progressTimerFire:) userInfo:nil repeats:YES] retain];
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



