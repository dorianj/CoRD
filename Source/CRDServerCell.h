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

#import <Cocoa/Cocoa.h>
#import "CRDShared.h"

#define SERVER_CELL_FULL_IMAGE_SIZE 36
#define SERVER_CELL_ABBREVIATED_IMAGE_SIZE 16


@interface CRDServerCell : NSCell
{
	NSMutableAttributedString *label, *user, *host;
	NSImage *image;
	BOOL highlighted;
	CRDConnectionStatus status;
	NSProgressIndicator *progressIndicator;
	NSTimer *progressIndicatorTimer;
	
	BOOL abbreviatedSize;
}

- (void)setDisplayedText:(NSString *)displayName username:(NSString *)username address:(NSString *)address;
- (void)setStatus:(CRDConnectionStatus)connStatus;
- (CRDConnectionStatus)status;
- (void)listStyleDidChange:(NSNotification *)notification;

@end
