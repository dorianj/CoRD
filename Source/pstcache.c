/*
   rdesktop: A Remote Desktop Protocol client.
   Persistent Bitmap Cache routines
   Copyright (C) Jeroen Meijer 2004-2005

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

#define MAX_CELL_SIZE		0x1000	/* pixels */

#define IS_PERSISTENT(id) (id < 8 && conn->pstcacheFd[id] > 0)

const uint8 zero_key[] = { 0, 0, 0, 0, 0, 0, 0, 0 };


/* Update mru stamp/index for a bitmap */
void
pstcache_touch_bitmap(RDConnectionRef conn, uint8 cache_id, uint16 cache_idx, uint32 stamp)
{
	int fd;

	if (!IS_PERSISTENT(cache_id) || cache_idx >= BMPCACHE2_NUM_PSTCELLS)
		return;

	fd = conn->pstcacheFd[cache_id];
	rd_lseek_file(fd, 12 + cache_idx * (conn->pstcacheBpp * MAX_CELL_SIZE + sizeof(RDPersistentCacheCellHeader)));
	rd_write_file(fd, &stamp, sizeof(stamp));
}

/* Load a bitmap from the persistent cache */
RDBOOL
pstcache_load_bitmap(RDConnectionRef conn, uint8 cache_id, uint16 cache_idx)
{
	uint8 *celldata;
	int fd;
	RDPersistentCacheCellHeader cellhdr;
	RDBitmapRef bitmap;

	if (!conn->bitmapCachePersist)
		return False;

	if (!IS_PERSISTENT(cache_id) || cache_idx >= BMPCACHE2_NUM_PSTCELLS)
		return False;

	fd = conn->pstcacheFd[cache_id];
	rd_lseek_file(fd, cache_idx * (conn->pstcacheBpp * MAX_CELL_SIZE + sizeof(RDPersistentCacheCellHeader)));
	rd_read_file(fd, &cellhdr, sizeof(RDPersistentCacheCellHeader));
	celldata = (uint8 *) xmalloc(cellhdr.length);
	rd_read_file(fd, celldata, cellhdr.length);

	bitmap = ui_create_bitmap(conn, cellhdr.width, cellhdr.height, celldata);
	DEBUG(("Load bitmap from disk: id=%d, idx=%d, bmp=0x%p)\n", cache_id, cache_idx, bitmap));
	cache_put_bitmap(conn, cache_id, cache_idx, bitmap);

	xfree(celldata);
	return True;
}

/* Store a bitmap in the persistent cache */
RDBOOL
pstcache_save_bitmap(RDConnectionRef conn, uint8 cache_id, uint16 cache_idx, uint8 * key,
		     uint16 width, uint16 height, uint16 length, uint8 * data)
{
	int fd;
	RDPersistentCacheCellHeader cellhdr;

	if (!IS_PERSISTENT(cache_id) || cache_idx >= BMPCACHE2_NUM_PSTCELLS)
		return False;

	memcpy(cellhdr.key, key, sizeof(RDHashKey));
	cellhdr.width = width;
	cellhdr.height = height;
	cellhdr.length = length;
	cellhdr.stamp = 0;

	fd = conn->pstcacheFd[cache_id];
	rd_lseek_file(fd, cache_idx * (conn->pstcacheBpp * MAX_CELL_SIZE + sizeof(RDPersistentCacheCellHeader)));
	rd_write_file(fd, &cellhdr, sizeof(RDPersistentCacheCellHeader));
	rd_write_file(fd, data, length);

	return True;
}

/* List the bitmap keys from the persistent cache file */
int
pstcache_enumerate(RDConnectionRef conn, uint8 id, RDHashKey * keylist)
{
	int fd, idx, n;
	sint16 mru_idx[0xa00];
	uint32 mru_stamp[0xa00];
	RDPersistentCacheCellHeader cellhdr;

	if (!(conn->bitmapCache && conn->bitmapCachePersist && IS_PERSISTENT(id)))
		return 0;

	/* The server disconnects if the bitmap cache content is sent more than once */
	if (conn->pstcacheEnumerated)
		return 0;

	DEBUG_RDP5(("Persistent bitmap cache enumeration... "));
	for (idx = 0; idx < BMPCACHE2_NUM_PSTCELLS; idx++)
	{
		fd = conn->pstcacheFd[id];
		rd_lseek_file(fd, idx * (conn->pstcacheBpp * MAX_CELL_SIZE + sizeof(RDPersistentCacheCellHeader)));
		if (rd_read_file(fd, &cellhdr, sizeof(RDPersistentCacheCellHeader)) <= 0)
			break;

		if (memcmp(cellhdr.key, zero_key, sizeof(RDHashKey)) != 0)
		{
			memcpy(keylist[idx], cellhdr.key, sizeof(RDHashKey));

			/* Pre-cache (not possible for 8bpp because 8bpp needs a colourmap) */
			if (conn->bitmapCachePrecache && cellhdr.stamp && conn->serverBpp > 8)
				pstcache_load_bitmap(conn, id, idx);

			/* Sort by stamp */
			for (n = idx; n > 0 && cellhdr.stamp < mru_stamp[n - 1]; n--)
			{
				mru_idx[n] = mru_idx[n - 1];
				mru_stamp[n] = mru_stamp[n - 1];
			}

			mru_idx[n] = idx;
			mru_stamp[n] = cellhdr.stamp;
		}
		else
		{
			break;
		}
	}

	DEBUG_RDP5(("%d cached bitmaps.\n", idx));

	cache_rebuild_bmpcache_linked_list(conn, id, mru_idx, idx);
	conn->pstcacheEnumerated = True;
	return idx;
}

/* initialise the persistent bitmap cache */
RDBOOL
pstcache_init(RDConnectionRef conn, uint8 cache_id)
{
	int fd;
	char filename[256];

	if (conn->pstcacheEnumerated)
		return True;

	conn->pstcacheFd[cache_id] = 0;

	if (!(conn->bitmapCache && conn->bitmapCachePersist))
		return False;

	if (!rd_pstcache_mkdir())
	{
		DEBUG(("failed to get/make cache directory!\n"));
		return False;
	}

	conn->pstcacheBpp = (conn->serverBpp + 7) / 8;
	sprintf(filename, "cache/pstcache_%d_%d", cache_id, conn->pstcacheBpp);
	DEBUG(("persistent bitmap cache file: %s\n", filename));

	fd = rd_open_file(filename);
	if (fd == -1)
		return False;

	if (!rd_lock_file(fd, 0, 0))
	{
		warning("Persistent bitmap caching is disabled. (The file is already in use)\n");
		rd_close_file(fd);
		return False;
	}

	conn->pstcacheFd[cache_id] = fd;
	return True;
}
