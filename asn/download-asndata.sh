#!/bin/sh
ASN_DATA_URL="http://127.0.0.1/asn.csv" # You want the URL to "asn.csv" made by update-asndata.sh

echo "You need to set ASN_DATA_DIR in this script first and remove Lines 4 and 5" 
exit

yum -y install perl-Text-CSV_XS perl-Getopt-Long perl-IO

TEMPDIR="`mktemp -d`"

mkdir /usr/share/xt_asn
wget $ASN_DATA_URL -O $TEMPDIR/asn.csv
./xt_asn_build -D /usr/share/xt_asn $TEMPDIR/asn.csv
rm -f $TEMPDIR/*.csv
rmdir $TEMPDIR