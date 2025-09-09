#!/bin/sh
ASN_DATA_URL="${ASN_DATA_URL:-http://127.0.0.1/asn.csv}"

# Load configuration if available
if [ -f /etc/xt_asn/xt_asn.conf ]; then
    source /etc/xt_asn/xt_asn.conf
fi

# Ensure we have a valid URL
if [ "$ASN_DATA_URL" = "http://127.0.0.1/asn.csv" ]; then
    echo "Warning: Using default URL. Please configure ASN_DATA_URL in /etc/xt_asn/xt_asn.conf"
    echo "Set ASN_DATA_URL to point to your ASN data server."
    exit 1
fi

yum -y install perl-Text-CSV_XS perl-Getopt-Long perl-IO

TEMPDIR="`mktemp -d`"

mkdir /usr/share/xt_asn
wget $ASN_DATA_URL -O $TEMPDIR/asn.csv
./xt_asn_build -D /usr/share/xt_asn $TEMPDIR/asn.csv
rm -f $TEMPDIR/*.csv
rmdir $TEMPDIR