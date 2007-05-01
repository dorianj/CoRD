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

/*	Purpose: A wrapper around Apple's Carbon Keychain API.

	Note: sometime (before 1.0), this will be changed to use 'Internet' passwords.
*/

#import "keychain.h"
#import <Carbon/Carbon.h>
#import <Security/Security.h>
#import <stdarg.h>


#define KC_DEBUG_MODE 0

#define STANDARD_KC_ERR(status) keychain_error("keychain function '%s' received error code %i\n", __func__, (status))
#define EXTENDED_KC_ERR(status, desc) keychain_error("keychain function '%s' received error code %i while %s.\n", __func__, (status), (desc))

// Takes the current server and transforms it from 'example.com' to 'CoRD: example.com'
#define BADGE_HOSTNAME(host) (host) = strpre(host, "CoRD: ")


// Private prototypes
static SecKeychainItemRef get_password_details(const char *server, const char *username,
		const char **password, int reportErrors);
static void keychain_error(char *format, ...);
static const char *strpre(const char *base, const char *prefix);


/* Gets a password for a passed Server/Username. Returns NULL on failure. Caller
	is responsible for freeing the returned string on success.
*/
const char *keychain_get_password(const char *server, const char *username)
{
	if (!strlen(server) || !strlen(username))
		return NULL;
	
	BADGE_HOSTNAME(server);
	
	const char *pass = NULL;
	SecKeychainItemRef keychainItem;
	if ((keychainItem = get_password_details(server, username, &pass, 1)))
		return pass;
	else
		return NULL;
}

/*	Creates or updates a keychain item to match new details.
*/
void keychain_update_password(const char *origServer, const char *origUser, 
		const char *server, const char *username, const char *password)
{
	if (!strlen(server) || !strlen(username))
		return;
	
	BADGE_HOSTNAME(server);
	
	
	SecKeychainItemRef origItem = NULL;
	OSStatus status;
	
	if (strlen(origServer) && strlen(origUser))
	{
		BADGE_HOSTNAME(origServer);
		origItem = get_password_details(origServer, origUser, NULL, 0);
	}
	
	SecKeychainItemRef newItem  = get_password_details(server, username, NULL, 0);
	
	if (origItem != NULL || newItem != NULL)
	{
		// Modify the existing password
		SecKeychainItemRef keychainItem = (origItem) ? origItem : newItem;
			
		// use 7 instead of kSecLabelItemAttr because of a Carbon bug
		//	details: http://lists.apple.com/archives/apple-cdsa/2006//May/msg00037.html
		
		SecKeychainAttribute attrs[] =
		{
				{ kSecAccountItemAttr, strlen(username), (void*)username },
				{ 7, strlen(server), (void*)server },
				{ kSecServiceItemAttr, strlen(server), (void*)server}
		};
		
		SecKeychainAttributeList list = { sizeof(attrs) / sizeof(attrs[0]), attrs };
			
		status = SecKeychainItemModifyAttributesAndData(keychainItem, &list, strlen(password), password);
		
		if (status != noErr) 
			EXTENDED_KC_ERR(status, "editing an existing password");
	}
	else
	{
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
		
		if (status != noErr) 
			EXTENDED_KC_ERR(status, "saving a new password");
    }
}


void keychain_save_password(const char *server, const char *username, const char *password)
{
	keychain_update_password(server, username, server, username, password);
}

void keychain_clear_password(const char *server, const char *username)
{
	if (!strlen(server) || !strlen(username))
		return;
		
	BADGE_HOSTNAME(server);
	
	SecKeychainItemRef keychainItem = get_password_details(server, username, NULL, 0);
	if (keychainItem)
		SecKeychainItemDelete(keychainItem);
}

static SecKeychainItemRef get_password_details(const char *server, const char *username, const char **password, int reportErrors)
{

	if (!strlen(server) || !strlen(username))
		return NULL;
	  
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
	
	if (status == noErr)
	{
		if (password != NULL)
		{
			char *formattedPassword = malloc(passwordLength + 1);
			memcpy(formattedPassword, passwordBuf, passwordLength);
			*(formattedPassword + passwordLength) = '\0';
			*password = formattedPassword;
		}
		
		SecKeychainItemFreeContent(NULL, passwordBuf);
		
		return keychainItem;
	}
	else
	{
		if (reportErrors) 
		{
			// look up at:
			// file://localhost/Developer/ADC%20Reference%20Library/documentation/Security/Reference/keychainservices/Reference/reference.html#//apple_ref/doc/uid/TP30000898-CH5g-95690
			STANDARD_KC_ERR(status);
		}
		return NULL;
	}
}



static void keychain_error(char *format, ...)
{
	if (KC_DEBUG_MODE)
	{
		va_list ap;
		va_start(ap, format);
		printf(format, ap);
		va_end(ap);
	}
}

// Appends base to prefix, returning the newly created string
static const char *strpre(const char *base, const char *prefix)
{
	if (base == NULL || prefix == NULL)
		return NULL;
		
	size_t baseLength = strlen(base), prefixLength = strlen(prefix);
	char *ret = malloc(baseLength + prefixLength + 1);
	
	memcpy(ret, prefix, prefixLength);
	memcpy(ret+prefixLength, base, baseLength);
	*(ret + baseLength + prefixLength) = '\0';

	return (const char *)ret;
}













