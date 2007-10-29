/* -*- c-basic-offset: 8 -*-
   rdesktop: A Remote Desktop Protocol client.
   Protocol services - RDP encryption and licensing
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

#import "rdesktop.h"

/*
 * I believe this is based on SSLv3 with the following differences:
 *  MAC algorithm (5.2.3.1) uses only 32-bit length in place of seq_num/type/length fields
 *  MAC algorithm uses SHA1 and MD5 for the two hash functions instead of one or other
 *  key_block algorithm (6.2.2) uses 'X', 'YY', 'ZZZ' instead of 'A', 'BB', 'CCC'
 *  key_block partitioning is different (16 bytes each: MAC secret, decrypt key, encrypt key)
 *  encryption/decryption keys updated every 4096 packets
 * See http://wp.netscape.com/eng/ssl3/draft302.txt
 */

/*
 * 48-byte transformation used to generate master secret (6.1) and key material (6.2.2).
 * Both SHA1 and MD5 algorithms are used.
 */
void
sec_hash_48(uint8 * out, uint8 * in, uint8 * salt1, uint8 * salt2, uint8 salt)
{
	uint8 shasig[20];
	uint8 pad[4];
	SHA_CTX sha;
	MD5_CTX md5;
	int i;

	for (i = 0; i < 3; i++)
	{
		memset(pad, salt + i, i + 1);

		SHA1_Init(&sha);
		SHA1_Update(&sha, pad, i + 1);
		SHA1_Update(&sha, in, 48);
		SHA1_Update(&sha, salt1, 32);
		SHA1_Update(&sha, salt2, 32);
		SHA1_Final(shasig, &sha);

		MD5_Init(&md5);
		MD5_Update(&md5, in, 48);
		MD5_Update(&md5, shasig, 20);
		MD5_Final(&out[i * 16], &md5);
	}
}

/*
 * 16-byte transformation used to generate export keys (6.2.2).
 */
void
sec_hash_16(uint8 * out, uint8 * in, uint8 * salt1, uint8 * salt2)
{
	MD5_CTX md5;

	MD5_Init(&md5);
	MD5_Update(&md5, in, 16);
	MD5_Update(&md5, salt1, 32);
	MD5_Update(&md5, salt2, 32);
	MD5_Final(out, &md5);
}

/* Reduce key entropy from 64 to 40 bits */
static void
sec_make_40bit(uint8 * key)
{
	key[0] = 0xd1;
	key[1] = 0x26;
	key[2] = 0x9e;
}

/* Generate encryption keys given client and server randoms */
static void
sec_generate_keys(rdcConnection conn, uint8 * client_random, uint8 * server_random, int rc4_key_size)
{
	uint8 pre_master_secret[48];
	uint8 master_secret[48];
	uint8 key_block[48];

	/* Construct pre-master secret */
	memcpy(pre_master_secret, client_random, 24);
	memcpy(pre_master_secret + 24, server_random, 24);

	/* Generate master secret and then key material */
	sec_hash_48(master_secret, pre_master_secret, client_random, server_random, 'A');
	sec_hash_48(key_block, master_secret, client_random, server_random, 'X');

	/* First 16 bytes of key material is MAC secret */
	memcpy(conn->secSignKey, key_block, 16);

	/* Generate export keys from next two blocks of 16 bytes */
	sec_hash_16(conn->secDecryptKey, &key_block[16], client_random, server_random);
	sec_hash_16(conn->secEncryptKey, &key_block[32], client_random, server_random);

	if (rc4_key_size == 1)
	{
		DEBUG(("40-bit encryption enabled\n"));
		sec_make_40bit(conn->secSignKey);
		sec_make_40bit(conn->secDecryptKey);
		sec_make_40bit(conn->secEncryptKey);
		conn->rc4KeyLen = 8;
	}
	else
	{
		DEBUG(("rc_4_key_size == %d, 128-bit encryption enabled\n", rc4_key_size));
		conn->rc4KeyLen = 16;
	}

	/* Save initial RC4 keys as update keys */
	memcpy(conn->secDecryptUpdateKey, conn->secDecryptKey, 16);
	memcpy(conn->secEncryptUpdateKey, conn->secEncryptKey, 16);

	/* Initialise RC4 state arrays */
	RC4_set_key(&conn->rc4DecryptKey, conn->rc4KeyLen, conn->secDecryptKey);
	RC4_set_key(&conn->rc4EncryptKey, conn->rc4KeyLen, conn->secEncryptKey);
}

static uint8 pad_54[40] = {
	54, 54, 54, 54, 54, 54, 54, 54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
	54, 54, 54,
	54, 54, 54, 54, 54, 54, 54, 54, 54, 54, 54, 54, 54, 54, 54, 54, 54,
	54, 54, 54
};

static uint8 pad_92[48] = {
	92, 92, 92, 92, 92, 92, 92, 92, 92, 92, 92, 92, 92, 92, 92, 92, 92,
	92, 92, 92, 92, 92, 92, 92,
	92, 92, 92, 92, 92, 92, 92, 92, 92, 92, 92, 92, 92, 92, 92, 92, 92,
	92, 92, 92, 92, 92, 92, 92
};

/* Output a uint32 into a buffer (little-endian) */
void
buf_out_uint32(uint8 * buffer, uint32 value)
{
	buffer[0] = (value) & 0xff;
	buffer[1] = (value >> 8) & 0xff;
	buffer[2] = (value >> 16) & 0xff;
	buffer[3] = (value >> 24) & 0xff;
}

/* Generate a MAC hash (5.2.3.1), using a combination of SHA1 and MD5 */
void
sec_sign(uint8 * signature, int siglen, uint8 * session_key, int keylen, uint8 * data, int datalen)
{
	uint8 shasig[20];
	uint8 md5sig[16];
	uint8 lenhdr[4];
	SHA_CTX sha;
	MD5_CTX md5;

	buf_out_uint32(lenhdr, datalen);

	SHA1_Init(&sha);
	SHA1_Update(&sha, session_key, keylen);
	SHA1_Update(&sha, pad_54, 40);
	SHA1_Update(&sha, lenhdr, 4);
	SHA1_Update(&sha, data, datalen);
	SHA1_Final(shasig, &sha);

	MD5_Init(&md5);
	MD5_Update(&md5, session_key, keylen);
	MD5_Update(&md5, pad_92, 48);
	MD5_Update(&md5, shasig, 20);
	MD5_Final(md5sig, &md5);

	memcpy(signature, md5sig, siglen);
}

/* Update an encryption key */
static void
sec_update(rdcConnection conn, uint8 * key, uint8 * update_key)
{
	uint8 shasig[20];
	SHA_CTX sha;
	MD5_CTX md5;
	RC4_KEY update;

	SHA1_Init(&sha);
	SHA1_Update(&sha, update_key, conn->rc4KeyLen);
	SHA1_Update(&sha, pad_54, 40);
	SHA1_Update(&sha, key, conn->rc4KeyLen);
	SHA1_Final(shasig, &sha);

	MD5_Init(&md5);
	MD5_Update(&md5, update_key, conn->rc4KeyLen);
	MD5_Update(&md5, pad_92, 48);
	MD5_Update(&md5, shasig, 20);
	MD5_Final(key, &md5);

	RC4_set_key(&update, conn->rc4KeyLen, key);
	RC4(&update, conn->rc4KeyLen, key, key);

	if (conn->rc4KeyLen == 8)
		sec_make_40bit(key);
}

/* Encrypt data using RC4 */
static void
sec_encrypt(rdcConnection conn, uint8 * data, int length)
{
	if (conn->encUseCount == 4096)
	{
		sec_update(conn, conn->secEncryptKey, conn->secEncryptUpdateKey);
		RC4_set_key(&conn->rc4EncryptKey, conn->rc4KeyLen, conn->secEncryptKey);
		conn->encUseCount = 0;
	}

	RC4(&conn->rc4EncryptKey, length, data, data);
	conn->encUseCount++;
}

/* Decrypt data using RC4 */
void
sec_decrypt(rdcConnection conn, uint8 * data, int length)
{
	
	if (conn->decUseCount == 4096)
	{
		sec_update(conn, conn->secDecryptKey, conn->secDecryptUpdateKey);
		RC4_set_key(&conn->rc4DecryptKey, conn->rc4KeyLen, conn->secDecryptKey);
		conn->decUseCount = 0;
	}

	RC4(&conn->rc4DecryptKey, length, data, data);
	conn->decUseCount++;
}

static void
reverse(uint8 * p, int len)
{
	int i, j;
	uint8 temp;

	for (i = 0, j = len - 1; i < j; i++, j--)
	{
		temp = p[i];
		p[i] = p[j];
		p[j] = temp;
	}
}

/* Perform an RSA public key encryption operation */
static void
sec_rsa_encrypt(uint8 * out, uint8 * in, int len, uint8 * modulus, uint8 * exponent)
{
	BN_CTX *ctx;
	BIGNUM mod, exp, x, y;
	uint8 inr[SEC_MODULUS_SIZE];
	int outlen;

	reverse(modulus, SEC_MODULUS_SIZE);
	reverse(exponent, SEC_EXPONENT_SIZE);
	memcpy(inr, in, len);
	reverse(inr, len);

	ctx = BN_CTX_new();
	BN_init(&mod);
	BN_init(&exp);
	BN_init(&x);
	BN_init(&y);

	BN_bin2bn(modulus, SEC_MODULUS_SIZE, &mod);
	BN_bin2bn(exponent, SEC_EXPONENT_SIZE, &exp);
	BN_bin2bn(inr, len, &x);
	BN_mod_exp(&y, &x, &exp, &mod, ctx);
	outlen = BN_bn2bin(&y, out);
	reverse(out, outlen);
	if (outlen < SEC_MODULUS_SIZE)
		memset(out + outlen, 0, SEC_MODULUS_SIZE - outlen);

	BN_free(&y);
	BN_clear_free(&x);
	BN_free(&exp);
	BN_free(&mod);
	BN_CTX_free(ctx);
}

/* Initialise secure transport packet */
STREAM
sec_init(rdcConnection conn, uint32 flags, int maxlen)
{
	int hdrlen;
	STREAM s;

	if (!conn->licenseIssued)
		hdrlen = (flags & SEC_ENCRYPT) ? 12 : 4;
	else
		hdrlen = (flags & SEC_ENCRYPT) ? 12 : 0;
	s = mcs_init(conn, maxlen + hdrlen);
	s_push_layer(s, sec_hdr, hdrlen);

	return s;
}

/* Transmit secure transport packet over specified channel */
void
sec_send_to_channel(rdcConnection conn, STREAM s, uint32 flags, uint16 channel)
{
	int datalen;

	s_pop_layer(s, sec_hdr);
	if (!conn->licenseIssued || (flags & SEC_ENCRYPT))
		out_uint32_le(s, flags);

	if (flags & SEC_ENCRYPT)
	{
		flags &= ~SEC_ENCRYPT;
		datalen = s->end - s->p - 8;

#if WITH_DEBUG_NETWORK
		DEBUG(("Sending encrypted packet:\n"));
		hexdump(s->p + 8, datalen);
#endif

		sec_sign(s->p, 8, conn->secSignKey, conn->rc4KeyLen, s->p + 8, datalen);
		sec_encrypt(conn, s->p + 8, datalen);
	}

	mcs_send_to_channel(conn, s, channel);
}

/* Transmit secure transport packet */

void
sec_send(rdcConnection conn, STREAM s, uint32 flags)
{
	sec_send_to_channel(conn, s, flags, MCS_GLOBAL_CHANNEL);
}


/* Transfer the client random to the server */
static void
sec_establish_key(rdcConnection conn)
{
	uint32 length = SEC_MODULUS_SIZE + SEC_PADDING_SIZE;
	uint32 flags = SEC_CLIENT_RANDOM;
	STREAM s;

	s = sec_init(conn, flags, 76);

	out_uint32_le(s, length);
	out_uint8p(s, conn->secCryptedRandom, SEC_MODULUS_SIZE);
	out_uint8s(s, SEC_PADDING_SIZE);

	s_mark_end(s);
	sec_send(conn, s, flags);
}

/* Output connect initial data blob */
static void
sec_out_mcs_data(rdcConnection conn, STREAM s)
{
	int hostlen = 2 * strlen(conn->hostname);
	int length = 158 + 76 + 12 + 4;
	unsigned int i;

	if (conn->numChannels > 0)
		length += conn->numChannels * 12 + 8;

	if (hostlen > 30)
		hostlen = 30;

	/* Generic Conference Control (T.124) ConferenceCreateRequest */
	out_uint16_be(s, 5);
	out_uint16_be(s, 0x14);
	out_uint8(s, 0x7c);
	out_uint16_be(s, 1);

	out_uint16_be(s, (length | 0x8000));	/* remaining length */

	out_uint16_be(s, 8);	/* length? */
	out_uint16_be(s, 16);
	out_uint8(s, 0);
	out_uint16_le(s, 0xc001);
	out_uint8(s, 0);

	out_uint32_le(s, 0x61637544);	/* OEM ID: "Duca", as in Ducati. */
	out_uint16_be(s, ((length - 14) | 0x8000));	/* remaining length */

	/* Client information */
	out_uint16_le(s, SEC_TAG_CLI_INFO);
	out_uint16_le(s, 212);	/* length */
	out_uint16_le(s, conn->useRdp5 ? 4 : 1);	/* RDP version. 1 == RDP4, 4 == RDP5. */
	out_uint16_le(s, 8);
	out_uint16_le(s, conn->screenWidth);
	out_uint16_le(s, conn->screenHeight);
	out_uint16_le(s, 0xca01);
	out_uint16_le(s, 0xaa03);
	out_uint32_le(s, conn->keyboardLayout);
	out_uint32_le(s, 2600);	/* Client build. We are now 2600 compatible :-) */

	/* Unicode name of client, padded to 32 bytes */
	rdp_out_unistr(s, conn->hostname, hostlen);
	out_uint8s(s, 30 - hostlen);

	out_uint32_le(s, 4); /* keyboard type */
	out_uint32_le(s, 0); /* keyboard subtype */
	out_uint32_le(s, 12); /* keyboard function key count */
	out_uint8s(s, 64);	/* reserved? 4 + 12 doublewords */
	out_uint16_le(s, 0xca01);	/* colour depth? */
	out_uint16_le(s, 1);

	out_uint32(s, 0);
	out_uint8(s, conn->serverBpp);
	out_uint16_le(s, 0x0700);
	out_uint8(s, 0);
	out_uint32_le(s, 1);
	out_uint8s(s, 64);	/* End of client info */

	out_uint16_le(s, SEC_TAG_CLI_4);
	out_uint16_le(s, 12);
	out_uint32_le(s, conn->consoleSession ? 0xb : 9);
	out_uint32(s, 0);

	/* Client encryption settings */
	out_uint16_le(s, SEC_TAG_CLI_CRYPT);
	out_uint16_le(s, 12);	/* length */
	out_uint32_le(s, conn->useEncryption ? 0x3 : 0);	/* encryption supported, 128-bit supported */
	out_uint32(s, 0);	/* Unknown */

	DEBUG_RDP5(("conn->numChannels is %d\n", conn->numChannels));
	if (conn->numChannels > 0)
	{
		out_uint16_le(s, SEC_TAG_CLI_CHANNELS);
		out_uint16_le(s, conn->numChannels * 12 + 8);	/* length */
		out_uint32_le(s, conn->numChannels);	/* number of virtual channels */
		for (i = 0; i < conn->numChannels; i++)
		{
			DEBUG_RDP5(("Requesting channel %s\n", conn->channels[i].name));
			out_uint8a(s, conn->channels[i].name, 8);
			out_uint32_be(s, conn->channels[i].flags);
		}
	}

	s_mark_end(s);
}

/* Parse a public key structure */
static RDCBOOL
sec_parse_public_key(STREAM s, uint8 ** modulus, uint8 ** exponent)
{
	uint32 magic, modulus_len;

	in_uint32_le(s, magic);
	if (magic != SEC_RSA_MAGIC)
	{
		error("RSA magic 0x%x\n", magic);
		return False;
	}

	in_uint32_le(s, modulus_len);
	if (modulus_len != SEC_MODULUS_SIZE + SEC_PADDING_SIZE)
	{
		error("modulus len 0x%x\n", modulus_len);
		return False;
	}

	in_uint8s(s, 8);	/* modulus_bits, unknown */
	in_uint8p(s, *exponent, SEC_EXPONENT_SIZE);
	in_uint8p(s, *modulus, SEC_MODULUS_SIZE);
	in_uint8s(s, SEC_PADDING_SIZE);

	return s_check(s);
}

static RDCBOOL
sec_parse_x509_key(rdcConnection conn, X509 * cert)
{
	EVP_PKEY *epk = NULL;
	/* By some reason, Microsoft sets the OID of the Public RSA key to
	   the oid for "MD5 with RSA Encryption" instead of "RSA Encryption"

	   Kudos to Richard Levitte for the following (. intiutive .) 
	   lines of code that resets the OID and let's us extract the key. */
	if (OBJ_obj2nid(cert->cert_info->key->algor->algorithm) == NID_md5WithRSAEncryption)
	{
		DEBUG_RDP5(("Re-setting algorithm type to RSA in server certificate\n"));
		cert->cert_info->key->algor->algorithm = OBJ_nid2obj(NID_rsaEncryption);
	}
	epk = X509_get_pubkey(cert);
	if (NULL == epk)
	{
		error("Failed to extract public key from certificate\n");
		return False;
	}

	conn->serverPublicKey = (RSA *) epk->pkey.ptr;

	return True;
}


/* Parse a crypto information structure */
static RDCBOOL
sec_parse_crypt_info(rdcConnection conn, STREAM s, uint32 * rc4_key_size,
		     uint8 ** server_random, uint8 ** modulus, uint8 ** exponent)
{
	uint32 crypt_level, random_len, rsa_info_len;
	uint32 cacert_len, cert_len, flags;
	X509 *cacert, *server_cert;
	uint16 tag, length;
	uint8 *next_tag, *end;

	in_uint32_le(s, *rc4_key_size);	/* 1 = 40-bit, 2 = 128-bit */
	in_uint32_le(s, crypt_level);	/* 1 = low, 2 = medium, 3 = high */
	if (crypt_level == 0)	/* no encryption */
		return False;
	in_uint32_le(s, random_len);
	in_uint32_le(s, rsa_info_len);

	if (random_len != SEC_RANDOM_SIZE)
	{
		error("random len %d, expected %d\n", random_len, SEC_RANDOM_SIZE);
		return False;
	}

	in_uint8p(s, *server_random, random_len);

	/* RSA info */
	end = s->p + rsa_info_len;
	if (end > s->end)
		return False;

	in_uint32_le(s, flags);	/* 1 = RDP4-style, 0x80000002 = X.509 */
	if (flags & 1)
	{
		DEBUG_RDP5(("We're going for the RDP4-style encryption\n"));
		in_uint8s(s, 8);	/* unknown */

		while (s->p < end)
		{
			in_uint16_le(s, tag);
			in_uint16_le(s, length);

			next_tag = s->p + length;

			switch (tag)
			{
				case SEC_TAG_PUBKEY:
					if (!sec_parse_public_key(s, modulus, exponent))
						return False;
					DEBUG_RDP5(("Got Public key, RDP4-style\n"));

					break;

				case SEC_TAG_KEYSIG:
					/* Is this a Microsoft key that we just got? */
					/* Care factor: zero! */
					/* Actually, it would probably be a good idea to check if the public key is signed with this key, and then store this 
					   key as a known key of the hostname. This would prevent some MITM-attacks. */
					break;

				default:
					unimpl("crypt tag 0x%x\n", tag);
			}

			s->p = next_tag;
		}
	}
	else
	{
		uint32 certcount;

		DEBUG_RDP5(("We're going for the RDP5-style encryption\n"));
		in_uint32_le(s, certcount);	/* Number of certificates */

		if (certcount < 2)
		{
			error("Server didn't send enough X509 certificates\n");
			return False;
		}

		for (; certcount > 2; certcount--)
		{		/* ignore all the certificates between the root and the signing CA */
			uint32 ignorelen;
			X509 *ignorecert;

			DEBUG_RDP5(("Ignored certs left: %d\n", certcount));

			in_uint32_le(s, ignorelen);
			DEBUG_RDP5(("Ignored Certificate length is %d\n", ignorelen));
			ignorecert = d2i_X509(NULL, &(s->p), ignorelen);

			if (ignorecert == NULL)
			{	/* XXX: error out? */
				DEBUG_RDP5(("got a bad cert: this will probably screw up the rest of the communication\n"));
			}

#ifdef WITH_DEBUG_RDP5
			DEBUG_RDP5(("cert #%d (ignored):\n", certcount));
			X509_print_fp(stdout, ignorecert);
#endif
		}

		/* Do da funky X.509 stuffy 

		   "How did I find out about this?  I looked up and saw a
		   bright light and when I came to I had a scar on my forehead
		   and knew about X.500"
		   - Peter Gutman in a early version of 
		   http://www.cs.auckland.ac.nz/~pgut001/pubs/x509guide.txt
		 */

		in_uint32_le(s, cacert_len);
		DEBUG_RDP5(("CA Certificate length is %d\n", cacert_len));
		cacert = d2i_X509(NULL, &(s->p), cacert_len);
		/* Note: We don't need to move s->p here - d2i_X509 is
		   "kind" enough to do it for us */
		if (NULL == cacert)
		{
			error("Couldn't load CA Certificate from server\n");
			return False;
		}

		/* Currently, we don't use the CA Certificate. 
		   FIXME: 
		   *) Verify the server certificate (server_cert) with the 
		   CA certificate.
		   *) Store the CA Certificate with the hostname of the 
		   server we are connecting to as key, and compare it
		   when we connect the next time, in order to prevent
		   MITM-attacks.
		 */

		in_uint32_le(s, cert_len);
		DEBUG_RDP5(("Certificate length is %d\n", cert_len));
		server_cert = d2i_X509(NULL, &(s->p), cert_len);
		if (NULL == server_cert)
		{
			error("Couldn't load Certificate from server\n");
			return False;
		}

		in_uint8s(s, 16);	/* Padding */

		/* Note: Verifying the server certificate must be done here, 
		   before sec_parse_public_key since we'll have to apply
		   serious violence to the key after this */

		if (!sec_parse_x509_key(conn, server_cert))
		{
			DEBUG_RDP5(("Didn't parse X509 correctly\n"));
			return False;
		}
		return True;	/* There's some garbage here we don't care about */
	}
	return s_check_end(s);
}

/* Process crypto information blob */
static void
sec_process_crypt_info(rdcConnection conn, STREAM s)
{
	uint8 *server_random, *modulus, *exponent;
	uint8 client_random[SEC_RANDOM_SIZE];
	uint32 rc4_key_size;
	uint8 inr[SEC_MODULUS_SIZE];

	if (!sec_parse_crypt_info(conn, s, &rc4_key_size, &server_random, &modulus, &exponent))
	{
		DEBUG(("Failed to parse crypt info\n"));
		return;
	}

	DEBUG(("Generating client random\n"));
	/* Generate a client random, and hence determine encryption keys */
	/* This is what the MS client do: */
	memset(inr, 0, SEC_RANDOM_SIZE);
	/*  *ARIGL!* Plaintext attack, anyone?
	   I tried doing:
	   generate_random(inr);
	   ..but that generates connection errors now and then (yes, 
	   "now and then". Something like 0 to 3 attempts needed before a 
	   successful connection. Nice. Not! 
	 */

	generate_random(client_random);
	if (NULL != conn->serverPublicKey)
	{			/* Which means we should use 
				   RDP5-style encryption */

		memcpy(inr + SEC_RANDOM_SIZE, client_random, SEC_RANDOM_SIZE);
		reverse(inr + SEC_RANDOM_SIZE, SEC_RANDOM_SIZE);

		RSA_public_encrypt(SEC_MODULUS_SIZE,
				   inr, conn->secCryptedRandom, conn->serverPublicKey, RSA_NO_PADDING);

		reverse(conn->secCryptedRandom, SEC_MODULUS_SIZE);

	}
	else
	{			/* RDP4-style encryption */
		sec_rsa_encrypt(conn->secCryptedRandom,
				client_random, SEC_RANDOM_SIZE, modulus, exponent);
	}
	sec_generate_keys(conn, client_random, server_random, rc4_key_size);
}


/* Process SRV_INFO, find RDP version supported by server */
static void
sec_process_srv_info(rdcConnection conn, STREAM s)
{
	in_uint16_le(s, conn->serverRdpVersion);
	DEBUG_RDP5(("Server RDP version is %d\n", conn->serverRdpVersion));
	if (1 == conn->serverRdpVersion)
	{
		conn->useRdp5 = 0;
		conn->serverBpp = 8;
	}
}


/* Process connect response data blob */
void
sec_process_mcs_data(rdcConnection conn, STREAM s)
{
	uint16 tag, length;
	uint8 *next_tag;
	uint8 len;

	in_uint8s(s, 21);	/* header (T.124 ConferenceCreateResponse) */
	in_uint8(s, len);
	if (len & 0x80)
		in_uint8(s, len);

	while (s->p < s->end)
	{
		in_uint16_le(s, tag);
		in_uint16_le(s, length);

		if (length <= 4)
			return;

		next_tag = s->p + length - 4;

		switch (tag)
		{
			case SEC_TAG_SRV_INFO:
				sec_process_srv_info(conn, s);
				break;

			case SEC_TAG_SRV_CRYPT:
				sec_process_crypt_info(conn, s);
				break;

			case SEC_TAG_SRV_CHANNELS:
				/* FIXME: We should parse this information and
				   use it to map RDP5 channels to MCS 
				   channels */
				break;

			default:
				unimpl("response tag 0x%x\n", tag);
		}

		s->p = next_tag;
	}
}

/* Receive secure transport packet */
STREAM
sec_recv(rdcConnection conn, uint8 * rdpver)
{
	uint32 sec_flags;
	uint16 channel;
	STREAM s;

	while ((s = mcs_recv(conn, &channel, rdpver)) != NULL)
	{
		if (rdpver != NULL)
		{
			if (*rdpver != 3)
			{
				if (*rdpver & 0x80)
				{
					in_uint8s(s, 8);	/* signature */
					sec_decrypt(conn, s->p, s->end - s->p);
				}
				return s;
			}
		}
		if (conn->useEncryption || !conn->licenseIssued)
		{
			in_uint32_le(s, sec_flags);

			if (sec_flags & SEC_ENCRYPT)
			{
				in_uint8s(s, 8);	/* signature */
				sec_decrypt(conn, s->p, s->end - s->p);
			}

			if (sec_flags & SEC_LICENCE_NEG)
			{
				licence_process(conn, s);
				continue;
			}
		}

		if (channel != MCS_GLOBAL_CHANNEL)
		{
			channel_process(conn, s, channel);
			*rdpver = 0xff;
			return s;
		}

		return s;
	}

	return NULL;
}

/* Establish a secure connection */
RDCBOOL
sec_connect(rdcConnection conn, const char *server, char *username)
{
	struct stream mcs_data;

	/* We exchange some RDP data during the MCS-Connect */
	mcs_data.size = 512;
	mcs_data.p = mcs_data.data = (uint8 *) xmalloc(mcs_data.size);
	sec_out_mcs_data(conn, &mcs_data);

	if (!mcs_connect(conn, server, &mcs_data, username))
		return False;

	/*      sec_process_mcs_data(&mcs_data); */
	if (conn->useEncryption)
		sec_establish_key(conn);
	xfree(mcs_data.data);
	return True;
}

/* Disconnect a connection */
void
sec_disconnect(rdcConnection conn)
{
	mcs_disconnect(conn);
}
