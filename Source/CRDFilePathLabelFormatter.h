/*	Copyright (c) 2009-2011 Nick Peelman <nick@peelman.us>
 
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

@interface CRDFilePathLabelFormatter : NSFormatter {

}

- (NSString *)stringForObjectValue:(id)anObject;
- (BOOL)getObjectValue:(id *)obj forString:(NSString *)string errorDescription:(NSString  **)error;

@end
