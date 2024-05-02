/*
 *	"asn" match extension for iptables
 *	Copyright © Samuel Jean <peejix [at] people netfilter org>, 2004 - 2008
 *	Copyright © Nicolas Bouliane <acidfu [at] people netfilter org>, 2004 - 2008
 *	Jan Engelhardt <jengelh [at] medozas de>, 2008-2011
 *
 *	This program is free software; you can redistribute it and/or
 *	modify it under the terms of the GNU General Public License; either
 *	version 2 of the License, or any later version, as published by the
 *	Free Software Foundation.
 */
#include <sys/stat.h>
#include <sys/types.h>
#include <ctype.h>
#include <endian.h>
#include <errno.h>
#include <fcntl.h>
#include <getopt.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <xtables.h>
#include "xt_asn.h"
#include "compat_user.h"
#define ASN_DB_DIR "/usr/share/xt_asn"

static void asn_help(void)
{
	printf (
	"asn match options:\n"
	"[!] --src-asn, --source-asn ASNnumber[,ASNnumber...]\n"
	"	Match packet coming from (one of) the specified ASN(s)\n"
	"[!] --dst-asn, --destination-asn ASNnumber[,ASNnumber...]\n"
	"	Match packet going to (one of) the specified ASN(s)\n"
	);
}

static struct option asn_opts[] = {
	{.name = "dst-asn",              .has_arg = true, .val = '2'},
	{.name = "destination-asn", .has_arg = true, .val = '2'},
	{.name = "src-asn",              .has_arg = true, .val = '1'},
	{.name = "source-asn",      .has_arg = true, .val = '1'},
	{NULL},
};

static void *
asn_get_subnets(const char *code, uint32_t *count, uint8_t nfproto)
{
	void *subnets;
	struct stat sb;
	char buf[256];
	int fd;

	/* Use simple integer vector files */
	if (nfproto == NFPROTO_IPV6) {
#if __BYTE_ORDER == _BIG_ENDIAN
		snprintf(buf, sizeof(buf), ASN_DB_DIR "/BE/%s.iv6", code);
#else
		snprintf(buf, sizeof(buf), ASN_DB_DIR "/LE/%s.iv6", code);
#endif
	} else {
#if __BYTE_ORDER == _BIG_ENDIAN
		snprintf(buf, sizeof(buf), ASN_DB_DIR "/BE/%s.iv4", code);
#else
		snprintf(buf, sizeof(buf), ASN_DB_DIR "/LE/%s.iv4", code);
#endif
	}

	if ((fd = open(buf, O_RDONLY)) < 0) {
		fprintf(stderr, "Could not open %s: %s\n", buf, strerror(errno));
		xtables_error(OTHER_PROBLEM, "Could not read asn database");
	}

	fstat(fd, &sb);
	*count = sb.st_size;
	switch (nfproto) {
	case NFPROTO_IPV6:
		if (sb.st_size % sizeof(struct asn_subnet6) != 0)
			xtables_error(OTHER_PROBLEM,
				"Database file %s seems to be corrupted", buf);
		*count /= sizeof(struct asn_subnet6);
		break;
	case NFPROTO_IPV4:
		if (sb.st_size % sizeof(struct asn_subnet4) != 0)
			xtables_error(OTHER_PROBLEM,
				"Database file %s seems to be corrupted", buf);
		*count /= sizeof(struct asn_subnet4);
		break;
	}
	subnets = malloc(sb.st_size);
	if (subnets == NULL)
		xtables_error(OTHER_PROBLEM, "asn: insufficient memory");
	read(fd, subnets, sb.st_size);
	close(fd);
	return subnets;
}
 
static struct asn_country_user *asn_load_cc(const char *code,
    unsigned int cc, uint8_t nfproto)
{
	struct asn_country_user *ginfo;
	ginfo = malloc(sizeof(struct asn_country_user));

	if (!ginfo)
		return NULL;

	ginfo->subnets = (unsigned long)asn_get_subnets(code,
	                 &ginfo->count, nfproto);
	ginfo->cc = cc;

	return ginfo;
}

static u_int32_t
check_asn_cc(char *cc, u_int32_t cc_used[], u_int8_t count)
{
	u_int8_t i;
	u_int32_t cc_int32;
        // Convert 32 bit unsinged integer (modern ASN are 32 bit)
        sscanf(cc, "%d", &cc_int32);
	// Check for presence of value in cc_used
	for (i = 0; i < count; i++)
		if (cc_int32 == cc_used[i])
			return 0; // Present, skip it!
	return cc_int32;
}

static unsigned int parse_asn_cc(const char *ccstr, uint32_t *cc,
    union asn_country_group *mem, uint8_t nfproto)
{
	char *buffer, *cp, *next;
	u_int8_t i, count = 0;
	u_int32_t cctmp;

	buffer = strdup(ccstr);
	if (!buffer)
		xtables_error(OTHER_PROBLEM,
			"asn: insufficient memory available");

	for (cp = buffer, i = 0; cp && i < XT_asn_MAX; cp = next, i++)
	{
		next = strchr(cp, ',');
		if (next) *next++ = '\0';

		if ((cctmp = check_asn_cc(cp, cc, count)) != 0) {
			if ((mem[count++].user =
			    (unsigned long)asn_load_cc(cp, cctmp, nfproto)) == 0)
				xtables_error(OTHER_PROBLEM,
					"asn: insufficient memory available");
			cc[count-1] = cctmp;
		}
	}

	if (cp)
		xtables_error(PARAMETER_PROBLEM,
			"asn: too many ASN numbers specified");
	free(buffer);

	if (count == 0)
		xtables_error(PARAMETER_PROBLEM,
			"asn: don't know what happened");

	return count;
}

static int asn_parse(int c, bool invert, unsigned int *flags,
    const char *arg, struct xt_asn_match_info *info, uint8_t nfproto)
{
	switch (c) {
	case '1':
		if (*flags & (XT_asn_SRC | XT_asn_DST))
			xtables_error(PARAMETER_PROBLEM,
				"asn: Only exactly one of --source-asn "
				"or --destination-asn must be specified!");

		*flags |= XT_asn_SRC;
		if (invert)
			*flags |= XT_asn_INV;

		info->count = parse_asn_cc(arg, info->cc, info->mem,
		              nfproto);
		info->flags = *flags;
		return true;

	case '2':
		if (*flags & (XT_asn_SRC | XT_asn_DST))
			xtables_error(PARAMETER_PROBLEM,
				"asn: Only exactly one of --source-asn "
				"or --destination-asn must be specified!");

		*flags |= XT_asn_DST;
		if (invert)
			*flags |= XT_asn_INV;

		info->count = parse_asn_cc(arg, info->cc, info->mem,
		              nfproto);
		info->flags = *flags;
		return true;
	}

	return false;
}

static int asn_parse6(int c, char **argv, int invert, unsigned int *flags,
    const void *entry, struct xt_entry_match **match)
{
	return asn_parse(c, invert, flags, optarg,
	       (void *)(*match)->data, NFPROTO_IPV6);
}

static int asn_parse4(int c, char **argv, int invert, unsigned int *flags,
    const void *entry, struct xt_entry_match **match)
{
	return asn_parse(c, invert, flags, optarg,
	       (void *)(*match)->data, NFPROTO_IPV4);
}

static void
asn_final_check(unsigned int flags)
{
	if (!flags)
		xtables_error(PARAMETER_PROBLEM,
			"asn: missing arguments");
}

static void
asn_print(const void *ip, const struct xt_entry_match *match, int numeric)
{
	const struct xt_asn_match_info *info = (void*)match->data;

	u_int8_t i;

	if (info->flags & XT_asn_SRC)
		printf(" Source ");
	else
		printf(" Destination ");

	if (info->count > 1)
		printf("ASNs: ");
	else
		printf("ASN: ");

	if (info->flags & XT_asn_INV)
		printf("! ");

	for (i = 0; i < info->count; i++)
		 printf("%sAS%d", i ? "," : "", info->cc[i]);
	printf(" ");
}

static void
asn_save(const void *ip, const struct xt_entry_match *match)
{
	const struct xt_asn_match_info *info = (void *)match->data;
	u_int8_t i;

	if (info->flags & XT_asn_INV)
		printf(" !");

	if (info->flags & XT_asn_SRC)
		printf(" --source-asn ");
	else
		printf(" --destination-asn ");

	for (i = 0; i < info->count; i++)
		printf("%s%d", i ? "," : "", info->cc[i]);
	printf(" ");
}

static struct xtables_match asn_match[] = {
	{
		.family        = NFPROTO_IPV6,
		.name          = "asn",
		.revision      = 1,
		.version       = XTABLES_VERSION,
		.size          = XT_ALIGN(sizeof(struct xt_asn_match_info)),
		.userspacesize = offsetof(struct xt_asn_match_info, mem),
		.help          = asn_help,
		.parse         = asn_parse6,
		.final_check   = asn_final_check,
		.print         = asn_print,
		.save          = asn_save,
		.extra_opts    = asn_opts,
	},
	{
		.family        = NFPROTO_IPV4,
		.name          = "asn",
		.revision      = 1,
		.version       = XTABLES_VERSION,
		.size          = XT_ALIGN(sizeof(struct xt_asn_match_info)),
		.userspacesize = offsetof(struct xt_asn_match_info, mem),
		.help          = asn_help,
		.parse         = asn_parse4,
		.final_check   = asn_final_check,
		.print         = asn_print,
		.save          = asn_save,
		.extra_opts    = asn_opts,
	},
};

static __attribute__((constructor)) void asn_mt_ldr(void)
{
	xtables_register_matches(asn_match,
		sizeof(asn_match) / sizeof(*asn_match));
}
