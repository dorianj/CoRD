/*	Copyright (c) 2006 Dorian Johnson <arcadiclife@gmail.com>
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













