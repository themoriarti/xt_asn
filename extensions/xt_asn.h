/* ipt_asn.h header file for libipt_asn.c and ipt_asn.c
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Copyright (c) 2004, 2005, 2006, 2007, 2008
 *
 * Samuel Jean
 * Nicolas Bouliane
 */
#ifndef _LINUX_NETFILTER_XT_asn_H
#define _LINUX_NETFILTER_XT_asn_H 1

enum {
	XT_asn_SRC = 1 << 0,	/* Perform check on Source IP */
	XT_asn_DST = 1 << 1,	/* Perform check on Destination IP */
	XT_asn_INV = 1 << 2,	/* Negate the condition */

	XT_asn_MAX = 15,	/* Maximum of ASNs */
};

/* Yup, an address range will be passed in with host-order */
struct asn_subnet4 {
	__u32 begin;
	__u32 end;
};

struct asn_subnet6 {
	struct in6_addr begin, end;
};

struct asn_country_user {
	aligned_u64 subnets;
	__u32 count;
	__u32 cc;
};

struct asn_country_kernel;

union asn_country_group {
	aligned_u64 user; /* struct asn_country_user * */
	struct asn_country_kernel *kernel;
};

struct xt_asn_match_info {
	__u8 flags;
	__u8 count;
	__u32 cc[XT_asn_MAX];

	/* Used internally by the kernel */
	union asn_country_group mem[XT_asn_MAX];
};

#define COUNTRY(cc) ((cc) >> 8), ((cc) & 0x00FF)

#endif /* _LINUX_NETFILTER_XT_asn_H */
