/*	Copyright (c) 2009-2012 Nick Peelman <nick@peelman.us>
 
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

#import "CRDScreenResFormatter.h"
#import "CRDShared.h"

@implementation CRDScreenResFormatter

- (NSString *)stringForObjectValue:(id)anObject
{
    return anObject;
}

- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString  **)error
{
	if (CRDResolutionStringIsFullscreen(string))
	{
		if (obj)
			*obj = string;
			
		return YES;
	}
	
	BOOL separatorIsValid = [[NSSet setWithObjects:@"x", @"*", nil] containsObject:[string stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]]];
	
	if (separatorIsValid && ([string length] > 6 && [string length] <= 9) )
	{
		if (obj)
			*obj = string;
			
		return YES;
	}
	else if (error)
	{
		*error = NSLocalizedString(@"Invalid resolution: please enter a valid screen resolution, like '1024x768'.", @"Invalid Resolution");
    }
	
	return NO;
	
}

@end
