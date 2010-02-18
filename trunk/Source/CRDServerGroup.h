/*	Copyright (c) 2010 Nick Peelman <nick@peelman.us>
	
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

@class CRDLabelCell;

@interface CRDServerGroup : NSObject {
	NSString *label;
	CRDLabelCell *labelCell;
	NSMutableArray *serverList, *groupList;
}

@property(retain) NSString *label;
@property (retain) CRDLabelCell *labelCell;
@property(nonatomic, retain) NSMutableArray *serverList, *groupList;

+(CRDServerGroup *)initWithLabel:(NSString *)newLabel;

-(id)initWithLabel:(NSString *)newLabel;

// Handle Servers
-(void)addServer:(CRDSession *)server;
-(void)removeServer:(CRDSession *)server;


// Handle Groups
-(void)addGroup:(CRDServerGroup *)group;
-(void)removeGroup:(CRDServerGroup *)group;

// Handle Input/Output
-(NSMutableDictionary *)dumpToDictionary;
-(void)exportToPlist:(NSString *)filename atPath:(NSString *)path;
// Uncomment when we go to 10.6 only
//-(void)exportToPlist:(NSString *)filename atURL:(NSURL *)url;

-(NSInteger)count;

@end
