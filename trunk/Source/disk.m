/* -*- c-basic-offset: 8 -*-
   rdesktop: A Remote Desktop Protocol client.
   Disk Redirection
   Copyright (C) Jeroen Meijer 2003

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
#import "CRDShared.h"

#import <sys/types.h>
#import <sys/stat.h>
#import <unistd.h>
#import <fcntl.h>		/* open, close */
#import <dirent.h>		/* opendir, closedir, readdir */
#import <fnmatch.h>
#import <errno.h>		/* errno */
#import <stdio.h>

#import <utime.h>
#import <time.h>		/* ctime */


#define DIRFD(a) (dirfd(a))

#import <sys/statvfs.h>
#import <sys/param.h>
#import <sys/mount.h>


#define STATFS_FN(path, buf) (statfs(path,buf))
#define STATFS_T statfs
#define F_NAMELEN(buf) (255)

typedef struct
{
	char name[PATH_MAX];
	char label[PATH_MAX];
	unsigned long serial;
	char type[PATH_MAX];
} FsInfoType;

static NTStatus NotifyInfo(RDConnectionRef conn, NTHandle handle, uint32 info_class, NOTIFY * p);

static time_t
get_create_time(struct stat *st)
{
	time_t ret, ret1;

	ret = MIN(st->st_ctime, st->st_mtime);
	ret1 = MIN(ret, st->st_atime);

	if (ret1 != (time_t) 0)
		return ret1;

	return ret;
}

/* Convert seconds since 1970 to a filetime */
static void
seconds_since_1970_to_filetime(time_t seconds, uint32 * high, uint32 * low)
{
	unsigned long long ticks;

	ticks = (seconds + 11644473600LL) * 10000000;
	*low = (uint32) ticks;
	*high = (uint32) (ticks >> 32);
}

/* Convert seconds since 1970 back to filetime */
static time_t
convert_1970_to_filetime(uint32 high, uint32 low)
{
	unsigned long long ticks;
	time_t val;

	ticks = low + (((unsigned long long) high) << 32);
	ticks /= 10000000;
	ticks -= 11644473600LL;

	val = (time_t) ticks;
	return (val);

}

/* A wrapper for ftruncate which supports growing files, even if the
   native ftruncate doesn't. This is needed on Linux FAT filesystems,
   for example. */
static int
ftruncate_growable(int fd, off_t length)
{
	int ret;
	off_t pos;
	static const char zero = 0;

	/* Try the simple method first */
	if ((ret = ftruncate(fd, length)) != -1)
	{
		return ret;
	}

	/* 
	 * Some kind of error. Perhaps we were trying to grow. Retry
	 * in a safe way.
	 */

	/* Get current position */
	if ((pos = lseek(fd, 0, SEEK_CUR)) == -1)
	{
		perror("lseek");
		return -1;
	}

	/* Seek to new size */
	if (lseek(fd, length, SEEK_SET) == -1)
	{
		perror("lseek");
		return -1;
	}

	/* Write a zero */
	if (write(fd, &zero, 1) == -1)
	{
		perror("write");
		return -1;
	}

	/* Truncate. This shouldn't fail. */
	if (ftruncate(fd, length) == -1)
	{
		perror("ftruncate");
		return -1;
	}

	/* Restore position */
	if (lseek(fd, pos, SEEK_SET) == -1)
	{
		perror("lseek");
		return -1;
	}

	return 0;
}

/* Just like open(2), but if a open with O_EXCL fails, retry with
   GUARDED semantics. This might be necessary because some filesystems
   (such as NFS filesystems mounted from a unfsd server) doesn't
   support O_EXCL. GUARDED semantics are subject to race conditions,
   but we can live with that.
*/
static int
open_weak_exclusive(const char *pathname, int flags, mode_t mode)
{
	int ret;
	struct stat statbuf;

	ret = open(pathname, flags, mode);
	if (ret != -1 || !(flags & O_EXCL))
	{
		/* Success, or not using O_EXCL */
		return ret;
	}

	/* An error occured, and we are using O_EXCL. In case the FS
	   doesn't support O_EXCL, some kind of error will be
	   returned. Unfortunately, we don't know which one. Linux
	   2.6.8 seems to return 524, but I cannot find a documented
	   #define for this case. So, we'll return only on errors that
	   we know aren't related to O_EXCL. */
	switch (errno)
	{
		case EACCES:
		case EEXIST:
		case EINTR:
		case EISDIR:
		case ELOOP:
		case ENAMETOOLONG:
		case ENOENT:
		case ENOTDIR:
			return ret;
	}

	/* Retry with GUARDED semantics */
	if (stat(pathname, &statbuf) != -1)
	{
		/* File exists */
		errno = EEXIST;
		return -1;
	}
	else
	{
		return open(pathname, flags & ~O_EXCL, mode);
	}
}

/* Enumeration of devices from rdesktop.c        */
/* returns numer of units found and initialized. */

int
disk_enum_devices(RDConnectionRef conn, char ** paths, char **names, int count)
{
	int i;
	
	for (i = 0 ; i < count; i++, conn->numDevices++)
	{	
		strncpy(conn->rdpdrDevice[conn->numDevices].name,names[i], sizeof(conn->rdpdrDevice[conn->numDevices].name) -1);
		if (strlen(names[i]) > (sizeof(conn->rdpdrDevice[conn->numDevices].name) -1 ))
			fprintf(stderr,"share name %s truncated to %s\n",names[i],
				conn->rdpdrDevice[conn->numDevices].name);
		
		conn->rdpdrDevice[conn->numDevices].local_path = xmalloc(strlen(paths[i]) +1);
		strcpy(conn->rdpdrDevice[conn->numDevices].local_path,paths[i]);
		conn->rdpdrDevice[conn->numDevices].device_type = DEVICE_TYPE_DISK;
	}
	
	return i;
}


/* Opens or creates a file or directory */
static NTStatus
disk_create(RDConnectionRef conn, uint32 device_id, uint32 accessmask, uint32 sharemode, uint32 create_disposition,
	    uint32 flags_and_attributes, char *filename, NTHandle * phandle)
{
	NTHandle handle;
	DIR *dirp;
	int flags, mode;
	char path[PATH_MAX];
	struct stat filestat;

	handle = 0;
	dirp = NULL;
	flags = 0;
	mode = S_IRWXU | S_IRGRP | S_IXGRP | S_IROTH | S_IXOTH;

	if (*filename && filename[strlen(filename) - 1] == '/')
		filename[strlen(filename) - 1] = 0;
	sprintf(path, "%s%s", conn->rdpdrDevice[device_id].local_path, filename);

	switch (create_disposition)
	{
		case CREATE_ALWAYS:

			/* Delete existing file/link. */
			unlink(path);
			flags |= O_CREAT;
			break;

		case CREATE_NEW:

			/* If the file already exists, then fail. */
			flags |= O_CREAT | O_EXCL;
			break;

		case OPEN_ALWAYS:

			/* Create if not already exists. */
			flags |= O_CREAT;
			break;

		case OPEN_EXISTING:

			/* Default behaviour */
			break;

		case TRUNCATE_EXISTING:

			/* If the file does not exist, then fail. */
			flags |= O_TRUNC;
			break;
	}

	/*printf("Open: \"%s\"  flags: %X, accessmask: %X sharemode: %X create disp: %X\n", path, flags_and_attributes, accessmask, sharemode, create_disposition); */

	/* Get information about file and set that flag ourselfs */
	if ((stat(path, &filestat) == 0) && (S_ISDIR(filestat.st_mode)))
	{
		if (flags_and_attributes & FILE_NON_DIRECTORY_FILE)
			return STATUS_FILE_IS_A_DIRECTORY;
		else
			flags_and_attributes |= FILE_DIRECTORY_FILE;
	}

	if (flags_and_attributes & FILE_DIRECTORY_FILE)
	{
		if (flags & O_CREAT)
		{
			mkdir(path, mode);
		}

		dirp = opendir(path);
		if (!dirp)
		{
			switch (errno)
			{
				case EACCES:

					return STATUS_ACCESS_DENIED;

				case ENOENT:

					return STATUS_NO_SUCH_FILE;

				default:

					perror("opendir");
					return STATUS_NO_SUCH_FILE;
			}
		}
		handle = DIRFD(dirp);
	}
	else
	{

		if (accessmask & GENERIC_ALL
		    || (accessmask & GENERIC_READ && accessmask & GENERIC_WRITE))
		{
			flags |= O_RDWR;
		}
		else if ((accessmask & GENERIC_WRITE) && !(accessmask & GENERIC_READ))
		{
			flags |= O_WRONLY;
		}
		else
		{
			flags |= O_RDONLY;
		}

		handle = open_weak_exclusive(path, flags, mode);
		if (handle == -1)
		{
			switch (errno)
			{
				case EISDIR:

					return STATUS_FILE_IS_A_DIRECTORY;

				case EACCES:

					return STATUS_ACCESS_DENIED;

				case ENOENT:

					return STATUS_NO_SUCH_FILE;
				case EEXIST:

					return STATUS_OBJECT_NAME_COLLISION;
				default:

					perror("open");
					return STATUS_NO_SUCH_FILE;
			}
		}

		/* all read and writes of files should be non blocking */
		if (fcntl(handle, F_SETFL, O_NONBLOCK) == -1)
			perror("fcntl");
	}

	if (handle >= MAX_OPEN_FILES)
	{
		error("Maximum number of open files (%s) reached. Increase MAX_OPEN_FILES!\n",
		      handle);
		exit(1);
	}

	if (dirp)
		conn->fileInfo[handle].pdir = dirp;
	else
		conn->fileInfo[handle].pdir = NULL;

	conn->fileInfo[handle].device_id = device_id;
	conn->fileInfo[handle].flags_and_attributes = flags_and_attributes;
	conn->fileInfo[handle].accessmask = accessmask;
	strncpy(conn->fileInfo[handle].path, path, PATH_MAX - 1);
	conn->fileInfo[handle].delete_on_close = False;
	conn->notifyStamp = True;
	
	*phandle = handle;
	return STATUS_SUCCESS;
}

static NTStatus
disk_close(RDConnectionRef conn, NTHandle handle)
{
	RDFileInfo *pfinfo;

	pfinfo = &(conn->fileInfo[handle]);

	conn->notifyStamp = True;

	rdpdr_abort_io(conn, handle, 0, STATUS_CANCELLED);

	if (pfinfo->pdir)
	{
		if (closedir(pfinfo->pdir) < 0)
		{
			perror("closedir");
			return STATUS_INVALID_HANDLE;
		}

		if (pfinfo->delete_on_close)
			if (rmdir(pfinfo->path) < 0)
			{
				perror(pfinfo->path);
				return STATUS_ACCESS_DENIED;
			}
		pfinfo->delete_on_close = False;
	}
	else
	{
		if (close(handle) < 0)
		{
			perror("close");
			return STATUS_INVALID_HANDLE;
		}
		if (pfinfo->delete_on_close)
			if (unlink(pfinfo->path) < 0)
			{
				perror(pfinfo->path);
				return STATUS_ACCESS_DENIED;
			}

		pfinfo->delete_on_close = False;
	}

	return STATUS_SUCCESS;
}

static NTStatus
disk_read(RDConnectionRef conn, NTHandle handle, uint8 * data, uint32 length, uint32 offset, uint32 * result)
{
	int n;

#if 1
	/* browsing dir ????        */
	/* each request is 24 bytes */
	if (conn->fileInfo[handle].flags_and_attributes & FILE_DIRECTORY_FILE)
	{
		*result = 0;
		return STATUS_SUCCESS;
	}
#endif

	lseek(handle, offset, SEEK_SET);

	n = read(handle, data, length);

	if (n < 0)
	{
		*result = 0;
		switch (errno)
		{
			case EISDIR:
				/* Implement 24 Byte directory read ??
				   with STATUS_NOT_IMPLEMENTED server doesn't read again */
				/* return STATUS_FILE_IS_A_DIRECTORY; */
				return STATUS_NOT_IMPLEMENTED;
			default:
				perror("read");
				return STATUS_INVALID_PARAMETER;
		}
	}

	*result = n;

	return STATUS_SUCCESS;
}

static NTStatus
disk_write(RDConnectionRef conn, NTHandle handle, uint8 * data, uint32 length, uint32 offset, uint32 * result)
{
	int n;

	lseek(handle, offset, SEEK_SET);

	n = write(handle, data, length);

	if (n < 0)
	{
		perror("write");
		*result = 0;
		switch (errno)
		{
			case ENOSPC:
				return STATUS_DISK_FULL;
			default:
				return STATUS_ACCESS_DENIED;
		}
	}

	*result = n;

	return STATUS_SUCCESS;
}

NTStatus
disk_query_information(RDConnectionRef conn, NTHandle handle, uint32 info_class, RDStreamRef outStream)
{
	uint32 file_attributes, ft_high, ft_low;
	struct stat filestat;
	char *path, *filename;

	path = conn->fileInfo[handle].path;

	/* Get information about file */
	if (fstat(handle, &filestat) != 0)
	{
		perror("stat");
		out_uint8(outStream, 0);
		return STATUS_ACCESS_DENIED;
	}

	/* Set file attributes */
	file_attributes = 0;
	if (S_ISDIR(filestat.st_mode))
		file_attributes |= FILE_ATTRIBUTE_DIRECTORY;

	filename = 1 + strrchr(path, '/');
	if (filename && filename[0] == '.')
		file_attributes |= FILE_ATTRIBUTE_HIDDEN;

	if (!file_attributes)
		file_attributes |= FILE_ATTRIBUTE_NORMAL;

	if (!(filestat.st_mode & S_IWUSR))
		file_attributes |= FILE_ATTRIBUTE_READONLY;

	/* Return requested data */
	switch (info_class)
	{
		case FileBasicInformation:
			seconds_since_1970_to_filetime(get_create_time(&filestat), &ft_high, &ft_low);
			out_uint32_le(outStream, ft_low);	/* create_access_time */
			out_uint32_le(outStream, ft_high);

			seconds_since_1970_to_filetime(filestat.st_atime, &ft_high, &ft_low);
			out_uint32_le(outStream, ft_low);	/* last_access_time */
			out_uint32_le(outStream, ft_high);

			seconds_since_1970_to_filetime(filestat.st_mtime, &ft_high, &ft_low);
			out_uint32_le(outStream, ft_low);	/* last_write_time */
			out_uint32_le(outStream, ft_high);

			seconds_since_1970_to_filetime(filestat.st_ctime, &ft_high, &ft_low);
			out_uint32_le(outStream, ft_low);	/* last_change_time */
			out_uint32_le(outStream, ft_high);

			out_uint32_le(outStream, file_attributes);
			break;

		case FileStandardInformation:
			out_uint64_le(outStream, filestat.st_size);	/* Allocation size */
			out_uint64_le(outStream, filestat.st_size);	/* End of file */
			out_uint32_le(outStream, filestat.st_nlink);	/* Number of links */
			out_uint8(outStream, 0);	/* Delete pending */
			out_uint8(outStream, S_ISDIR(filestat.st_mode) ? 1 : 0);	/* Directory */
			break;

		case FileObjectIdInformation:

			out_uint32_le(outStream, file_attributes);	/* File Attributes */
			out_uint32_le(outStream, 0);	/* Reparse Tag */
			break;

		default:

			unimpl("IRP Query (File) Information class: 0x%x\n", info_class);
			return STATUS_INVALID_PARAMETER;
	}
	return STATUS_SUCCESS;
}

NTStatus
disk_set_information(RDConnectionRef conn, NTHandle handle, uint32 info_class, RDStreamRef in, RDStreamRef out)
{
	uint32 length, file_attributes, ft_high, ft_low, delete_on_close;
	char newname[PATH_MAX], fullpath[PATH_MAX];
	RDFileInfo *pfinfo;
	int mode;
	struct stat filestat;
	time_t write_time, change_time, access_time, mod_time;
	struct utimbuf tvs;
	struct STATFS_T stat_fs;

	pfinfo = &(conn->fileInfo[handle]);
	conn->notifyStamp = True;

	switch (info_class)
	{
		case FileBasicInformation:
			write_time = change_time = access_time = 0;

			in_uint8s(in, 4);	/* Handle of root dir? */
			in_uint8s(in, 24);	/* unknown */

			/* CreationTime */
			in_uint32_le(in, ft_low);
			in_uint32_le(in, ft_high);

			/* AccessTime */
			in_uint32_le(in, ft_low);
			in_uint32_le(in, ft_high);
			if (ft_low || ft_high)
				access_time = convert_1970_to_filetime(ft_high, ft_low);

			/* WriteTime */
			in_uint32_le(in, ft_low);
			in_uint32_le(in, ft_high);
			if (ft_low || ft_high)
				write_time = convert_1970_to_filetime(ft_high, ft_low);

			/* ChangeTime */
			in_uint32_le(in, ft_low);
			in_uint32_le(in, ft_high);
			if (ft_low || ft_high)
				change_time = convert_1970_to_filetime(ft_high, ft_low);

			in_uint32_le(in, file_attributes);

			if (fstat(handle, &filestat))
				return STATUS_ACCESS_DENIED;

			tvs.modtime = filestat.st_mtime;
			tvs.actime = filestat.st_atime;
			if (access_time)
				tvs.actime = access_time;


			if (write_time || change_time)
				mod_time = MIN(write_time, change_time);
			else
				mod_time = write_time ? write_time : change_time;

			if (mod_time)
				tvs.modtime = mod_time;


			if (access_time || write_time || change_time)
			{
#if WITH_DEBUG_RDP5
				printf("FileBasicInformation access       time %s",
				       ctime(&tvs.actime));
				printf("FileBasicInformation modification time %s",
				       ctime(&tvs.modtime));
#endif
				if (utime(pfinfo->path, &tvs) && errno != EPERM)
					return STATUS_ACCESS_DENIED;
			}

			if (!file_attributes)
				break;	/* not valid */

			mode = filestat.st_mode;

			if (file_attributes & FILE_ATTRIBUTE_READONLY)
				mode &= ~(S_IWUSR | S_IWGRP | S_IWOTH);
			else
				mode |= S_IWUSR;

			mode &= 0777;
#if WITH_DEBUG_RDP5
			printf("FileBasicInformation set access mode 0%o", mode);
#endif

			if (fchmod(handle, mode))
				return STATUS_ACCESS_DENIED;

			break;

		case FileRenameInformation:

			in_uint8s(in, 4);	/* Handle of root dir? */
			in_uint8s(in, 0x1a);	/* unknown */
			in_uint32_le(in, length);

			if (length && (length / 2) < 256)
			{
				rdp_in_unistr(in, newname, length);
				convert_to_unix_filename(newname);
			}
			else
			{
				return STATUS_INVALID_PARAMETER;
			}

			sprintf(fullpath, "%s%s", conn->rdpdrDevice[pfinfo->device_id].local_path,
				newname);

			if (rename(pfinfo->path, fullpath) != 0)
			{
				perror("rename");
				return STATUS_ACCESS_DENIED;
			}
			break;

		case FileDispositionInformation:
			/* As far as I understand it, the correct
			   thing to do here is to *schedule* a delete,
			   so it will be deleted when the file is
			   closed. Subsequent
			   FileDispositionInformation requests with
			   DeleteFile set to FALSE should unschedule
			   the delete. See
			   http://www.osronline.com/article.cfm?article=245. */

			in_uint32_le(in, delete_on_close);

			if (delete_on_close ||
			    (pfinfo->
			     accessmask & (FILE_DELETE_ON_CLOSE | FILE_COMPLETE_IF_OPLOCKED)))
			{
				pfinfo->delete_on_close = True;
			}

			break;

		case FileAllocationInformation:
			/* Fall through to FileEndOfFileInformation,
			   which uses ftrunc. This is like Samba with
			   "strict allocation = false", and means that
			   we won't detect out-of-quota errors, for
			   example. */

		case FileEndOfFileInformation:
			in_uint8s(in, 28);	/* unknown */
			in_uint32_le(in, length);	/* file size */

			/* prevents start of writing if not enough space left on device */
			if (STATFS_FN(conn->rdpdrDevice[pfinfo->device_id].local_path, &stat_fs) == 0)
				if (stat_fs.f_bfree * stat_fs.f_bsize < length)
					return STATUS_DISK_FULL;

			if (ftruncate_growable(handle, length) != 0)
			{
				return STATUS_DISK_FULL;
			}

			break;
		default:

			unimpl("IRP Set File Information class: 0x%x\n", info_class);
			return STATUS_INVALID_PARAMETER;
	}
	return STATUS_SUCCESS;
}

NTStatus
disk_check_notify(RDConnectionRef conn, NTHandle handle)
{
	RDFileInfo *pfinfo;
	NTStatus status = STATUS_PENDING;

	NOTIFY notify;

	pfinfo = &(conn->fileInfo[handle]);
	if (!pfinfo->pdir)
		return STATUS_INVALID_DEVICE_REQUEST;



	status = NotifyInfo(conn, handle, pfinfo->info_class, &notify);

	if (status != STATUS_PENDING)
		return status;

	if (memcmp(&pfinfo->notify, &notify, sizeof(NOTIFY)))
	{
		/*printf("disk_check_notify found changed event\n"); */
		memcpy(&pfinfo->notify, &notify, sizeof(NOTIFY));
		status = STATUS_NOTIFY_ENUM_DIR;
	}

	return status;


}

NTStatus
disk_create_notify(RDConnectionRef conn, NTHandle handle, uint32 info_class)
{
	RDFileInfo *pfinfo;
	NTStatus ret = STATUS_PENDING;

	/* printf("start disk_create_notify info_class %X\n", info_class); */

	pfinfo = &(conn->fileInfo[handle]);
	pfinfo->info_class = info_class;

	ret = NotifyInfo(conn, handle, info_class, &pfinfo->notify);

	if (info_class & 0x1000)
	{			/* ???? */
		if (ret == STATUS_PENDING)
			return STATUS_SUCCESS;
	}

	/* printf("disk_create_notify: num_entries %d\n", pfinfo->notify.num_entries); */


	return ret;

}

static NTStatus
NotifyInfo(RDConnectionRef conn, NTHandle handle, uint32 info_class, NOTIFY * p)
{
	RDFileInfo *pfinfo;
	struct stat buf;
	struct dirent *dp;
	char *fullname;
	DIR *dpr;

	pfinfo = &(conn->fileInfo[handle]);
	if (fstat(handle, &buf) < 0)
	{
		perror("NotifyInfo");
		return STATUS_ACCESS_DENIED;
	}
	p->modify_time = buf.st_mtime;
	p->status_time = buf.st_ctime;
	p->num_entries = 0;
	p->total_time = 0;


	dpr = opendir(pfinfo->path);
	if (!dpr)
	{
		perror("NotifyInfo");
		return STATUS_ACCESS_DENIED;
	}


	while ((dp = readdir(dpr)))
	{
		if (!strcmp(dp->d_name, ".") || !strcmp(dp->d_name, ".."))
			continue;
		p->num_entries++;
		fullname = xmalloc(strlen(pfinfo->path) + strlen(dp->d_name) + 2);
		sprintf(fullname, "%s/%s", pfinfo->path, dp->d_name);

		if (!stat(fullname, &buf))
		{
			p->total_time += (buf.st_mtime + buf.st_ctime);
		}

		xfree(fullname);
	}
	closedir(dpr);

	return STATUS_PENDING;
}

static FsInfoType *
FsVolumeInfo(char *fpath)
{

	FsInfoType *info;
#ifdef USE_SETMNTENT
	FILE *fdfs;
	struct mntent *e;
#endif

	/* initialize */
	info = malloc(sizeof(FsInfoType));
	memset(info, 0, sizeof(info));
	strcpy(info->label, "RDESKTOP");
	strcpy(info->type, "RDPFS");

#ifdef USE_SETMNTENT
	fdfs = setmntent(MNTENT_PATH, "r");
	if (!fdfs)
		return &info;

	while ((e = getmntent(fdfs)))
	{
		if (str_startswith(e->mnt_dir, fpath))
		{
			strcpy(info.type, e->mnt_type);
			strcpy(info.name, e->mnt_fsname);
			if (strstr(e->mnt_opts, "vfat") || strstr(e->mnt_opts, "iso9660"))
			{
				int fd = open(e->mnt_fsname, O_RDONLY);
				if (fd >= 0)
				{
					unsigned char buf[512];
					memset(buf, 0, sizeof(buf));
					if (strstr(e->mnt_opts, "vfat"))
						 /*FAT*/
					{
						strcpy(info.type, "vfat");
						read(fd, buf, sizeof(buf));
						info.serial =
							(buf[42] << 24) + (buf[41] << 16) +
							(buf[40] << 8) + buf[39];
						strncpy(info.label, (char *)buf + 43, 10);
						info.label[10] = '\0';
					}
					else if (lseek(fd, 32767, SEEK_SET) >= 0)	/* ISO9660 */
					{
						read(fd, buf, sizeof(buf));
						strncpy(info.label, (char *)buf + 41, 32);
						info.label[32] = '\0';
						/* info.Serial = (buf[128]<<24)+(buf[127]<<16)+(buf[126]<<8)+buf[125]; */
					}
					close(fd);
				}
			}
		}
	}
	endmntent(fdfs);
#else
	/* initialize */
	memset(info, 0, sizeof(info));
	strcpy(info->label, "RDESKTOP");
	strcpy(info->type, "RDPFS");

#endif
	return info;
}


NTStatus
disk_query_volume_information(RDConnectionRef conn, NTHandle handle, uint32 info_class, RDStreamRef outStream)
{
	struct STATFS_T stat_fs;
	RDFileInfo *pfinfo;
	FsInfoType *fsinfo;

	pfinfo = &(conn->fileInfo[handle]);

	if (STATFS_FN(pfinfo->path, &stat_fs) != 0)
	{
		perror("statfs");
		return STATUS_ACCESS_DENIED;
	}

	fsinfo = FsVolumeInfo(pfinfo->path);

	switch (info_class)
	{
		case FileFsVolumeInformation:
			
			out_uint32_le(outStream, 0);	/* volume creation time low */
			out_uint32_le(outStream, 0);	/* volume creation time high */
			out_uint32_le(outStream, fsinfo->serial);	/* serial */

			out_uint32_le(outStream, 2 * strlen(fsinfo->label));	/* length of string */

			out_uint8(outStream, 0);	/* support objects? */
			rdp_out_unistr(outStream, fsinfo->label, 2 * strlen(fsinfo->label) - 2);
			break;

		case FileFsSizeInformation:
			out_uint32_le(outStream, stat_fs.f_blocks);	/* Total allocation units low */
			out_uint32_le(outStream, 0);	/* Total allocation high units */
			out_uint32_le(outStream, stat_fs.f_bfree);	/* Available allocation units */
			out_uint32_le(outStream, 0);	/* Available allowcation units */
			out_uint32_le(outStream, stat_fs.f_bsize / 0x200);	/* Assume 512 sectors per allocation unit */
			out_uint32_le(outStream, 0x200);	/* Assume 512 bytes per sector */
			break;

		case FileFsAttributeInformation:

			out_uint32_le(outStream, FS_CASE_SENSITIVE | FS_CASE_IS_PRESERVED);	/* fs attributes */
			out_uint32_le(outStream, F_NAMELEN(stat_fs));	/* max length of filename */

			out_uint32_le(outStream, 2 * strlen(fsinfo->type));	/* length of fs_type */
			rdp_out_unistr(outStream, fsinfo->type, 2 * strlen(fsinfo->type) - 2);
			break;

		case FileFsLabelInformation:
		case FileFsDeviceInformation:
		case FileFsControlInformation:
		case FileFsFullSizeInformation:
		case FileFsObjectIdInformation:
		case FileFsMaximumInformation:

		default:

			unimpl("IRP Query Volume Information class: 0x%x\n", info_class);
			return STATUS_INVALID_PARAMETER;
	}
	return STATUS_SUCCESS;
}

NTStatus
disk_query_directory(RDConnectionRef conn, NTHandle handle, uint32 info_class, char *pattern, RDStreamRef outStream)
{
	uint32 file_attributes, ft_low, ft_high;
	const char *dirname;
	char fullpath[PATH_MAX];
	DIR *pdir;
	struct dirent *pdirent;
	struct stat fstat;
	RDFileInfo *pfinfo;

	pfinfo = &(conn->fileInfo[handle]);
	pdir = pfinfo->pdir;
	dirname = pfinfo->path;
	file_attributes = 0;

	switch (info_class)
	{
		case FileBothDirectoryInformation:

			/* If a search pattern is received, remember this pattern, and restart search */
			if (pattern[0] != 0)
			{
				strncpy(pfinfo->pattern, 1 + strrchr(pattern, '/'), PATH_MAX - 1);
				rewinddir(pdir);
			}

			/* find next dirent matching pattern */
			pdirent = readdir(pdir);
			while (pdirent && fnmatch(pfinfo->pattern, pdirent->d_name, 0) != 0)
				pdirent = readdir(pdir);

			if (pdirent == NULL)
				return STATUS_NO_MORE_FILES;

			/* Get information for directory entry */
			sprintf(fullpath, "%s/%s", dirname, pdirent->d_name);
					
			if (stat(fullpath, &fstat))
			{
				switch (errno)
				{
					case ENOENT:
					case ELOOP:
					case EACCES:
						/* These are non-fatal errors. */
						memset(&fstat, 0, sizeof(fstat));
						break;
					default:
						/* Fatal error. By returning STATUS_NO_SUCH_FILE, 
						   the directory list operation will be aborted */
						perror(fullpath);
						out_uint8(outStream, 0);
						return STATUS_NO_SUCH_FILE;
				}
			}

			if (S_ISDIR(fstat.st_mode))
				file_attributes |= FILE_ATTRIBUTE_DIRECTORY;
			if (CRDPathIsHidden([NSString stringWithUTF8String:fullpath]))
				file_attributes |= FILE_ATTRIBUTE_HIDDEN;
			if (!file_attributes)
				file_attributes |= FILE_ATTRIBUTE_NORMAL;
			if (!(fstat.st_mode & S_IWUSR))
				file_attributes |= FILE_ATTRIBUTE_READONLY;

			/* Return requested information */
			out_uint8s(outStream, 8);	/* unknown zero */

			seconds_since_1970_to_filetime(get_create_time(&fstat), &ft_high, &ft_low);
			out_uint32_le(outStream, ft_low);	/* create time */
			out_uint32_le(outStream, ft_high);

			seconds_since_1970_to_filetime(fstat.st_atime, &ft_high, &ft_low);
			out_uint32_le(outStream, ft_low);	/* last_access_time */
			out_uint32_le(outStream, ft_high);

			seconds_since_1970_to_filetime(fstat.st_mtime, &ft_high, &ft_low);
			out_uint32_le(outStream, ft_low);	/* last_write_time */
			out_uint32_le(outStream, ft_high);

			seconds_since_1970_to_filetime(fstat.st_ctime, &ft_high, &ft_low);
			out_uint32_le(outStream, ft_low);	/* change_write_time */
			out_uint32_le(outStream, ft_high);

			out_uint64_le(outStream, fstat.st_size);	/* filesize */
			out_uint64_le(outStream, fstat.st_size);	/* filesize */
			out_uint32_le(outStream, file_attributes);
			out_uint8(outStream, 2 * strlen(pdirent->d_name) + 2);	/* unicode length */
			out_uint8s(outStream, 7);	/* pad? */
			out_uint8(outStream, 0);	/* 8.3 file length */
			out_uint8s(outStream, 2 * 12);	/* 8.3 unicode length */
			rdp_out_unistr(outStream, pdirent->d_name, 2 * strlen(pdirent->d_name));
			break;

		default:
			/* FIXME: Support FileDirectoryInformation,
			   FileFullDirectoryInformation, and
			   FileNamesInformation */

			unimpl("IRP Query Directory sub: 0x%x\n", info_class);
			return STATUS_INVALID_PARAMETER;
	}

	return STATUS_SUCCESS;
}

static NTStatus
disk_device_control(RDConnectionRef conn, NTHandle handle, uint32 request, RDStreamRef in, RDStreamRef out)
{
	if (((request >> 16) != 20) || ((request >> 16) != 9))
		return STATUS_INVALID_PARAMETER;

	/* extract operation */
	request >>= 2;
	request &= 0xfff;

	printf("DISK IOCTL %d\n", request);

	switch (request)
	{
		case 25:	/* ? */
		case 42:	/* ? */
		default:
			unimpl("DISK IOCTL %d\n", request);
			return STATUS_INVALID_PARAMETER;
	}

	return STATUS_SUCCESS;
}

DEVICE_FNS disk_fns = {
	disk_create,
	disk_close,
	disk_read,
	disk_write,
	disk_device_control	/* device_control */
};
