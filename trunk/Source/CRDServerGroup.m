//
//  CRDServerGroup.m
//  Cord
//
//  Created by Nick Peelman on 2/14/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "CRDServerGroup.h"


@implementation CRDServerGroup

@synthesize label, serverList, groupList;

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

-(NSInteger)count
{
	return [serverList count];
}

@end
