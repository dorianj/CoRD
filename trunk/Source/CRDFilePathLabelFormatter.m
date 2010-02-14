/*	Copyright (c) 2009 Nick Peelman <nick@peelman.us>
 
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

#import "CRDFilePathLabelFormatter.h"
#import "CRDShared.h"

@implementation CRDFilePathLabelFormatter

- (NSString *)stringForObjectValue:(id)obj
{
	if (obj == nil)
		obj = [NSString stringWithString:@""];
	
    return obj;
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString  **)error
{
	if (string == nil)
		*obj = @"";
	
	if ([string length] > 0 && [string length] <= 7)
	{
		if (obj)
			*obj = string;
			
		return YES;
	}
	
	if (error)
		*error = NSLocalizedString(@"Invalid label: Labels must exist, but are limited by Windows to 7 characters.", @"Invalid Label");
	
	return NO;
}

@end
