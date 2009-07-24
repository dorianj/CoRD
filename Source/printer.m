/* -*- c-basic-offset: 8 -*-
   rdesktop: A Remote Desktop Protocol client.
   Copyright (C) Matthew Chapman 1999-2005
   Rewritten for CoRD by Dorian Johnson, 2008

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import "CRDShared.h"
#import "rdesktop.h"
#import "Carbon/Carbon.h"
#import "sys/fcntl.h"

static NTStatus printer_create(RDConnectionRef conn, uint32 device_id, uint32 access, uint32 share_mode, uint32 disposition, uint32 flags, char *filename, NTHandle * handle);
static NTStatus printer_close(RDConnectionRef conn, NTHandle handle);
static NTStatus printer_write(RDConnectionRef conn, NTHandle handle, uint8 * data, uint32 length, uint32 offset, uint32 * result);


void
printer_enum_devices(RDConnectionRef conn)
{
	CFArrayRef printerList;
	
	PMServerCreatePrinterList(kPMServerLocal, &printerList);
	
	for (int i = 0; i < CFArrayGetCount(printerList); i++, conn->numDevices++)
	{
		PMPrinter printer = (void *)CFArrayGetValueAtIndex(printerList, i);
		const char *printerName = [[NSString stringWithString:(NSString *)PMPrinterGetName(printer)] cString];

		RDRedirectedDevice *device = &conn->rdpdrDevice[conn->numDevices];
		RDPrinterInfo *printerInfo = (RDPrinterInfo *) xmalloc(sizeof(RDPrinterInfo));
		
		printerInfo->printer = printer;
		
		printerInfo->rdpName = xmalloc(strlen(printerName)+1);
		strcpy(printerInfo->rdpName, printerName);
		
		strcpy(device->name, "PRN");
		strcat(device->name, l_to_a(i + 1, 10));
		
		const char *driverName = "HP Color LaserJet 8500 PS";
		printerInfo->rdpDriver = xmalloc(strlen(driverName)+1);
		strcpy(printerInfo->rdpDriver, driverName);
		
		device->device_type = DEVICE_TYPE_PRINTER;
		device->handle = 0;
		device->local_path = NULL;
		device->pdevice_data = (void *)printerInfo;
	}
}

static NTStatus
printer_create(RDConnectionRef conn, uint32 device_id, uint32 access, uint32 share_mode, uint32 disposition, uint32 flags, char *filename, NTHandle * handle)
{	
	RDRedirectedDevice *device = &conn->rdpdrDevice[device_id];
	const char *tempPath = [[CRDTemporaryFile() stringByAppendingString:@".eps"] cStringUsingEncoding:NSASCIIStringEncoding];
	
	device->local_path = xmalloc(strlen(tempPath)+1);
	strcpy(device->local_path, tempPath);
	
	int fd = open(tempPath, O_RDWR | O_TRUNC | O_APPEND | O_CREAT, S_IRWXU | S_IRGRP | S_IROTH);
	
	*handle = device->handle = fd;
	
	return STATUS_SUCCESS;
}

static NTStatus
printer_close(RDConnectionRef conn, NTHandle handle)
{
	RDRedirectedDevice *device = &conn->rdpdrDevice[get_device_index(conn, handle)];
	RDPrinterInfo *printerInfo = (void *)device->pdevice_data;
	
	// Close the temp file
	close(handle);
	
	// Create printing environment variables, send to printer
	PMPrintSession currentSession;
	PMCreateSession(&currentSession);
	
	PMPrintSettings printSettings;
	PMCreatePrintSettings(&printSettings);
	PMSessionDefaultPrintSettings(currentSession, printSettings);
	
	PMPageFormat pageFormat;
	PMCreatePageFormat(&pageFormat);
	PMSessionDefaultPageFormat(currentSession, pageFormat);
	
	CFURLRef filePath = CFURLCreateFromFileSystemRepresentation(NULL, (void *)device->local_path, strlen(device->local_path), false);
	
	OSStatus err =  PMPrinterPrintWithFile(printerInfo->printer, printSettings, pageFormat, CFStringCreateWithCString(NULL, "application/postscript", kCFStringEncodingASCII), filePath);

	NSLog(@"printer_close err=%d", err);

	PMRelease(currentSession);
	PMRelease(printSettings);
	PMRelease(pageFormat);
	CFRelease(filePath);
	
	// Delete the temp file
	remove(device->local_path);
	
	return STATUS_SUCCESS;
}

static NTStatus
printer_write(RDConnectionRef conn, NTHandle handle, uint8 * data, uint32 length, uint32 offset, uint32 * result)
{
	*result = length * write(handle, data, length);
	
	// xxx: need to catch errors
	
	*result = length;
	return STATUS_SUCCESS;
}

DEVICE_FNS printer_fns = {
	printer_create,
	printer_close,
	NULL,			/* read */
	printer_write,
	NULL			/* device_control */
};
