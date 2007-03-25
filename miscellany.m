//  Copyright (c) 2007 Dorian Johnson <arcadiclife@gmail.com>
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

#include "miscellany.h"


#pragma mark General purpose
const char *safe_string_conv(void *src)
{
	return (src) ? [(NSString *)src UTF8String] : "";
}

#pragma mark AppController
NSToolbarItem * create_static_toolbar_item(NSView *view, NSString *name, NSString *tooltip, SEL action)
{
	NSToolbarItem *item = [[[NSToolbarItem alloc] initWithItemIdentifier:name] autorelease];
	[item setPaletteLabel:name];
	[item setLabel:name];
	[item setToolTip:tooltip];
	[item setAction:action];
	if (view)
	{
		[item setView:view];
		[item setMinSize:[view bounds].size];
		[item setMaxSize:[view bounds].size];
	}
	else
		[item setImage:[NSImage imageNamed:[NSString stringWithFormat:@"%@.png", name]]];
		
	return item;
}

int wrap_array_index(int start, int count, signed int modifier) {
	int new = start + modifier;
	if (new < 0)
		new = count-1;
	else if
		(new >= count) new = 0;
	return new;
}


#pragma mark ConnectionsController
void ensureDirectoryExists(NSString *path, NSFileManager *manager) {
	BOOL isDir;
	if (![manager fileExistsAtPath:path isDirectory:&isDir])
		[manager createDirectoryAtPath:path attributes:nil];
}

/* Keeps trying filenames until it finds one that isn't taken.. eg: given "Untitled","rdp", if 
	'Untitled.rdp' is taken, it will try 'Untitled 1.rdp', 'Untitled 2.rdp', etc until one is found,
	then it returns the found filename */
NSString * findAvailableFileName(NSString *path, NSString *base, NSString *extension)
{
	NSString *filename = [base stringByAppendingString:extension];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	int i = 0;
	while ([fileManager fileExistsAtPath:[path stringByAppendingPathComponent:filename]] && ++i<100)
		filename = [base stringByAppendingString:[NSString stringWithFormat:@"-%d%@", i, extension]];
		
	return filename;
}

void split_hostname(NSString *address, NSString **host, int *port)
{ 
	NSScanner *scan = [NSScanner scannerWithString:address];
	NSCharacterSet *colonSet = [NSCharacterSet characterSetWithCharactersInString:@":"];
	[scan setCharactersToBeSkipped:colonSet];
	if (![scan scanUpToCharactersFromSet:colonSet intoString:host]) *host = @"";
	if (![scan scanInt:port]) *port = 3389;
}

NSArray *filter_filenames(NSArray *unfilteredFiles, NSArray *types)
{
	NSMutableArray *returnFiles = [NSMutableArray arrayWithCapacity:4];
	NSEnumerator *fileEnumerator = [unfilteredFiles objectEnumerator];
	int i, typeCount = [types count];
	NSString *filename, *type, *extension, *hfsFileType;	
	while ((filename = [fileEnumerator nextObject]))
	{
		hfsFileType = [NSHFSTypeOfFile(filename) stringByTrimmingCharactersInSet:
					[NSCharacterSet characterSetWithCharactersInString:@" '"]];
		NSLog(@"hfs type is: '%@'", hfsFileType);
		extension = [filename pathExtension];
		for (i = 0; i < typeCount; i++)
		{
			type = [types objectAtIndex:i];
			if ([type caseInsensitiveCompare:extension] == NSOrderedSame ||
				[type caseInsensitiveCompare:hfsFileType] == NSOrderedSame)
			{
				[returnFiles addObject:filename];
			}
		}
	}
	
	return ([returnFiles count] > 0) ? [[returnFiles copy] autorelease] : nil;
}

#pragma mark RDCKeyboard
// Frees a uni_key_translation and its sequences
void free_key_translation(uni_key_translation *kt)
{
	if (kt == NULL)
		return;
		
	free_key_translation(kt->next);
	free(kt);
}

void print_bitfield(unsigned v, int bits)
{
	int i;
	for (i = 0; i < bits; i++) {
		if ((i)%4 == 0)
			printf(" ");
		printf("%u", (v << (i + bits)) >> (sizeof(unsigned)*8-1));
	}
	printf("\n");
}


#pragma mark RDInstance
// converts a NSArray of strings to a 2d c string array. You are responsible to 
//	free the returned pointer array.
char **convert_string_array(NSArray *conv)
{
	int count, i = 0;
	if (conv != nil && (count = [conv count]) > 0)
	{
		char **strings = malloc(sizeof(char *) * count);
		NSEnumerator *enumerator = [conv objectEnumerator];
		id o;
		while ( (o = [enumerator nextObject]) )
			strings[i++] = (char *)[[o description] UTF8String];
		return strings;
	}
	
	return NULL;
}