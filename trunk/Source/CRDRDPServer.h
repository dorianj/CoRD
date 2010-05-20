//
//  CRDRDPServer.h
//  Cord
//
//  Created by Nick Peelman on 4/13/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CRDServer.h"


@interface CRDRDPServer : CRDServer {
	
	// Represented rdesktop object
	RDConnectionRef conn;

	NSString *username, *password, *domain;	

	BOOL forwardDisks, forwardPrinters, drawDesktop, windowDrags, windowAnimation, themes, fontSmoothing, consoleSession, fullscreen;
	
	NSInteger screenDepth, screenWidth, screenHeight, forwardAudio;
	
	// Represented file
	NSString *rdpFilename;
	NSStringEncoding fileEncoding;
	
}

@end
