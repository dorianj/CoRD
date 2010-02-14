/* -*- c-basic-offset: 8 -*-
   rdesktop: A Remote Desktop Protocol client.
   Protocol services - Multipoint Communications Service
   Copyright (C) Matthew Chapman 1999-2008
   
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

/* Parse an ASN.1 BER header */
static RD_BOOL
ber_parse_header(RDStreamRef s, int tagval, int *length)
{
	int tag, len;

	if (tagval > 0xff)
	{
		in_uint16_be(s, tag);
	}
	else
	{
        in_uint8(s, tag);
    }

	if (tag != tagval)
	{
		error("expected tag %d, got %d\n", tagval, tag);
		return False;
	}

	in_uint8(s, len);

	if (len & 0x80)
	{
		len &= ~0x80;
		*length = 0;
		while (len--)
			next_be(s, *length);
	}
	else
		*length = len;

	return s_check(s);
}

/* Output an ASN.1 BER header */
static void
ber_out_header(RDStreamRef s, int tagval, int length)
{
	if (tagval > 0xff)
	{
		out_uint16_be(s, tagval);
	}
	else
	{
		out_uint8(s, tagval);
	}

	if (length >= 0x80)
	{
		out_uint8(s, 0x82);
		out_uint16_be(s, length);
	}
	else
		out_uint8(s, length);
}

/* Output an ASN.1 BER integer */
static void
ber_out_integer(RDStreamRef s, int value)
{
	ber_out_header(s, BER_TAG_INTEGER, 2);
	out_uint16_be(s, value);
}

/* Output a DOMAIN_PARAMS structure (ASN.1 BER) */
static void
mcs_out_domain_params(RDStreamRef s, int max_channels, int max_users, int max_tokens, int max_pdusize)
{
	ber_out_header(s, MCS_TAG_DOMAIN_PARAMS, 32);
	ber_out_integer(s, max_channels);
	ber_out_integer(s, max_users);
	ber_out_integer(s, max_tokens);
	ber_out_integer(s, 1);	/* num_priorities */
	ber_out_integer(s, 0);	/* min_throughput */
	ber_out_integer(s, 1);	/* max_height */
	ber_out_integer(s, max_pdusize);
	ber_out_integer(s, 2);	/* ver_protocol */
}

/* Parse a DOMAIN_PARAMS structure (ASN.1 BER) */
static RD_BOOL
mcs_parse_domain_params(RDStreamRef s)
{
	int length;

	ber_parse_header(s, MCS_TAG_DOMAIN_PARAMS, &length);
	in_uint8s(s, length);

	return s_check(s);
}

/* Send an MCS_CONNECT_INITIAL message (ASN.1 BER) */
static void
mcs_send_connect_initial(RDConnectionRef conn, RDStreamRef mcs_data)
{
	int datalen = mcs_data->end - mcs_data->data;
	int length = 9 + 3 * 34 + 4 + datalen;
	RDStreamRef s;

	s = iso_init(conn, length + 5);

	ber_out_header(s, MCS_CONNECT_INITIAL, length);
	ber_out_header(s, BER_TAG_OCTET_STRING, 1);	/* calling domain */
	out_uint8(s, 1);
	ber_out_header(s, BER_TAG_OCTET_STRING, 1);	/* called domain */
	out_uint8(s, 1);

	ber_out_header(s, BER_TAG_RDCBOOLEAN, 1);
	out_uint8(s, 0xff);	/* upward flag */

	mcs_out_domain_params(s, 34, 2, 0, 0xffff);	/* target params */
	mcs_out_domain_params(s, 1, 1, 1, 0x420);	/* min params */
	mcs_out_domain_params(s, 0xffff, 0xfc17, 0xffff, 0xffff);	/* max params */

	ber_out_header(s, BER_TAG_OCTET_STRING, datalen);
	out_uint8p(s, mcs_data->data, datalen);

	s_mark_end(s);
	iso_send(conn, s);
}

/* Expect a MCS_CONNECT_RESPONSE message (ASN.1 BER) */
static RD_BOOL
mcs_recv_connect_response(RDConnectionRef conn, RDStreamRef mcs_data)
{
	uint8 result;
	int length;
	RDStreamRef s;

	s = iso_recv(conn, NULL);
	if (s == NULL)
		return False;

	ber_parse_header(s, MCS_CONNECT_RESPONSE, &length);

	ber_parse_header(s, BER_TAG_RESULT, &length);
	in_uint8(s, result);
	if (result != 0)
	{
		error("MCS connect: %d\n", result);
		return False;
	}

	ber_parse_header(s, BER_TAG_INTEGER, &length);
	in_uint8s(s, length);	/* connect id */
	mcs_parse_domain_params(s);

	ber_parse_header(s, BER_TAG_OCTET_STRING, &length);

	sec_process_mcs_data(conn, s);
	/*
	   if (length > mcs_data->size)
	   {
	   error("MCS data length %d, expected %d\n", length,
	   mcs_data->size);
	   length = mcs_data->size;
	   }

	   in_uint8a(s, mcs_data->data, length);
	   mcs_data->p = mcs_data->data;
	   mcs_data->end = mcs_data->data + length;
	 */
	return s_check_end(s);
}

/* Send an EDrq message (ASN.1 PER) */
static void
mcs_send_edrq(RDConnectionRef conn)
{
	RDStreamRef s;

	s = iso_init(conn, 5);

	out_uint8(s, (MCS_EDRQ << 2));
	out_uint16_be(s, 1);	/* height */
	out_uint16_be(s, 1);	/* interval */

	s_mark_end(s);
	iso_send(conn, s);
}

/* Send an AUrq message (ASN.1 PER) */
static void
mcs_send_aurq(RDConnectionRef conn)
{
	RDStreamRef s;

	s = iso_init(conn, 1);

	out_uint8(s, (MCS_AURQ << 2));

	s_mark_end(s);
	iso_send(conn, s);
}

/* Expect a AUcf message (ASN.1 PER) */
static RD_BOOL
mcs_recv_aucf(RDConnectionRef conn)
{
	uint8 opcode, result;
	RDStreamRef s;

	s = iso_recv(conn, NULL);
	if (s == NULL)
		return False;

	in_uint8(s, opcode);
	if ((opcode >> 2) != MCS_AUCF)
	{
		error("expected AUcf, got %d\n", opcode);
		return False;
	}

	in_uint8(s, result);
	if (result != 0)
	{
		error("AUrq: %d\n", result);
		return False;
	}

	if (opcode & 2)
		in_uint16_be(s, conn->mcsUserid);

	return s_check_end(s);
}

/* Send a CJrq message (ASN.1 PER) */
static void
mcs_send_cjrq(RDConnectionRef conn, uint16 chanid)
{
	RDStreamRef s;

	DEBUG_RDP5(("Sending CJRQ for channel #%d\n", chanid));

	s = iso_init(conn, 5);

	out_uint8(s, (MCS_CJRQ << 2));
	out_uint16_be(s, conn->mcsUserid);
	out_uint16_be(s, chanid);

	s_mark_end(s);
	iso_send(conn, s);
}

/* Expect a CJcf message (ASN.1 PER) */
static RD_BOOL
mcs_recv_cjcf(RDConnectionRef conn)
{
	uint8 opcode, result;
	RDStreamRef s;

	s = iso_recv(conn, NULL);
	if (s == NULL)
		return False;

	in_uint8(s, opcode);
	if ((opcode >> 2) != MCS_CJCF)
	{
		error("expected CJcf, got %d\n", opcode);
		return False;
	}

	in_uint8(s, result);
	if (result != 0)
	{
		error("CJrq: %d\n", result);
		return False;
	}

	in_uint8s(s, 4);	/* mcs_userid, req_chanid */
	if (opcode & 2)
		in_uint8s(s, 2);	/* join_chanid */

	return s_check_end(s);
}

/* Initialise an MCS transport data packet */
RDStreamRef
mcs_init(RDConnectionRef conn, int length)
{
	RDStreamRef s;

	s = iso_init(conn, length + 8);
	s_push_layer(s, mcs_hdr, 8);

	return s;
}

/* Send an MCS transport data packet to a specific channel */
void
mcs_send_to_channel(RDConnectionRef conn, RDStreamRef s, uint16 channel)
{
	uint16 length;

	s_pop_layer(s, mcs_hdr);
	length = s->end - s->p - 8;
	length |= 0x8000;

	out_uint8(s, (MCS_SDRQ << 2));
	out_uint16_be(s, conn->mcsUserid);
	out_uint16_be(s, channel);
	out_uint8(s, 0x70);	/* flags */
	out_uint16_be(s, length);

	iso_send(conn, s);
}

/* Send an MCS transport data packet to the global channel */
void
mcs_send(RDConnectionRef conn, RDStreamRef s)
{
	mcs_send_to_channel(conn, s, MCS_GLOBAL_CHANNEL);
}

/* Receive an MCS transport data packet */
RDStreamRef
mcs_recv(RDConnectionRef conn, uint16 * channel, uint8 * rdpver)
{
	uint8 opcode, appid, length;
	RDStreamRef s;

	s = iso_recv(conn, rdpver);
	if (s == NULL)
		return NULL;
	if (rdpver != NULL)
		if (*rdpver != 3)
			return s;
	in_uint8(s, opcode);
	appid = opcode >> 2;
	if (appid != MCS_SDIN)
	{
		if (appid != MCS_DPUM)
		{
			error("expected data, got %d\n", opcode);
		}
		return NULL;
	}
	in_uint8s(s, 2);	/* userid */
	in_uint16_be(s, *channel);
	in_uint8s(s, 1);	/* flags */
	in_uint8(s, length);
	if (length & 0x80)
		in_uint8s(s, 1);	/* second byte of length */
	return s;
}

/* Establish a connection up to the MCS layer */
RD_BOOL
mcs_connect(RDConnectionRef conn, const char *server, RDStreamRef mcs_data, char *username)
{
	unsigned int i;

	if (!iso_connect(conn, server, username))
		return False;

	mcs_send_connect_initial(conn, mcs_data);
	if (!mcs_recv_connect_response(conn, mcs_data))
		goto error;

	mcs_send_edrq(conn);

	mcs_send_aurq(conn);
	if (!mcs_recv_aucf(conn))
		goto error;

	mcs_send_cjrq(conn, conn->mcsUserid + MCS_USERCHANNEL_BASE);

	if (!mcs_recv_cjcf(conn))
		goto error;

	mcs_send_cjrq(conn, MCS_GLOBAL_CHANNEL);
	if (!mcs_recv_cjcf(conn))
		goto error;

	for (i = 0; i < conn->numChannels; i++)
	{
		mcs_send_cjrq(conn, conn->channels[i].mcs_id);
		if (!mcs_recv_cjcf(conn))
			goto error;
	}
	return True;

      error:
	iso_disconnect(conn);
	return False;
}

/* Establish a connection up to the MCS layer */
RD_BOOL
mcs_reconnect(RDConnectionRef conn, char *server, RDStreamRef mcs_data)
{
	unsigned int i;

	if (!iso_reconnect(conn, server))
		return False;

	mcs_send_connect_initial(conn, mcs_data);
	if (!mcs_recv_connect_response(conn, mcs_data))
		goto error;

	mcs_send_edrq(conn);

	mcs_send_aurq(conn);
	if (!mcs_recv_aucf(conn))
		goto error;

	mcs_send_cjrq(conn, conn->mcsUserid + MCS_USERCHANNEL_BASE);

	if (!mcs_recv_cjcf(conn))
		goto error;

	mcs_send_cjrq(conn, MCS_GLOBAL_CHANNEL);
	if (!mcs_recv_cjcf(conn))
		goto error;

	for (i = 0; i < conn->numChannels; i++)
	{
		mcs_send_cjrq(conn, conn->channels[i].mcs_id);
		if (!mcs_recv_cjcf(conn))
			goto error;
	}
	return True;

      error:
	iso_disconnect(conn);
	return False;
}

/* Disconnect from the MCS layer */
void
mcs_disconnect(RDConnectionRef conn)
{
	iso_disconnect(conn);
}

/* reset the state of the mcs layer */
void
mcs_reset_state(RDConnectionRef conn)
{
	conn->mcsUserid = 0;
	iso_reset_state(conn);
}