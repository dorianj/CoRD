/* bitmap.c */
RDCBOOL bitmap_decompress(uint8 * output, int width, int height, uint8 * input, int size, int Bpp);
/* cache.c */
void cache_rebuild_bmpcache_linked_list(rdcConnection conn, uint8 cache_id, sint16 * cache_idx, int count);
HBITMAP cache_get_bitmap(rdcConnection conn, uint8 cache_id, uint16 cache_idx);
void cache_put_bitmap(rdcConnection conn, uint8 cache_id, uint16 cache_idx, HBITMAP bitmap);
void cache_save_state(rdcConnection conn);
FONTGLYPH *cache_get_font(rdcConnection conn, uint8 font, uint16 character);
void cache_put_font(rdcConnection conn, uint8 font, uint16 character, uint16 offset, uint16 baseline, uint16 width,
		    uint16 height, HGLYPH pixmap);
DATABLOB *cache_get_text(rdcConnection conn, uint8 cache_id);
void cache_put_text(rdcConnection conn, uint8 cache_id, void *data, int length);
uint8 *cache_get_desktop(rdcConnection conn, uint32 offset, int cx, int cy, int bytes_per_pixel);
void cache_put_desktop(rdcConnection conn, uint32 offset, int cx, int cy, int scanline, int bytes_per_pixel,
		       uint8 * data);
HCURSOR cache_get_cursor(rdcConnection conn, uint16 cache_idx);
void cache_put_cursor(rdcConnection conn, uint16 cache_idx, HCURSOR cursor);
/* channels.c */
VCHANNEL *channel_register(rdcConnection conn, char *name, uint32 flags, void (*callback) (rdcConnection, STREAM));
STREAM channel_init(rdcConnection conn, VCHANNEL * channel, uint32 length);
void channel_send(rdcConnection conn, STREAM s, VCHANNEL * channel);
void channel_process(rdcConnection conn, STREAM s, uint16 mcs_channel);
/* cliprdr.c */
void cliprdr_send_text_format_announce(rdcConnection conn);
void cliprdr_send_blah_format_announce(rdcConnection conn);
void cliprdr_send_native_format_announce(rdcConnection conn, uint8 * data, uint32 length);
void cliprdr_send_data_request(rdcConnection conn, uint32 format);
void cliprdr_send_data(rdcConnection conn, uint8 * data, uint32 length);
RDCBOOL cliprdr_init(rdcConnection conn);
/* disk.c */
int disk_enum_devices(rdcConnection conn, char ** paths, char **names, int count);
NTSTATUS disk_query_information(rdcConnection conn, NTHANDLE handle, uint32 info_class, STREAM out);
NTSTATUS disk_set_information(rdcConnection conn, NTHANDLE handle, uint32 info_class, STREAM in, STREAM out);
NTSTATUS disk_query_volume_information(rdcConnection conn, NTHANDLE handle, uint32 info_class, STREAM out);
NTSTATUS disk_query_directory(rdcConnection conn, NTHANDLE handle, uint32 info_class, char *pattern, STREAM out);
NTSTATUS disk_create_notify(rdcConnection conn, NTHANDLE handle, uint32 info_class);
NTSTATUS disk_check_notify(rdcConnection conn, NTHANDLE handle);
/* mppc.c */
int mppc_expand(rdcConnection conn, uint8 * data, uint32 clen, uint8 ctype, uint32 * roff, uint32 * rlen);
/* ewmhints.c */
int get_current_workarea(uint32 * x, uint32 * y, uint32 * width, uint32 * height);
/* iso.c */
STREAM iso_init(rdcConnection conn, int length);
void iso_send(rdcConnection conn, STREAM s);
STREAM iso_recv(rdcConnection conn, uint8 * rdpver);
RDCBOOL iso_connect(rdcConnection conn, const char *server, char *username);
void iso_disconnect(rdcConnection conn);
/* licence.c */
void licence_process(rdcConnection conn, STREAM s);
/* mcs.c */
STREAM mcs_init(rdcConnection conn, int length);
void mcs_send_to_channel(rdcConnection conn, STREAM s, uint16 channel);
void mcs_send(rdcConnection conn, STREAM s);
STREAM mcs_recv(rdcConnection conn, uint16 * channel, uint8 * rdpver);
RDCBOOL mcs_connect(rdcConnection conn, const char *server, STREAM mcs_data, char *username);
void mcs_disconnect(rdcConnection conn);
/* orders.c */
void process_orders(rdcConnection conn, STREAM s, uint16 num_orders);
void reset_order_state(rdcConnection conn);
/* parallel.c */
int parallel_enum_devices(rdcConnection conn, uint32 * id, char *optarg);
/* printer.c */
int printer_enum_devices(rdcConnection conn, uint32 * id, char *optarg);
/* printercache.c */
int printercache_load_blob(char *printer_name, uint8 ** data);
void printercache_process(STREAM s);
/* pstcache.c */
void pstcache_touch_bitmap(rdcConnection conn, uint8 id, uint16 idx, uint32 stamp);
RDCBOOL pstcache_load_bitmap(rdcConnection conn, uint8 id, uint16 idx);
RDCBOOL pstcache_save_bitmap(rdcConnection conn, uint8 id, uint16 idx, uint8 * hash_key, uint16 wd,
			  uint16 ht, uint16 len, uint8 * data);
int pstcache_enumerate(rdcConnection conn, uint8 id, HASH_KEY * keylist);
RDCBOOL pstcache_init(rdcConnection conn, uint8 id);
/* rdesktop.c */
int main(int argc, char *argv[]);
void generate_random(uint8 * random);
void *xmalloc(int size);
void *xrealloc(void *oldmem, int size);
void xfree(void *mem);
void error(char *format, ...);
void warning(char *format, ...);
void unimpl(char *format, ...);
void hexdump(unsigned char *p, unsigned int len);
char *next_arg(char *src, char needle);
void toupper_str(char *p);
char *l_to_a(long N, int base);
int load_licence(unsigned char **data);
void save_licence(unsigned char *data, int length);
RDCBOOL rd_pstcache_mkdir(void);
int rd_open_file(char *filename);
void rd_close_file(int fd);
int rd_read_file(int fd, void *ptr, int len);
int rd_write_file(int fd, void *ptr, int len);
int rd_lseek_file(int fd, int offset);
RDCBOOL rd_lock_file(int fd, int start, int len);
/* rdp5.c */
void rdp5_process(rdcConnection conn, STREAM s);
/* rdp.c */
STREAM rdp_recv(rdcConnection conn, uint8 * type);
void rdp_out_unistr(STREAM s, const char *string, int len);
int rdp_in_unistr(STREAM s, char *string, int uni_len);
void rdp_send_input(rdcConnection conn, uint32 time, uint16 message_type, uint16 device_flags, uint16 param1,
		    uint16 param2);
void process_colour_pointer_pdu(rdcConnection conn, STREAM s);
void process_cached_pointer_pdu(rdcConnection conn, STREAM s);
void process_system_pointer_pdu(rdcConnection conn, STREAM s);
void process_bitmap_updates(rdcConnection conn, STREAM s);
void process_palette(rdcConnection conn, STREAM s);
RDCBOOL rdp_loop(RDCBOOL * deactivated, uint32 * ext_disc_reason);
void rdp_main_loop(RDCBOOL * deactivated, uint32 * ext_disc_reason);
RDCBOOL rdp_connect(rdcConnection conn, const char *server, uint32 flags, const char *domain, const char *password, 
					   const char *command, const char *directory);
void rdp_disconnect(rdcConnection conn);
void rdp_process_server_caps(rdcConnection conn, STREAM s, uint16 length);
void process_demand_active(rdcConnection conn, STREAM s);
void process_disconnect_pdu(STREAM s, uint32 * ext_disc_reason);
RDCBOOL process_data_pdu(rdcConnection conn, STREAM s, uint32 * ext_disc_reason);
/* rdpdr.c */
int get_device_index(rdcConnection conn, NTHANDLE handle);
void convert_to_unix_filename(char *filename);
RDCBOOL rdpdr_init(rdcConnection conn);
void rdpdr_add_fds(rdcConnection conn, int *n, fd_set * rfds, fd_set * wfds, struct timeval *tv, RDCBOOL * timeout);
struct async_iorequest *rdpdr_remove_iorequest(rdcConnection conn, struct async_iorequest *prev,
					       struct async_iorequest *iorq);
void rdpdr_check_fds(rdcConnection conn, fd_set * rfds, fd_set * wfds, RDCBOOL timed_out);
RDCBOOL rdpdr_abort_io(rdcConnection conn, uint32 fd, uint32 major, NTSTATUS status);
/* rdpsnd.c */
void rdpsnd_send_completion(uint16 tick, uint8 packet_index);
RDCBOOL rdpsnd_init(void);
/* rdpsnd_oss.c */
RDCBOOL wave_out_open(void);
void wave_out_close(void);
RDCBOOL wave_out_format_supported(WAVEFORMATEX * pwfx);
RDCBOOL wave_out_set_format(WAVEFORMATEX * pwfx);
void wave_out_volume(uint16 left, uint16 right);
void wave_out_write(STREAM s, uint16 tick, uint8 index);
void wave_out_play(void);
/* secure.c */
void sec_hash_48(uint8 * out, uint8 * in, uint8 * salt1, uint8 * salt2, uint8 salt);
void sec_hash_16(uint8 * out, uint8 * in, uint8 * salt1, uint8 * salt2);
void buf_out_uint32(uint8 * buffer, uint32 value);
void sec_sign(uint8 * signature, int siglen, uint8 * session_key, int keylen, uint8 * data,
	      int datalen);
void sec_decrypt(rdcConnection conn, uint8 * data, int length);
STREAM sec_init(rdcConnection conn, uint32 flags, int maxlen);
void sec_send_to_channel(rdcConnection conn, STREAM s, uint32 flags, uint16 channel);
void sec_send(rdcConnection conn, STREAM s, uint32 flags);
void sec_process_mcs_data(rdcConnection conn, STREAM s);
STREAM sec_recv(rdcConnection conn, uint8 * rdpver);
RDCBOOL sec_connect(rdcConnection conn, const char *server, char *username);
void sec_disconnect(rdcConnection conn);
/* serial.c */
int serial_enum_devices(rdcConnection conn, uint32 * id, char *optarg);
RDCBOOL serial_get_timeout(rdcConnection conn, NTHANDLE handle, uint32 length, uint32 * timeout, uint32 * itv_timeout);
RDCBOOL serial_get_event(rdcConnection conn, NTHANDLE handle, uint32 * result);
/* tcp.c */
STREAM tcp_init(rdcConnection conn, uint32 maxlen);
void tcp_send(rdcConnection conn, STREAM s);
STREAM tcp_recv(rdcConnection conn, STREAM s, uint32 length);
RDCBOOL tcp_connect(rdcConnection conn, const char *server);
void tcp_disconnect(rdcConnection conn);
char *tcp_get_address(rdcConnection conn);
/* xclip.c */
void ui_clip_format_announce(uint8 * data, uint32 length);
void ui_clip_handle_data(uint8 * data, uint32 length);
void ui_clip_request_data(uint32 format);
void ui_clip_sync(void);
void xclip_init(rdcConnection conn);
/* xkeymap.c */
void xkeymap_init(void);
RDCBOOL handle_special_keys(uint32 keysym, unsigned int state, uint32 ev_time, RDCBOOL pressed);
key_translation xkeymap_translate_key(uint32 keysym, unsigned int keycode, unsigned int state);
uint16 xkeymap_translate_button(unsigned int button);
char *get_ksname(uint32 keysym);
void save_remote_modifiers(uint8 scancode);
void restore_remote_modifiers(uint32 ev_time, uint8 scancode);
void ensure_remote_modifiers(uint32 ev_time, key_translation tr);
unsigned int read_keyboard_state(void);
uint16 ui_get_numlock_state(unsigned int state);
void reset_modifier_keys(void);
void rdp_send_scancode(uint32 time, uint16 flags, uint8 scancode);
/* xwin.c */
RDCBOOL get_key_state(unsigned int state, uint32 keysym);
RDCBOOL ui_init(void);
void ui_deinit(void);
RDCBOOL ui_create_window(void);
void ui_resize_window(void);
void ui_destroy_window(void);
void xwin_toggle_fullscreen(void);
int ui_select(int rdp_socket);
void ui_move_pointer(int x, int y);
HBITMAP ui_create_bitmap(rdcConnection conn, int width, int height, uint8 * data);
void ui_paint_bitmap(rdcConnection conn, int x, int y, int cx, int cy, int width, int height, uint8 * data);
void ui_destroy_bitmap(HBITMAP bmp);
HGLYPH ui_create_glyph(rdcConnection conn, int width, int height, const uint8 * data);
void ui_destroy_glyph(HGLYPH glyph);
HCURSOR ui_create_cursor(rdcConnection conn, unsigned int x, unsigned int y, int width, int height, uint8 * andmask,
			 uint8 * xormask);
void ui_set_cursor(rdcConnection,HCURSOR cursor);
void ui_destroy_cursor(HCURSOR cursor);
void ui_set_null_cursor(rdcConnection conn);
HCOLOURMAP ui_create_colourmap(COLOURMAP * colours);
void ui_destroy_colourmap(HCOLOURMAP map);
void ui_set_colourmap(rdcConnection conn, HCOLOURMAP map);
void ui_set_clip(rdcConnection conn, int x, int y, int cx, int cy);
void ui_reset_clip(rdcConnection conn);
void ui_bell(void);
void ui_destblt(rdcConnection conn, uint8 opcode, int x, int y, int cx, int cy);
void ui_patblt(rdcConnection conn, uint8 opcode, int x, int y, int cx, int cy, BRUSH * brush, int bgcolour,
	       int fgcolour);
void ui_screenblt(rdcConnection conn, uint8 opcode, int x, int y, int cx, int cy, int srcx, int srcy);
void ui_memblt(rdcConnection conn, uint8 opcode, int x, int y, int cx, int cy, HBITMAP src, int srcx, int srcy);
void ui_triblt(uint8 opcode, int x, int y, int cx, int cy, HBITMAP src, int srcx, int srcy,
	       BRUSH * brush, int bgcolour, int fgcolour);
void ui_line(rdcConnection conn, uint8 opcode, int startx, int starty, int endx, int endy, PEN * pen);
void ui_rect(rdcConnection conn, int x, int y, int cx, int cy, int colour);
void ui_polygon(rdcConnection conn, uint8 opcode, uint8 fillmode, POINT * point, int npoints, BRUSH * brush,
		int bgcolour, int fgcolour);
void ui_polyline(rdcConnection conn, uint8 opcode, POINT * point, int npoints, PEN * pen);
void ui_ellipse(rdcConnection conn, uint8 opcode, uint8 fillmode, int x, int y, int cx, int cy, BRUSH * brush,
		int bgcolour, int fgcolour);
void ui_draw_glyph(int mixmode, int x, int y, int cx, int cy, HGLYPH glyph, int srcx, int srcy,
		   int bgcolour, int fgcolour);
void ui_draw_text(rdcConnection conn, uint8 font, uint8 flags, uint8 opcode, int mixmode, int x, int y,
		  int clipx, int clipy, int clipcx, int clipcy, int boxx, int boxy,
		  int boxcx, int boxcy, BRUSH * brush, int bgcolour, int fgcolour,
		  uint8 * text, uint8 length);
void ui_desktop_save(rdcConnection conn, uint32 offset, int x, int y, int cx, int cy);
void ui_desktop_restore(rdcConnection conn, uint32 offset, int x, int y, int cx, int cy);
void fillDefaultConnection(rdcConnection conn);
void ui_end_update(rdcConnection conn);
void ui_begin_update(rdcConnection conn);
const char *safe_string_conv(void *src);