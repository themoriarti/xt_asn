# xt_asn for IPTables
Forked from https://github.com/themoriarti/xt_asn
Personal fix by yellowlm

## Disclaimer
I'm no professional software engineer. You shouldn't probably count on my stuff.

## Caution
If you are currently using the original version of xt_asn, you need to unload the xt_asn kernel module first (before or after installation) using `modprobe -r xt_asn`. If you install my xt_asn without doing this, you will get a `dmesg` error message `asn.1 match: invalid size 152 (kernel) != (user) 184` (which can of course be solved by `modprobe -r xt_asn` and then `modprobe xt_asn`).

## What this fork does
* Added support for 4-byte ASN (original xt_asn works only for 2-byte ASNs)
* Fixed minor typo and things on `iptables -m asn -h` 
* Reworked the way ASN data are updated - see below.
* Fixed compatibility issue with `iptables-services` (save and load rules).

## Update ASN data
The ASN data is updated in an async fashion. In my network, there is a server that processes the raw bgp data (`update-asndata.sh`) and save them into `asn.csv`. On all routers of my network that needs such data, there is a cronjob downloading (`download-asndata.sh`) the `asn.csv` from the processing server and convert the data into what xt_asn can read. The consideration for this design is that processing the raw bgp data can take up a lot time and resources. Therefore, if there are multiple places where you need to use xt_asn, it would be better to have a central server that process the bgp data once for all places.

In the ASN folder there are 2 scripts for this.

`update-asndata.sh` gets bgp data collected at 5.00 the previous day by `routeviews.org` and turn them into csv files. In order to get this work, you need to open that script and set `ASN_DATA_DIR`. This is the location where you put these csv files

`download-asndata.sh` gets the processed bgp data (`asn.csv` made by `update-asndata.sh`) and parse them into what xt_asn can read. Note, asn.csv is supposed to be downloaded from an internal http server and you need to open the script and set `ASN_DATA_URL` which is the URL to the `asn.csv` file.

## Tested on
RockyLinux 8.6 with kernel `4.18.0-372.26.1.el8_6.x86_64`

## Original README.md

### About module
Modules for firewall iptables. Designed for filtering through the autonomous system number (ASN).
The module is useful if you need to filter the traffic that comes or goes to certain service providers.
#### How it works
After installing the script, the actual database of all AS is downloaded and converted to a binary format suitable for insert to linux kernel, for each autonomous system, a separate binary file. The standalone system specified in the rules is loaded once into the kernel from binary file, which contains subnets belonging to this autonomous system. Filtered traffic that came from the AS with the help of ```--src-asn``` (```--source-asn```) and traffic that is directed to a certain autonomous system ```--dst-asn``` (```--destination-asn```). Subnets in autonomous systems do not often change, new ones can be added, in order to update the data on subnets, you need to execute a download script for the new one, but all the rules that apply to this module will need to be unloaded from the kernel and reboot the xt_asn module (```rmmod xt_asn && insmod xt_asn```) to the new then It will load new data into the kernel.

### Install
```
./configure
make
make install
```
#### Generate ASN IP DB
```
./asn/xt_asn_dl
```
#### Load module to kernel
```
depmod -a
modprobe xt_asn
```
### Use
```
iptables -A INPUT -p tcp -m asn --src-asn 15169 -m comment --comment 'Input from Google AS' -j ACCEPT
iptables -A OUTPU -p tcp -m asn --dst-asn 15169 -m comment --comment 'Output to Google AS' -j ACCEPT
```
#### Tested on platform
Slackware 14.2 x86_64, kernel 4.4.14, iptables v1.6.0
