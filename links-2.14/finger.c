/* finger.c
 * finger:// processing
 * (c) 2002 Mikulas Patocka
 * This file is a part of the Links program, released under GPL.
 */

#include "links.h"

static void finger_send_request(struct connection *);
static void finger_sent_request(struct connection *);
static void finger_get_response(struct connection *, struct read_buffer *);
static void finger_end_request(struct connection *, int);

void finger_func(struct connection *c)
{
	int p;
	if ((p = get_port(c->url)) == -1) {
		setcstate(c, S_BAD_URL);
		abort_connection(c);
		return;
	}
	c->from = 0;
	make_connection(c, p, &c->sock1, finger_send_request);
}

static void finger_send_request(struct connection *c)
{
	unsigned char *req = init_str();
	int rl = 0;
	unsigned char *user;
	add_to_str(&req, &rl, cast_uchar "/W");
	if ((user = get_user_name(c->url))) {
		add_to_str(&req, &rl, cast_uchar " ");
		add_to_str(&req, &rl, user);
		mem_free(user);
	}
	add_to_str(&req, &rl, cast_uchar "\r\n");
	write_to_socket(c, c->sock1, req, rl, finger_sent_request);
	mem_free(req);
	setcstate(c, S_SENT);
}

static void finger_sent_request(struct connection *c)
{
	struct read_buffer *rb;
	set_connection_timeout(c);
	if (!(rb = alloc_read_buffer(c))) return;
	rb->close = 1;
	read_from_socket(c, c->sock1, rb, finger_get_response);
}

static void finger_get_response(struct connection *c, struct read_buffer *rb)
{
	int l;
	int a;
	set_connection_timeout(c);
	if (!c->cache) {
		if (get_cache_entry(c->url, &c->cache)) {
			setcstate(c, S_OUT_OF_MEM);
			abort_connection(c);
			return;
		}
		c->cache->refcount--;
	}
	if (rb->close == 2) {
		finger_end_request(c, S__OK);
		return;
	}
	l = rb->len;
	if ((off_t)(0UL + c->from + l) < 0) {
		setcstate(c, S_LARGE_FILE);
		abort_connection(c);
		return;
	}
	c->received += l;
	a = add_fragment(c->cache, c->from, rb->data, l);
	if (a < 0) {
		setcstate(c, a);
		abort_connection(c);
		return;
	}
	if (a == 1) c->tries = 0;
	c->from += l;
	kill_buffer_data(rb, l);
	read_from_socket(c, c->sock1, rb, finger_get_response);
	setcstate(c, S_TRANS);
}

static void finger_end_request(struct connection *c, int state)
{
	if (state == S__OK) {
		if (c->cache) {
			truncate_entry(c->cache, c->from, 1);
			c->cache->incomplete = 0;
		}
	}
	setcstate(c, state);
	abort_connection(c);
}
