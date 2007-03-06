//  Copyright (c) 2006 Dorian Johnson <arcadiclife@gmail.com>
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

/*	Purpose: reads and writes Microsoft formatted .rdp files. Passwords aren't
		saved to file.
*/

#import "RDPFile.h"


@implementation RDPFile
#pragma mark Accessors
- (NSString *)label
{
	id fileLabel = [self getStringAttribute:@"cord label"];
	if (fileLabel == nil)
		fileLabel = [[pathLoadedFrom lastPathComponent] stringByDeletingPathExtension];	

	return (NSString *)fileLabel;
}
- (void)setLabel:(NSString *)newLabel
{
	[attributes setObject:newLabel forKey:@"cord label"];
}
// Returns the path that this was loaded from, if any
- (NSString *)filename
{
	return pathLoadedFrom;
}
- (void)setFilename:(NSString *)path
{
	[path retain];
	[pathLoadedFrom release];
	pathLoadedFrom = path; 
}

- (NSString *)password {
	return password;
}

- (void)setPassword:(NSString *)pass {
	[pass retain];
	[password release];
	password = pass;
}

#pragma mark Attribute methods

- (NSDictionary *) attributes
{
	return [attributes copy];
}
- (void) setAttributes:(NSDictionary *) newMap
{
	[attributes release];
	attributes = [newMap mutableCopy];
}

- (NSString *) getStringAttribute:(NSString *) name
{
	id attribute = [self getAttribute:name];
	if ([attribute isKindOfClass:[NSString class]])
		return attribute;
	else
		return nil;
}

- (int) getIntAttribute:(NSString *) name
{
	id attribute = [self getAttribute:name];
	if ([attribute isKindOfClass:[NSNumber class]])
		return [attribute intValue];
	else
		return 0;
}

- (BOOL) getBoolAttribute:(NSString *) name
{
	return [self getIntAttribute:name] == 1;
}

- (id) getAttribute:(NSString *)name
{
	return [attributes objectForKey:name];
}

/*
- (void) setAttribute:(NSString *)name value:(id)value
{
	[attributes setObject:value forKey:name];
}*/

- (BOOL) hasValueForName:(NSString *)name
{
	return [attributes objectForKey:name] != nil;
}


#pragma mark General methods
- (NSString *) descriptionBrief
{
	id username = [attributes objectForKey:@"username"];
	id host = [attributes objectForKey:@"full address"];
	if (username != nil && ![username isEqual:@""])
		return [NSString stringWithFormat:@"%@/%@", host, username];
	else
		return [host description];
}

#pragma mark File reading/writing methods
- (void) writeToFile:(NSString *)filename
{
	NSMutableArray *lines = [NSMutableArray arrayWithCapacity:[attributes count]];
	NSString *type;
	id value, key;
	NSEnumerator *enumerator = [attributes keyEnumerator];
	while ( (key = [enumerator nextObject]) && (value = [attributes objectForKey:key]) )
	{
		type = ([value isKindOfClass:[NSNumber class]]) ? @"i" : @"s";	
		[lines addObject:[NSString stringWithFormat:@"%@:%@:%@", key, type, value]];
	}
	
	[[lines componentsJoinedByString:@"\r\n"] writeToFile:filename atomically:YES
			encoding:NSASCIIStringEncoding error:nil];
}

+ (RDPFile *) rdpFromFile:(NSString *) filename
{
	NSError *fileError = nil;
	NSString *fileContents = [NSString stringWithContentsOfFile:filename
			encoding:NSASCIIStringEncoding error:&fileError];
	if (fileError != nil) {
		NSLog(@"Couldn't open  file '%@'! Details: \n%@", filename, fileError);
		return nil;
	}
	
	RDPFile *newFile = [[RDPFile alloc] init];
	NSArray *fileLines = [fileContents componentsSeparatedByString:@"\r\n"];
	NSMutableDictionary *attributesBuilder = [NSMutableDictionary dictionaryWithCapacity:10];
	NSString *thisName, *thisType;
	id thisValue;
	NSScanner *scan;
	NSCharacterSet *colonSet = [NSCharacterSet characterSetWithCharactersInString:@":"];
	
	// Loop through each line, extracting the name, type, and value
	NSEnumerator *enumerator = [fileLines objectEnumerator];
	id thisLine;
	while ( (thisLine = [enumerator nextObject]) )
	{
		if ([thisLine length] > 1)
		{
			scan = [[NSScanner alloc] initWithString:thisLine];
			[scan setCharactersToBeSkipped:colonSet];
			[scan scanUpToCharactersFromSet:colonSet intoString:&thisName];
			[scan scanUpToCharactersFromSet:colonSet intoString:&thisType];
			
			if ([thisType isEqual:@"s"]) {
				thisValue = [thisLine substringFromIndex:[scan scanLocation]+1];
			} else if ([thisType isEqual:@"i"]) {
				int x = 0;
				if (![scan scanInt:&x]) NSLog(@"Bad scan!");
				thisValue = [NSNumber numberWithInt:x];
			} else if ([thisType isEqual:@"b"]) {
				// UNIMPLEMENTED TYPE: byte data. Only used for passwords, which
				//	cannot be read anyways (they are encrypted with some info
				//	specific to the Windows install it was run on, if I understand
				//	correctly)
				thisValue = nil;
			} else thisValue = nil;
			
			[attributesBuilder setObject:thisValue forKey:thisName];
			[scan release];
		}
	}
	
	if ([attributesBuilder count] > 0) {
		[newFile setFilename:filename];
		[newFile setAttributes:attributesBuilder];
		[newFile autorelease];
	} else
		[newFile release];
	
	return newFile;
}

#pragma mark NSObject overrides
- (id) init {
	self = [super init];
	if (self != nil) {
		attributes = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void) dealloc {
	[pathLoadedFrom release];
	[attributes release];
	[super dealloc];
}






@end