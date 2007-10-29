/*	Copyright (c) 2007 Dorian Johnson <arcadiclife@gmail.com>
	
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

#import <Cocoa/Cocoa.h>
#import "miscellany.h"

#define CELL_IMAGE_HEIGHT 36
#define CELL_IMAGE_WIDTH  36


@interface CRDServerCell : NSCell
{
	NSMutableAttributedString *label; // First line
	NSMutableAttributedString *user;  // Second line
	NSMutableAttributedString *host;  // Third line
	NSImage *image;
	BOOL highlighted;
	CRDConnectionStatus status;
	NSProgressIndicator *progressIndicator;
	NSTimer *progressIndicatorTimer;
}

- (void)setDisplayedText:(NSString *)displayName username:(NSString *)username address:(NSString *)address;

- (void)setStatus:(CRDConnectionStatus)connStatus;
- (CRDConnectionStatus)status;

@end
