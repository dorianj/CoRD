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

/*	Purpose: A loose wrapper around Apple's Carbon Keychain code. I was getting
		conflicts with Cocoa for some reason. This might be leaking a bit of
		memory in the form of SecKeychainItemRef-s, but I don't think so. The
		docs aren't clear who has the responsibility to release those.
*/


#include <Carbon/Carbon.h>
#include "Security/Security.h"
#include "keychain.h"

// Private prototypes
SecKeychainItemRef get_password_details(const char *server, const char *username,
		const char **password, int reportErrors);



// Gets a password for a passed Server/Username. Returns NULL on failure. Caller
//	is responsible for free()ing the returned string on success.
const char *keychain_get_password(const char *server, const char *username) {
	const char *pass = NULL;
	SecKeychainItemRef keychainItem;
	if ((keychainItem = get_password_details(server, username, &pass, 1)) != NULL) {
		return pass;
	}

	return "";
}


void keychain_save_password(const char *server, const char *username, const char *password) {
	/*	KeyChain doesn't allow duplicate items to be created, so figure out if 
		this has to be created or edited, then do the action.
	*/
	OSStatus status;
	const char *oldPass;
	SecKeychainItemRef keychainItem = get_password_details(server, username, &oldPass, 0);
	
	if (keychainItem != NULL) {
		// Password already exists, change it
		free((void *)oldPass);
		status = SecKeychainItemModifyAttributesAndData(
						keychainItem, NULL, strlen(password), password);
		if (status != 0) printf("keychain_save_password got error code %d while changing an existing password\n", status);				
	} else {
		// Password doesn't exist, create it
		status = SecKeychainAddGenericPassword (
					NULL,              // default keychain
					strlen(server),    // length of service name
					server,            // service name
					strlen(username),  // length of account name
					username,          // account name
					strlen(password),  // length of password
					password,          // pointer to password data
					NULL               // the item reference
		);
		
		if (status != 0) printf("keychain_save_password got error code %d while saving a new password\n", status);
    }	
}

void keychain_clear_password(const char *server, const char *username) {
	const char *oldPass;
	SecKeychainItemRef keychainItem = get_password_details(server, username, &oldPass, 0);
	SecKeychainItemDelete(keychainItem);
}

SecKeychainItemRef get_password_details(const char *server, const char *username, const char **password, int reportErrors) {

	void *passwordBuf = NULL;
	UInt32 passwordLength;
	SecKeychainItemRef keychainItem;
	
	OSStatus status = SecKeychainFindGenericPassword (
				NULL,						//CFTypeRef keychainOrArray,
				strlen(server),				//UInt32 serviceNameLength,
				server,						//const char *serviceName,
				strlen(username),			//UInt32 accountNameLength,
				username,					//const char *accountName,
				&passwordLength,			//UInt32 *passwordLength,
				&passwordBuf,				//void **passwordData,
				&keychainItem				//SecKeychainItemRef *itemRef
	);
	
	if (status == noErr) {
		char *formattedPassword = malloc(passwordLength + 1);
		memcpy(formattedPassword, passwordBuf, passwordLength);
		*(formattedPassword + passwordLength) = '\0';
		*password = formattedPassword;
		
		SecKeychainItemFreeContent(NULL, passwordBuf);
		
		return keychainItem;
	} else {
		if (reportErrors) {
			// look up at:
			// file://localhost/Developer/ADC%20Reference%20Library/documentation/Security/Reference/keychainservices/Reference/reference.html#//apple_ref/doc/uid/TP30000898-CH5g-95690
			printf("get_password_details got error code %d\n", status);
		}
		return NULL;
	}
}