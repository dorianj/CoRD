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

+(void)file:(char*)sourceFile function:(char*)functionName lineNumber:(int)lineNumber format:(NSString*)format, ...;

#define ZNLog(s,...) [ZNLog file:__FILE__ function: (char *)__FUNCTION__ lineNumber:__LINE__ format:(s),##__VA_ARGS__]

@end


//  ZNLog.m
@implementation ZNLog

+ (void)file:(char*)sourceFile function:(char*)functionName lineNumber:(int)lineNumber format:(NSString*)format, ...
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  va_list ap;
  NSString *print, *file, *function;
  va_start(ap,format);
  file = [[NSString alloc] initWithBytes: sourceFile length: strlen(sourceFile) encoding: NSUTF8StringEncoding];

  function = [NSString stringWithCString: functionName];
  print = [[NSString alloc] initWithFormat: format arguments: ap];
  va_end(ap);
  NSLog(@"%@:%d %@; %@", [file lastPathComponent], lineNumber, function, print);
  [print release];
  [file release];
  [pool release];
}

@end