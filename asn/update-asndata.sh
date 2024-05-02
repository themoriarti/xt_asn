#!/bin/sh
ASN_DATA_DIR="~"

echo "You need to set ASN_DATA_DIR in this script first and remove Lines 4 and 5" 
exit

yum -y install perl-Net-IP perl-Net-Netmask bgpdump wget

TEMPDIR="`mktemp -d`"

# http://phpsuxx.blogspot.com/2011/12/full-bgp.html
yesterday_date=$(date --date='1 days ago' '+%Y.%m')
yesterday_date_with_day=$(date --date='1 days ago' '+%Y%m%d')

# get ipv4 routing data for yesterday at 5 o'clock 
wget http://archive.routeviews.org/bgpdata/${yesterday_date}/RIBS/rib.${yesterday_date_with_day}.0600.bz2 -O $TEMPDIR/rib4.bz2
echo "Start converting v4 addresses ..."
/usr/bin/bgpdump $TEMPDIR/rib4.bz2 | ./bgp_table_to_text.pl > $TEMPDIR/asn4.csv

# get ipv6 routing data for yesterday at 5 o'clock
wget http://archive.routeviews.org/route-views6/bgpdata/${yesterday_date}/RIBS/rib.${yesterday_date_with_day}.0600.bz2 -O $TEMPDIR/rib6.bz2
echo "Start converting v6 addresses ..."
/usr/bin/bgpdump $TEMPDIR/rib6.bz2 | ./bgp_table_to_text.pl > $TEMPDIR/asn6.csv

/bin/cp -f $TEMPDIR/asn4.csv $ASN_DATA_DIR/asn4.csv
/bin/cp -f $TEMPDIR/asn6.csv $ASN_DATA_DIR/asn6.csv
cat $TEMPDIR/asn4.csv $TEMPDIR/asn6.csv > $ASN_DATA_DIR/asn.csv

rm -f $TEMPDIR/*.bz2
rm -f $TEMPDIR/*.csv
rmdir $TEMPDIR