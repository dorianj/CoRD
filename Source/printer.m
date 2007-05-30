/* -*- c-basic-offset: 8 -*-
   rdesktop: A Remote Desktop Protocol client.
   Copyright (C) Matthew Chapman 1999-2005
   Rewritten for CoRD by Dorian Johnson.

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

#import "rdesktop.h"
#import "Carbon/Carbon.h"
#import "sys/fcntl.h"

static NTStatus printer_create(RDConnectionRef conn, uint32 device_id, uint32 access, uint32 share_mode, uint32 disposition, uint32 flags, char *filename, NTHandle * handle);
static int get_printer_id(RDConnectionRef conn, NTHandle handle);
static NTStatus printer_close(RDConnectionRef conn, NTHandle handle);
static NTStatus printer_write(RDConnectionRef conn, NTHandle handle, uint8 * data, uint32 length, uint32 offset, uint32 * result);



static int
get_printer_id(RDConnectionRef conn, NTHandle handle)
{
	int index;

	for (index = 0; index < RDPDR_MAX_DEVICES; index++)
	{
		if (handle == conn->rdpdrDevice[index].handle)
			return index;
	}
	return -1;
}

void
printer_enum_devices(RDConnectionRef conn)
{

/*
	RDPrinterInfo *pprinter_data;
	int i;
	
	for (i = 0; i < printerCount; i++, conn->numDevices++)
	{
		printf("Adding printer %s\n", printerNames[i]);
		
		
		
		pprinter_data = (RDPrinterInfo *) xmalloc(sizeof(RDPrinterInfo));
	
		strcpy(conn->rdpdrDevice[conn->numDevices].name, "PRN");
		strcat(conn->rdpdrDevice[conn->numDevices].name, l_to_a(i + 1, 10));
		

		pprinter_data->default_printer = (i == 0);
		
		conn->printerNames[i] = malloc(strlen(printerNames[i])+1);
		pprinter_data->printer = malloc(strlen(printerNames[i])+1);
		strcpy(pprinter_data->printer, printerNames[i]);
		strcpy(conn->printerNames[i], printerNames[i]);
		
		pprinter_data->driver = malloc(strlen("HP Color LaserJet 8500 PS")+1);
		strcpy(pprinter_data->driver, "HP Color LaserJet 8500 PS");
		
		conn->rdpdrDevice[conn->numDevices].device_type = DEVICE_TYPE_PRINTER;
		conn->rdpdrDevice[conn->numDevices].pdevice_data = (void *) pprinter_data;
	}*/
}

static NTStatus
printer_create(RDConnectionRef conn, uint32 device_id, uint32 access, uint32 share_mode, uint32 disposition, uint32 flags, char *filename, NTHandle * handle)
{	

	asprintf(&conn->rdpdrDevice[device_id].local_path, "/tmp/CoRD_PrintFile%d-%d.eps", device_id, time(NULL));
	int fd = open(conn->rdpdrDevice[device_id].local_path, O_RDWR | O_TRUNC | O_APPEND | O_CREAT, S_IRWXU | S_IRGRP | S_IROTH);
	
	*handle = conn->rdpdrDevice[device_id].handle = fd;
	
	return STATUS_SUCCESS;
}

static NTStatus
printer_close(RDConnectionRef conn, NTHandle handle)
{
	int device_id = get_printer_id(conn, handle);
	close(handle);
	
	PMPrintSession currentSession;
	PMCreateSession(&currentSession);
	
	PMPrinter currentPrinter;
	PMSessionGetCurrentPrinter(currentSession, &currentPrinter);
	
	PMPrintSettings defaultPrintSettings;
	PMCreatePrintSettings(&defaultPrintSettings);
	
	PMPageFormat defaultPageFormat;
	PMCreatePageFormat(&defaultPageFormat);
	
	
	CFURLRef filePath = CFURLCreateFromFileSystemRepresentation(NULL, (const unsigned char *)conn->rdpdrDevice[device_id].local_path, strlen(conn->rdpdrDevice[device_id].local_path), NO);
	
	OSStatus err =  PMPrinterPrintWithFile(currentPrinter, defaultPrintSettings, defaultPageFormat, CFStringCreateWithCString(NULL, "application/postscript", kCFStringEncodingASCII), filePath);
	
	remove(conn->rdpdrDevice[device_id].local_path);
	
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
