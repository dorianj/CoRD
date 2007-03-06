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


#import <Cocoa/Cocoa.h>


@interface RDPFile : NSObject {
	NSMutableDictionary *attributes;
	NSString *pathLoadedFrom;
	NSString *password;
}
/* Accessors */
- (NSString *)label;
- (void)setLabel:(NSString *)newLabel;
- (NSString *)filename;
- (void)setFilename:(NSString *)path;
- (NSString *)password;
- (void)setPassword:(NSString *)pass;

/* Accessing data */
- (NSDictionary *) attributes;
- (NSString *) getStringAttribute:(NSString *) name;
- (int) getIntAttribute:(NSString *) name;
- (BOOL) getBoolAttribute:(NSString *) name;
- (id) getAttribute:(NSString *)name;
- (BOOL) hasValueForName:(NSString *)name;
- (void) setAttributes:(NSDictionary *)newMap;

- (NSString *) descriptionBrief;

- (void) writeToFile:(NSString *)filename;

+ (RDPFile *) rdpFromFile:(NSString *) filename;


@end