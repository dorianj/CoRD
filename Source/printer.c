#import "rdesktop.h"

static PRINTER *
get_printer_data(rdcConnection conn, NTHANDLE handle)
{
	int index;

	for (index = 0; index < RDPDR_MAX_DEVICES; index++)
	{
		if (handle == conn->rdpdrDevice[index].handle)
			return (PRINTER *) conn->rdpdrDevice[index].pdevice_data;
	}
	return NULL;
}

int
printer_enum_devices(rdcConnection conn, uint32 * id, char *optarg)
{
	PRINTER *pprinter_data;

	char *pos = optarg;
	char *pos2;
	int count = 0;
	int already = 0;

	/* we need to know how many printers we've already set up
	   supplied from other -r flags than this one. */
	while (count < *id)
	{
		if (conn->rdpdrDevice[count].device_type == DEVICE_TYPE_PRINTER)
			already++;
		count++;
	}

	count = 0;

	if (*optarg == ':')
		optarg++;

	while ((pos = next_arg(optarg, ',')) && *id < RDPDR_MAX_DEVICES)
	{
		pprinter_data = (PRINTER *) xmalloc(sizeof(PRINTER));

		strcpy(conn->rdpdrDevice[*id].name, "PRN");
		strcat(conn->rdpdrDevice[*id].name, l_to_a(already + count + 1, 10));

		/* first printer is set as default printer */
		if ((already + count) == 0)
			pprinter_data->default_printer = True;
		else
			pprinter_data->default_printer = False;

		pos2 = next_arg(optarg, '=');
		if (*optarg == (char) 0x00)
			pprinter_data->printer = "mydeskjet";	/* set default */
		else
		{
			pprinter_data->printer = xmalloc(strlen(optarg) + 1);
			strcpy(pprinter_data->printer, optarg);
		}

		if (!pos2 || (*pos2 == (char) 0x00))
			pprinter_data->driver = "HP Color LaserJet 8500 PS";	/* no printer driver supplied set default */
		else
		{
			pprinter_data->driver = xmalloc(strlen(pos2) + 1);
			strcpy(pprinter_data->driver, pos2);
		}

		printf("PRINTER %s to %s driver %s\n", conn->rdpdrDevice[*id].name,
		       pprinter_data->printer, pprinter_data->driver);
		conn->rdpdrDevice[*id].device_type = DEVICE_TYPE_PRINTER;
		conn->rdpdrDevice[*id].pdevice_data = (void *) pprinter_data;
		count++;
		(*id)++;

		optarg = pos;
	}
	return count;
}

static NTSTATUS
printer_create(rdcConnection conn, uint32 device_id, uint32 access, uint32 share_mode, uint32 disposition, uint32 flags,
	       char *filename, NTHANDLE * handle)
{
	char cmd[256];
	PRINTER *pprinter_data;

	pprinter_data = (PRINTER *) conn->rdpdrDevice[device_id].pdevice_data;

	/* default printer name use default printer queue as well in unix */
	if (pprinter_data->printer == "mydeskjet")
	{
		pprinter_data->printer_fp = popen("lpr", "w");
	}
	else
	{
		sprintf(cmd, "lpr -P %s", pprinter_data->printer);
		pprinter_data->printer_fp = popen(cmd, "w");
	}

	conn->rdpdrDevice[device_id].handle = fileno(pprinter_data->printer_fp);
	*handle = conn->rdpdrDevice[device_id].handle;
	return STATUS_SUCCESS;
}

static NTSTATUS
printer_close(rdcConnection conn, NTHANDLE handle)
{
	int i = get_device_index(conn, handle);
	if (i >= 0)
	{
		PRINTER *pprinter_data = conn->rdpdrDevice[i].pdevice_data;
		if (pprinter_data)
			pclose(pprinter_data->printer_fp);
		conn->rdpdrDevice[i].handle = 0;
	}
	return STATUS_SUCCESS;
}

static NTSTATUS
printer_write(rdcConnection conn, NTHANDLE handle, uint8 * data, uint32 length, uint32 offset, uint32 * result)
{
	PRINTER *pprinter_data;

	pprinter_data = get_printer_data(conn, handle);
	*result = length * fwrite(data, length, 1, pprinter_data->printer_fp);

	if (ferror(pprinter_data->printer_fp))
	{
		*result = 0;
		return STATUS_INVALID_HANDLE;
	}
	return STATUS_SUCCESS;
}

DEVICE_FNS printer_fns = {
	printer_create,
	printer_close,
	NULL,			/* read */
	printer_write,
	NULL			/* device_control */
};
