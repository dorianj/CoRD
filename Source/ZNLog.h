//
//  ZNLog
//
//  Created by Tony on 24/01/07.
//  Copyright 2007 boomBalada! Productions..
//  Some rights reserved: <http://creativecommons.org/licenses/by/2.5/>
//

//  ZNLog.h
#import <Cocoa/Cocoa.h>

@interface ZNLog : NSObject {}

+ (void)file:(char *)sourceFile function:(char *)functionName lineNumber:(NSInteger)lineNumber format:(NSString *)format, ...;

#define ZNLog(s,...) [ZNLog file:__FILE__ function:(char *)__FUNCTION__ lineNumber:__LINE__ format:(s),##__VA_ARGS__]
@end
