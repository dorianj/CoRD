/* -*- c-basic-offset: 8 -*-
   rdesktop: A Remote Desktop Protocol client.
   Copyright (C) Matthew Chapman 1999-2005

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

#pragma mark bitmap.c
RDBOOL bitmap_decompress(uint8 * output, int width, int height, uint8 * input, int size, int Bpp);

#pragma mark -
#pragma mark cache.c
void cache_rebuild_bmpcache_linked_list(RDConnectionRef conn, uint8 cache_id, sint16 * cache_idx, int count);
RDBitmapRef cache_get_bitmap(RDConnectionRef conn, uint8 cache_id, uint16 cache_idx);
void cache_put_bitmap(RDConnectionRef conn, uint8 cache_id, uint16 cache_idx, RDBitmapRef bitmap);
void cache_save_state(RDConnectionRef conn);
RDFontGlyph *cache_get_font(RDConnectionRef conn, uint8 font, uint16 character);
void cache_put_font(RDConnectionRef conn, uint8 font, uint16 character, uint16 offset, uint16 baseline, uint16 width, uint16 height, RDGlyphRef pixmap);
RDDataBlob *cache_get_text(RDConnectionRef conn, uint8 cache_id);
void cache_put_text(RDConnectionRef conn, uint8 cache_id, void *data, int length);
uint8 *cache_get_desktop(RDConnectionRef conn, uint32 offset, int cx, int cy, int bytes_per_pixel);
void cache_put_desktop(RDConnectionRef conn, uint32 offset, int cx, int cy, int scanline, int bytes_per_pixel, uint8 * data);
RDCursorRef cache_get_cursor(RDConnectionRef conn, uint16 cache_idx);
void cache_put_cursor(RDConnectionRef conn, uint16 cache_idx, RDCursorRef cursor);

#pragma mark -
#pragma mark channels.c
RDVirtualChannel *channel_register(RDConnectionRef conn, char *name, uint32 flags, void (*callback) (RDConnectionRef, RDStreamRef));
RDStreamRef channel_init(RDConnectionRef conn, RDVirtualChannel * channel, uint32 length);
void channel_send(RDConnectionRef conn, RDStreamRef s, RDVirtualChannel * channel);
void channel_process(RDConnectionRef conn, RDStreamRef s, uint16 mcs_channel);

#pragma mark -
#pragma mark cliprdr.c
void cliprdr_send_simple_native_format_announce(RDConnectionRef conn, uint32 format);
void cliprdr_send_blah_format_announce(RDConnectionRef conn);
void cliprdr_send_native_format_announce(RDConnectionRef conn, uint8 * data, uint32 length);
void cliprdr_send_data_request(RDConnectionRef conn, uint32 format);
void cliprdr_send_data(RDConnectionRef conn, uint8 * data, uint32 length);
void cliprdr_set_mode(RDConnectionRef conn, const char *optarg);
RDBOOL cliprdr_init(RDConnectionRef conn);

#pragma mark -
#pragma mark disk.c
int disk_enum_devices(RDConnectionRef conn, char ** paths, char **names, int count);
NTStatus disk_query_information(RDConnectionRef conn, NTHandle handle, uint32 info_class, RDStreamRef out);
NTStatus disk_set_information(RDConnectionRef conn, NTHandle handle, uint32 info_class, RDStreamRef in, RDStreamRef out);
NTStatus disk_query_volume_information(RDConnectionRef conn, NTHandle handle, uint32 info_class, RDStreamRef out);
NTStatus disk_query_directory(RDConnectionRef conn, NTHandle handle, uint32 info_class, char *pattern, RDStreamRef out);
NTStatus disk_create_notify(RDConnectionRef conn, NTHandle handle, uint32 info_class);
NTStatus disk_check_notify(RDConnectionRef conn, NTHandle handle);

#pragma mark -
#pragma mark mppc.c
int mppc_expand(RDConnectionRef conn, uint8 * data, uint32 clen, uint8 ctype, uint32 * roff, uint32 * rlen);

#pragma mark -
#pragma mark iso.c
RDStreamRef iso_init(RDConnectionRef conn, int length);
void iso_send(RDConnectionRef conn, RDStreamRef s);
RDStreamRef iso_recv(RDConnectionRef conn, uint8 * rdpver);
RDBOOL iso_connect(RDConnectionRef conn, const char *server, char *username);
RDBOOL iso_reconnect(RDConnectionRef conn, char *server);
void iso_disconnect(RDConnectionRef conn);
void iso_reset_state(RDConnectionRef conn);

#pragma mark -
#pragma mark licence.c
void licence_process(RDConnectionRef conn, RDStreamRef s);

#pragma mark -
#pragma mark mcs.c
RDStreamRef mcs_init(RDConnectionRef conn, int length);
void mcs_send_to_channel(RDConnectionRef conn, RDStreamRef s, uint16 channel);
void mcs_send(RDConnectionRef conn, RDStreamRef s);
RDStreamRef mcs_recv(RDConnectionRef conn, uint16 * channel, uint8 * rdpver);
RDBOOL mcs_connect(RDConnectionRef conn, const char *server, RDStreamRef mcs_data, char *username);
RDBOOL mcs_reconnect(RDConnectionRef conn, char *server, RDStreamRef mcs_data);
void mcs_disconnect(RDConnectionRef conn);
void mcs_reset_state(RDConnectionRef conn);

#pragma mark -
#pragma mark orders.c
void process_orders(RDConnectionRef conn, RDStreamRef s, uint16 num_orders);
void reset_order_state(RDConnectionRef conn);

#pragma mark -
#pragma mark parallel.c
int parallel_enum_devices(RDConnectionRef conn, uint32 * id, char *optarg);

#pragma mark -
#pragma mark printer.c
void printer_enum_devices(RDConnectionRef conn);

#pragma mark -
#pragma mark printercache.c
int printercache_load_blob(char *printer_name, uint8 ** data);
void printercache_process(RDStreamRef s);

#pragma mark -
#pragma mark pstcache.c
void pstcache_touch_bitmap(RDConnectionRef conn, uint8 id, uint16 idx, uint32 stamp);
RDBOOL pstcache_load_bitmap(RDConnectionRef conn, uint8 id, uint16 idx);
RDBOOL pstcache_save_bitmap(RDConnectionRef conn, uint8 id, uint16 idx, uint8 * hash_key, uint16 wd, uint16 ht, uint16 len, uint8 * data);
int pstcache_enumerate(RDConnectionRef conn, uint8 id, RDHashKey * keylist);
RDBOOL pstcache_init(RDConnectionRef conn, uint8 id);

#pragma mark -
#pragma mark CRDVestigialGlue (formerly rdesktop.c)
void generate_random(uint8 * random);
void *xmalloc(int size);
char *xstrdup(const char *s);
void *xrealloc(void *oldmem, int size);
void xfree(void *mem);
void error(char *format, ...);
void warning(char *format, ...);
void unimpl(char *format, ...);
void hexdump(unsigned char *p, unsigned int len);
char *next_arg(char *src, char needle);
void toupper_str(char *p);
RDBOOL str_startswith(const char *s, const char *prefix);
RDBOOL str_handle_lines(const char *input, char **rest, str_handle_lines_t linehandler, void *data);
RDBOOL subprocess(char *const argv[], str_handle_lines_t linehandler, void *data);
char *l_to_a(long N, int base);
int load_licence(unsigned char **data);
void save_licence(unsigned char *data, int length);
RDBOOL rd_pstcache_mkdir(void);
int rd_open_file(char *filename);
void rd_close_file(int fd);
int rd_read_file(int fd, void *ptr, int len);
int rd_write_file(int fd, void *ptr, int len);
int rd_lseek_file(int fd, int offset);
RDBOOL rd_lock_file(int fd, int start, int len);

#pragma mark -
#pragma mark rdp5.c
void rdp5_process(RDConnectionRef conn, RDStreamRef s);

#pragma mark -
#pragma mark rdp.c
RDStreamRef rdp_recv(RDConnectionRef conn, uint8 * type);
void rdp_out_unistr(RDStreamRef s, const char *string, int len);
int rdp_in_unistr(RDStreamRef s, char *string, int uni_len);
void rdp_send_input(RDConnectionRef conn, uint32 time, uint16 message_type, uint16 device_flags, uint16 param1, uint16 param2);
void rdp_send_client_window_status(RDConnectionRef conn, int status);
void process_colour_pointer_pdu(RDConnectionRef conn, RDStreamRef s);
void process_cached_pointer_pdu(RDConnectionRef conn, RDStreamRef s);
void process_system_pointer_pdu(RDConnectionRef conn, RDStreamRef s);
void process_bitmap_updates(RDConnectionRef conn, RDStreamRef s);
void process_palette(RDConnectionRef conn, RDStreamRef s);
void process_disconnect_pdu(RDConnectionRef conn, RDStreamRef s, uint32 * ext_disc_reason);
RDBOOL rdp_connect(RDConnectionRef conn, const char *server, uint32 flags, const char *domain, const char *password, const char *command, const char *directory);
RDBOOL rdp_reconnect(RDConnectionRef conn, const char *server, uint32 flags, const char *domain, const char *password, const char *command, const char *directory, char *cookie);
void rdp_reset_state(RDConnectionRef conn);
void rdp_disconnect(RDConnectionRef conn);
void rdp_reset_state(RDConnectionRef conn);
void rdp_process_server_caps(RDConnectionRef conn, RDStreamRef s, uint16 length);
void process_demand_active(RDConnectionRef conn, RDStreamRef s);
void process_disconnect_pdu(RDConnectionRef conn, RDStreamRef s, uint32 * ext_disc_reason);
RDBOOL process_data_pdu(RDConnectionRef conn, RDStreamRef s, uint32 * ext_disc_reason);
RDBOOL process_redirect_pdu(RDConnectionRef conn, RDStreamRef s);

#pragma mark -
#pragma mark rdpdr.c
int get_device_index(RDConnectionRef conn, NTHandle handle);
void convert_to_unix_filename(char *filename);
RDBOOL rdpdr_init(RDConnectionRef conn);
RDAsynchronousIORequest *rdpdr_remove_iorequest(RDConnectionRef conn, uint32 fd, RDAsynchronousIORequest *requestToRemove);
void rdpdr_io_available_event(RDConnectionRef conn, uint32 file, RDAsynchronousIORequest *iorq);
RDBOOL rdpdr_abort_io(RDConnectionRef conn, uint32 fd, uint32 major, NTStatus status);

#pragma mark -
#pragma mark rdpsnd.c
void rdpsnd_send_completion(uint16 tick, uint8 packet_index);
RDBOOL rdpsnd_init(void);

#pragma mark -
#pragma mark rdpsnd_oss.c
RDBOOL wave_out_open(void);
void wave_out_close(void);
RDBOOL wave_out_format_supported(RDWaveFormat * pwfx);
RDBOOL wave_out_set_format(RDWaveFormat * pwfx);
void wave_out_volume(uint16 left, uint16 right);
void wave_out_write(RDStreamRef s, uint16 tick, uint8 index);
void wave_out_play(void);

#pragma mark -
#pragma mark secure.c
void sec_hash_48(uint8 * out, uint8 * in, uint8 * salt1, uint8 * salt2, uint8 salt);
void sec_hash_16(uint8 * out, uint8 * in, uint8 * salt1, uint8 * salt2);
void buf_out_uint32(uint8 * buffer, uint32 value);
void sec_sign(uint8 * signature, int siglen, uint8 * session_key, int keylen, uint8 * data, int datalen);
void sec_decrypt(RDConnectionRef conn, uint8 * data, int length);
RDStreamRef sec_init(RDConnectionRef conn, uint32 flags, int maxlen);
void sec_send_to_channel(RDConnectionRef conn, RDStreamRef s, uint32 flags, uint16 channel);
void sec_send(RDConnectionRef conn, RDStreamRef s, uint32 flags);
void sec_process_mcs_data(RDConnectionRef conn, RDStreamRef s);
RDStreamRef sec_recv(RDConnectionRef conn, uint8 * rdpver);
RDBOOL sec_connect(RDConnectionRef conn, const char *server, char *username);
RDBOOL sec_reconnect(RDConnectionRef conn, char *server);
void sec_disconnect(RDConnectionRef conn);
void sec_reset_state(RDConnectionRef conn);

#pragma mark -
#pragma mark serial.c
int serial_enum_devices(RDConnectionRef conn, uint32 * id, char *optarg);
RDBOOL serial_get_timeout(RDConnectionRef conn, NTHandle handle, uint32 length, uint32 * timeout, uint32 * itv_timeout);
RDBOOL serial_get_event(RDConnectionRef conn, NTHandle handle, uint32 * result);

#pragma mark -
#pragma mark tcp.c
RDStreamRef tcp_init(RDConnectionRef conn, uint32 maxlen);
void tcp_send(RDConnectionRef conn, RDStreamRef s);
RDStreamRef tcp_recv(RDConnectionRef conn, RDStreamRef s, uint32 length);
RDBOOL tcp_connect(RDConnectionRef conn, const char *server);
void tcp_disconnect(RDConnectionRef conn);
char *tcp_get_address(RDConnectionRef conn);
void tcp_reset_state(RDConnectionRef conn);

#pragma mark -
#pragma mark CRDDrawingStubs.m (formerly xclip.c)
void ui_clip_format_announce(RDConnectionRef conn, uint8 * data, uint32 length);
void ui_clip_handle_data(RDConnectionRef conn, uint8 * data, uint32 length);
void ui_clip_request_data(RDConnectionRef conn, uint32 format);
void ui_clip_sync(RDConnectionRef conn);
void ui_clip_request_failed(RDConnectionRef conn);
void ui_clip_set_mode(RDConnectionRef conn, const char *optarg);

#pragma mark -
#pragma mark CRDVestigialGlue.m (formerly xkeymap.c)
unsigned int read_keyboard_state(void);
uint16 ui_get_numlock_state(unsigned int state);

#pragma mark -
#pragma mark CRDDrawingGlue.m (formerly xwin.c)
void ui_resize_window(RDConnectionRef conn);
void ui_destroy_window(void);
int ui_select(RDConnectionRef conn);
void ui_move_pointer(RDConnectionRef conn, int x, int y);
RDBitmapRef ui_create_bitmap(RDConnectionRef conn, int width, int height, uint8 * data);
void ui_paint_bitmap(RDConnectionRef conn, int x, int y, int cx, int cy, int width, int height, uint8 * data);
void ui_destroy_bitmap(RDBitmapRef bmp);
RDGlyphRef ui_create_glyph(RDConnectionRef conn, int width, int height, const uint8 * data);
void ui_destroy_glyph(RDGlyphRef glyph);
RDCursorRef ui_create_cursor(RDConnectionRef conn, unsigned int x, unsigned int y, int width, int height, uint8 * andmask, uint8 * xormask);
void ui_set_cursor(RDConnectionRef,RDCursorRef cursor);
void ui_destroy_cursor(RDCursorRef cursor);
void ui_set_null_cursor(RDConnectionRef conn);
RDColorMapRef ui_create_colourmap(RDColorMap * colours);
void ui_destroy_colourmap(RDColorMapRef map);
void ui_set_colourmap(RDConnectionRef conn, RDColorMapRef map);
void ui_set_clip(RDConnectionRef conn, int x, int y, int cx, int cy);
void ui_reset_clip(RDConnectionRef conn);
void ui_bell(void);
void ui_destblt(RDConnectionRef conn, uint8 opcode, int x, int y, int cx, int cy);
void ui_patblt(RDConnectionRef conn, uint8 opcode, int x, int y, int cx, int cy, RDBrush * brush, int bgcolour, int fgcolour);
void ui_screenblt(RDConnectionRef conn, uint8 opcode, int x, int y, int cx, int cy, int srcx, int srcy);
void ui_memblt(RDConnectionRef conn, uint8 opcode, int x, int y, int cx, int cy, RDBitmapRef src, int srcx, int srcy);
void ui_triblt(uint8 opcode, int x, int y, int cx, int cy, RDBitmapRef src, int srcx, int srcy, RDBrush * brush, int bgcolour, int fgcolour);
void ui_line(RDConnectionRef conn, uint8 opcode, int startx, int starty, int endx, int endy, RDPen * pen);
void ui_rect(RDConnectionRef conn, int x, int y, int cx, int cy, int colour);
void ui_polygon(RDConnectionRef conn, uint8 opcode, uint8 fillmode, RDPoint* point, int npoints, RDBrush * brush, int bgcolour, int fgcolour);
void ui_polyline(RDConnectionRef conn, uint8 opcode, RDPoint* point, int npoints, RDPen * pen);
void ui_ellipse(RDConnectionRef conn, uint8 opcode, uint8 fillmode, int x, int y, int cx, int cy, RDBrush * brush, int bgcolour, int fgcolour);
void ui_draw_glyph(int mixmode, int x, int y, int cx, int cy, RDGlyphRef glyph, int srcx, int srcy, int bgcolour, int fgcolour);
void ui_draw_text(RDConnectionRef conn, uint8 font, uint8 flags, uint8 opcode, int mixmode, int x, int y, int clipx, int clipy, int clipcx, int clipcy, int boxx, int boxy, int boxcx, int boxcy, RDBrush * brush, int bgcolour, int fgcolour, uint8 * text, uint8 length);
void ui_desktop_save(RDConnectionRef conn, uint32 offset, int x, int y, int cx, int cy);
void ui_desktop_restore(RDConnectionRef conn, uint32 offset, int x, int y, int cx, int cy);
void ui_end_update(RDConnectionRef conn);
void ui_begin_update(RDConnectionRef conn);
void rdp_send_client_window_status(RDConnectionRef conn, int status);