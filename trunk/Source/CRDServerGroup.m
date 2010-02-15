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

#import "CRDServerGroup.h"


@implementation CRDServerGroup

@synthesize label, serverList, groupList;

+(CRDServerGroup *)initWithLabel:(NSString *)newLabel
{
	CRDServerGroup *serverGroup = [[CRDServerGroup alloc] initWithLabel:newLabel];
	
	return serverGroup;
}

- (id)init
{
	if (![super init])
		return nil;
	serverList = [[NSMutableArray alloc] init];
	groupList = [[NSMutableArray alloc] init];
	
	return self;
}

-(id)initWithLabel:(NSString *)newLabel
{
	[self init];
	[self setLabel:newLabel];
	
	return self;
}

- (void)dealloc
{
	[serverList release];
	[groupList release];
	[super dealloc];
}

-(void)addServer:(CRDSession *)server
{
	[serverList addObject:server];
}
-(void)removeServer:(CRDSession *)server
{
	[serverList removeObject:server];
}

-(void)addGroup:(CRDServerGroup *)group
{
	[groupList addObject:group];
}
-(void)removeGroup:(CRDServerGroup *)group
{
	[groupList removeObject:group];
}

-(NSMutableDictionary *)dumpToDictionary
{
	NSMutableDictionary *serverGroupContents = [[NSMutableDictionary alloc] initWithCapacity:1];
	[serverGroupContents setValue:[self label] forKey:@"label"];
	
	if ([serverList count] > 0) {
		
		NSMutableDictionary *serverGroupServerList = [[NSMutableDictionary alloc] initWithCapacity:1];
		for (CRDSession *session in serverList)
		{
			// CRDSession Method to Export Settings to a MutableDictionary
			// Add aforementioned MutableDiciontary to serverGroupServerList
		}
		
		[serverGroupContents setObject:serverGroupServerList forKey:@"serverList"];
	}
	
	if ([groupList count] > 0) {
		
		NSMutableDictionary *serverGroupGroupList = [[NSMutableDictionary alloc] initWithCapacity:1];
		for (CRDServerGroup *group in groupList)
		{
			[serverGroupGroupList setObject:[group dumpToDictionary] forKey:[group label]];
		}
			 
		[serverGroupContents setObject:serverGroupGroupList forKey:@"groupList"];
	 }
	
	return serverGroupContents;
}
-(void)exportToPlist:(NSString *)filename atPath:(NSString *)path
{
	NSMutableDictionary *plist = [self dumpToDictionary];
	[plist writeToFile:[path stringByAppendingPathComponent:filename] atomically:YES];
}
// Uncomment when we go to 10.6 only
//-(void)exportToPlist:(NSString *)filename atURL:(NSURL *)url
//{
//	NSMutableDictionary *plist = [self dumpToDictionary];
//	
//	[plist writeToURL:[url URLByAppendingPathComponent:filename] atomically:YES];
//}

-(NSInteger)count
{
	return [serverList count] + [groupList count];
}


@end
