/*
   rdesktop: A Remote Desktop Protocol client.
   Cache routines
   Copyright (C) Matthew Chapman 1999-2005
   Copyright (C) Jeroen Meijer 2005

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

#define NUM_ELEMENTS(array) (sizeof(array) / sizeof(array[0]))
#define IS_PERSISTENT(id) (conn->pstcacheFd[id] > 0)
#define TO_TOP -1
#define CACHE_IS_SET(idx) (idx >= 0)

/*
 * TODO: Test for optimal value of BUMP_COUNT. TO_TOP gives lowest cpu utilisation but using
 * a positive value will hopefully result in less frequently used bitmaps having a greater chance
 * of being evicted from the cache, and therby reducing the need to load bitmaps from disk.
 * (Jeroen)
 */
#define BUMP_COUNT 40

static void cache_bump_bitmap(rdcConnection conn, uint8 id, uint16 idx, int bump);
static void cache_evict_bitmap(rdcConnection conn, uint8 id);
/* Setup the bitmap cache lru/mru linked list */
void
cache_rebuild_bmpcache_linked_list(rdcConnection conn, uint8 id, sint16 * idx, int count)
{
	int n = count, c = 0;
	sint16 n_idx;

	/* find top, skip evicted bitmaps */
	while (--n >= 0 && conn->bmpcache[id][idx[n]].bitmap == NULL);
	if (n < 0)
	{
		conn->bmpcacheMru[id] = conn->bmpcacheLru[id] = NOT_SET;
		return;
	}

	conn->bmpcacheMru[id] = idx[n];
	conn->bmpcache[id][idx[n]].next = NOT_SET;
	n_idx = idx[n];
	c++;

	/* link list */
	while (n >= 0)
	{
		/* skip evicted bitmaps */
		while (--n >= 0 && conn->bmpcache[id][idx[n]].bitmap == NULL);

		if (n < 0)
			break;

		conn->bmpcache[id][n_idx].previous = idx[n];
		conn->bmpcache[id][idx[n]].next = n_idx;
		n_idx = idx[n];
		c++;
	}

	conn->bmpcache[id][n_idx].previous = NOT_SET;
	conn->bmpcacheLru[id] = n_idx;

	if (c != conn->bmpcacheCount[id])
	{
		error("Oops. %d in bitmap cache linked list, %d in ui cache...\n", c,
		      conn->bmpcacheCount[id]);
		exit(1);
	}
}

/* Move a bitmap to a new position in the linked list. */
static void
cache_bump_bitmap(rdcConnection conn, uint8 id, uint16 idx, int bump)
{
	int p_idx, n_idx, n;

	if (!IS_PERSISTENT(id))
		return;

	if (conn->bmpcacheMru[id] == idx)
		return;

	DEBUG_RDP5(("bump bitmap: id=%d, idx=%d, bump=%d\n", id, idx, bump));

	n_idx = conn->bmpcache[id][idx].next;
	p_idx = conn->bmpcache[id][idx].previous;

	if (CACHE_IS_SET(n_idx))
	{
		/* remove */
		--conn->bmpcacheCount[id];
		if (CACHE_IS_SET(p_idx))
			conn->bmpcache[id][p_idx].next = n_idx;
		else
			conn->bmpcacheLru[id] = n_idx;
		if (CACHE_IS_SET(n_idx))
			conn->bmpcache[id][n_idx].previous = p_idx;
		else
			conn->bmpcacheMru[id] = p_idx;
	}
	else
	{
		p_idx = NOT_SET;
		n_idx = conn->bmpcacheLru[id];
	}

	if (bump >= 0)
	{
		for (n = 0; n < bump && CACHE_IS_SET(n_idx); n++)
		{
			p_idx = n_idx;
			n_idx = conn->bmpcache[id][p_idx].next;
		}
	}
	else
	{
		p_idx = conn->bmpcacheMru[id];
		n_idx = NOT_SET;
	}

	/* insert */
	++conn->bmpcacheCount[id];
	conn->bmpcache[id][idx].previous = p_idx;
	conn->bmpcache[id][idx].next = n_idx;

	if (p_idx >= 0)
		conn->bmpcache[id][p_idx].next = idx;
	else
		conn->bmpcacheLru[id] = idx;

	if (n_idx >= 0)
		conn->bmpcache[id][n_idx].previous = idx;
	else
		conn->bmpcacheMru[id] = idx;
}

/* Evict the least-recently used bitmap from the cache */
static void
cache_evict_bitmap(rdcConnection conn, uint8 id)
{
	uint16 idx;
	int n_idx;

	if (!IS_PERSISTENT(id))
		return;

	idx = conn->bmpcacheLru[id];
	n_idx = conn->bmpcache[id][idx].next;
	DEBUG_RDP5(("evict bitmap: id=%d idx=%d n_idx=%d bmp=0x%x\n", id, idx, n_idx,
		    conn->bmpcache[id][idx].bitmap));

	ui_destroy_bitmap(conn->bmpcache[id][idx].bitmap);
	--conn->bmpcacheCount[id];
	conn->bmpcache[id][idx].bitmap = 0;

	conn->bmpcacheLru[id] = n_idx;
	conn->bmpcache[id][n_idx].previous = NOT_SET;

	pstcache_touch_bitmap(conn, id, idx, 0);
}

/* Retrieve a bitmap from the cache */
HBITMAP
cache_get_bitmap(rdcConnection conn, uint8 id, uint16 idx)
{
	if ((id < NUM_ELEMENTS(conn->bmpcache)) && (idx < NUM_ELEMENTS(conn->bmpcache[0])))
	{
		if (conn->bmpcache[id][idx].bitmap || pstcache_load_bitmap(conn, id, idx))
		{
			if (IS_PERSISTENT(id))
				cache_bump_bitmap(conn, id, idx, BUMP_COUNT);

			return conn->bmpcache[id][idx].bitmap;
		}
	}
	else if ((id < NUM_ELEMENTS(conn->volatileBc)) && (idx == 0x7fff))
	{
		return conn->volatileBc[id];
	}

	error("get bitmap %d:%d\n", id, idx);
	return NULL;
}

/* Store a bitmap in the cache */
void
cache_put_bitmap(rdcConnection conn, uint8 id, uint16 idx, HBITMAP bitmap)
{
	HBITMAP old;

	if ((id < NUM_ELEMENTS(conn->bmpcache)) && (idx < NUM_ELEMENTS(conn->bmpcache[0])))
	{
		old = conn->bmpcache[id][idx].bitmap;
		if (old != NULL)
			ui_destroy_bitmap(old);
		conn->bmpcache[id][idx].bitmap = bitmap;

		if (IS_PERSISTENT(id))
		{
			if (old == NULL)
				conn->bmpcache[id][idx].previous = conn->bmpcache[id][idx].next = NOT_SET;

			cache_bump_bitmap(conn, id, idx, TO_TOP);
			if (conn->bmpcacheCount[id] > BMPCACHE2_C2_CELLS)
				cache_evict_bitmap(conn, id);
		}
	}
	else if ((id < NUM_ELEMENTS(conn->volatileBc)) && (idx == 0x7fff))
	{
		old = conn->volatileBc[id];
		if (old != NULL)
			ui_destroy_bitmap(old);
		conn->volatileBc[id] = bitmap;
	}
	else
	{
		error("put bitmap %d:%d\n", id, idx);
	}
}

/* Updates the persistent bitmap cache MRU information on exit */
void
cache_save_state(rdcConnection conn)
{
	uint32 id = 0, t = 0;
	int idx;

	for (id = 0; id < NUM_ELEMENTS(conn->bmpcache); id++)
		if (IS_PERSISTENT(id))
		{
			DEBUG_RDP5(("Saving cache state for bitmap cache %d...", id));
			idx = conn->bmpcacheLru[id];
			while (idx >= 0)
			{
				pstcache_touch_bitmap(conn, id, idx, ++t);
				idx = conn->bmpcache[id][idx].next;
			}
			DEBUG_RDP5((" %d stamps written.\n", t));
		}
}

/* Retrieve a glyph from the font cache */
FONTGLYPH *
cache_get_font(rdcConnection conn, uint8 font, uint16 character)
{
	FONTGLYPH *glyph;

	if ((font < NUM_ELEMENTS(conn->fontCache)) && (character < NUM_ELEMENTS(conn->fontCache[0])))
	{
		glyph = &conn->fontCache[font][character];
		if (glyph->pixmap != NULL)
			return glyph;
	}

	error("get font %d:%d\n", font, character);
	return NULL;
}

/* Store a glyph in the font cache */
void
cache_put_font(rdcConnection conn, uint8 font, uint16 character, uint16 offset,
	       uint16 baseline, uint16 width, uint16 height, HGLYPH pixmap)
{
	FONTGLYPH *glyph;

	if ((font < NUM_ELEMENTS(conn->fontCache)) && (character < NUM_ELEMENTS(conn->fontCache[0])))
	{
		glyph = &conn->fontCache[font][character];
		if (glyph->pixmap != NULL)
			ui_destroy_glyph(glyph->pixmap);

		glyph->offset = offset;
		glyph->baseline = baseline;
		glyph->width = width;
		glyph->height = height;
		glyph->pixmap = pixmap;
	}
	else
	{
		error("put font %d:%d\n", font, character);
	}
}

/* Retrieve a text item from the cache */
DATABLOB *
cache_get_text(rdcConnection conn, uint8 cache_id)
{
	DATABLOB *text;

	text = &conn->textCache[cache_id];
	return text;
}

/* Store a text item in the cache */
void
cache_put_text(rdcConnection conn, uint8 cache_id, void *data, int length)
{
	DATABLOB *text;

	text = &conn->textCache[cache_id];
	if (text->data != NULL)
		xfree(text->data);
	text->data = xmalloc(length);
	text->size = length;
	memcpy(text->data, data, length);
}

/* Retrieve desktop data from the cache */
uint8 *
cache_get_desktop(rdcConnection conn, uint32 offset, int cx, int cy, int bytes_per_pixel)
{
	int length = cx * cy * bytes_per_pixel;

	if (offset > sizeof(conn->deskCache))
		offset = 0;

	if ((offset + length) <= sizeof(conn->deskCache))
	{
		return &conn->deskCache[offset];
	}

	error("get desktop %d:%d\n", offset, length);
	return NULL;
}

/* Store desktop data in the cache */
void
cache_put_desktop(rdcConnection conn, uint32 offset, int cx, int cy, int scanline, int bytes_per_pixel, uint8 * data)
{
	int length = cx * cy * bytes_per_pixel;

	if (offset > sizeof(conn->deskCache))
		offset = 0;

	if ((offset + length) <= sizeof(conn->deskCache))
	{
		cx *= bytes_per_pixel;
		while (cy--)
		{
			memcpy(&conn->deskCache[offset], data, cx);
			data += scanline;
			offset += cx;
		}
	}
	else
	{
		error("put desktop %d:%d\n", offset, length);
	}
}

/* Retrieve cursor from cache */
HCURSOR
cache_get_cursor(rdcConnection conn, uint16 cache_idx)
{
	HCURSOR cursor;

	if (cache_idx < NUM_ELEMENTS(conn->cursorCache))
	{
		cursor = conn->cursorCache[cache_idx];
		if (cursor != NULL)
			return cursor;
	}

	error("get cursor %d\n", cache_idx);
	return NULL;
}

/* Store cursor in cache */
void
cache_put_cursor(rdcConnection conn, uint16 cache_idx, HCURSOR cursor)
{
	HCURSOR old;

	if (cache_idx < NUM_ELEMENTS(conn->cursorCache))
	{
		old = conn->cursorCache[cache_idx];
		if (old != NULL)
			ui_destroy_cursor(old);

		conn->cursorCache[cache_idx] = cursor;
	}
	else
	{
		error("put cursor %d\n", cache_idx);
	}
}
