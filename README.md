# xt_asn for IPTables

## About module
Modules for firewall iptables. Designed for filtering through the autonomous system number (ASN).
The module is useful if you need to filter the traffic that comes or goes to certain service providers.
### How it works
After installing the script, the actual database of all AS is downloaded and converted to a binary format suitable for insert to linux kernel, for each autonomous system, a separate binary file. The standalone system specified in the rules is loaded once into the kernel from binary file, which contains subnets belonging to this autonomous system. Filtered traffic that came from the AS with the help of ```--src-asn``` (```--source-asn```) and traffic that is directed to a certain autonomous system ```--dst-asn``` (```--destination-asn```). Subnets in autonomous systems do not often change, new ones can be added, in order to update the data on subnets, you need to execute a download script for the new one, but all the rules that apply to this module will need to be unloaded from the kernel and reboot the xt_asn module (```rmmod xt_asn && insmod xt_asn```) to the new then It will load new data into the kernel.

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
