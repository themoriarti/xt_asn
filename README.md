# xt_asn for IPTables

## Install
```
./configure
make
make install
```
### Generate ASN IP DB
```
./asn/xt_asn_dl
```
### Load module to kernel
```
depmod -a
modprobe xt_asn
```
## Use
```
iptables -A INPUT -p tcp -m asn --src-asn 15169 -m comment --comment 'Input from Google AS' -j ACCEPT
iptables -A OUTPU -p tcp -m asn --dst-asn 15169 -m comment --comment 'Output to Google AS' -j ACCEPT
```
### Tested on platform
Slackware 14.2 x86_64, kernel 4.4.14, iptables v1.6.0
