#!/bin/bash
ASN_DATA_DIR="${ASN_DATA_DIR:-/var/lib/xt_asn}"

# Load configuration if available
if [ -f /etc/xt_asn/xt_asn.conf ]; then
    source /etc/xt_asn/xt_asn.conf
fi

# Create data directory if it doesn't exist (with sudo if needed)
if [ ! -d "$ASN_DATA_DIR" ]; then
    if [ -w "$(dirname "$ASN_DATA_DIR")" ]; then
        mkdir -p "$ASN_DATA_DIR"
    else
        echo "Creating directory $ASN_DATA_DIR (requires sudo)..."
        sudo mkdir -p "$ASN_DATA_DIR"
        sudo chown $(whoami):$(whoami) "$ASN_DATA_DIR"
    fi
fi

# Detect package manager and install dependencies
if command -v apt-get >/dev/null 2>&1; then
    # Ubuntu/Debian
    if ! command -v bgpdump >/dev/null 2>&1; then
        echo "Installing dependencies with apt-get..."
        sudo apt-get update
        sudo apt-get install -y bgpdump libnet-ip-perl libnet-netmask-perl wget
    fi
elif command -v yum >/dev/null 2>&1; then
    # CentOS/RHEL
    if ! command -v bgpdump >/dev/null 2>&1; then
        echo "Installing dependencies with yum..."
        sudo yum install -y perl-Net-IP perl-Net-Netmask bgpdump wget
    fi
elif command -v dnf >/dev/null 2>&1; then
    # Fedora/newer RHEL
    if ! command -v bgpdump >/dev/null 2>&1; then
        echo "Installing dependencies with dnf..."
        sudo dnf install -y perl-Net-IP perl-Net-Netmask bgpdump wget
    fi
else
    echo "Warning: Unknown package manager. Please install bgpdump and Perl modules manually."
fi

# Verify bgpdump is available
if ! command -v bgpdump >/dev/null 2>&1; then
    echo "Error: bgpdump not found. Please install it manually:"
    echo "  Ubuntu/Debian: sudo apt-get install bgpdump"
    echo "  CentOS/RHEL: sudo yum install bgpdump"
    echo "  Fedora: sudo dnf install bgpdump"
    exit 1
fi

TEMPDIR="`mktemp -d`"

# http://phpsuxx.blogspot.com/2011/12/full-bgp.html
yesterday_date=$(date --date='1 days ago' '+%Y.%m')
yesterday_date_with_day=$(date --date='1 days ago' '+%Y%m%d')

# Get the directory where this script is located (for bgp_table_to_text.pl)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# get ipv4 routing data for yesterday at 5 o'clock 
echo "Downloading IPv4 BGP data for ${yesterday_date_with_day}..."
wget http://archive.routeviews.org/bgpdata/${yesterday_date}/RIBS/rib.${yesterday_date_with_day}.0600.bz2 -O $TEMPDIR/rib4.bz2

echo "Start converting v4 addresses ..."
if bgpdump $TEMPDIR/rib4.bz2 | "$SCRIPT_DIR/bgp_table_to_text.pl" > $TEMPDIR/asn4.csv; then
    echo "✓ IPv4 conversion completed"
else
    echo "✗ IPv4 conversion failed"
    rm -rf "$TEMPDIR"
    exit 1
fi

# get ipv6 routing data for yesterday at 5 o'clock
echo "Downloading IPv6 BGP data for ${yesterday_date_with_day}..."
wget http://archive.routeviews.org/route-views6/bgpdata/${yesterday_date}/RIBS/rib.${yesterday_date_with_day}.0600.bz2 -O $TEMPDIR/rib6.bz2

echo "Start converting v6 addresses ..."
if bgpdump $TEMPDIR/rib6.bz2 | "$SCRIPT_DIR/bgp_table_to_text.pl" > $TEMPDIR/asn6.csv; then
    echo "✓ IPv6 conversion completed"
else
    echo "✗ IPv6 conversion failed"
    rm -rf "$TEMPDIR"
    exit 1
fi

# Copy files to destination (with proper permissions)
echo "Copying ASN data to $ASN_DATA_DIR..."
if cp -f $TEMPDIR/asn4.csv $ASN_DATA_DIR/asn4.csv && \
   cp -f $TEMPDIR/asn6.csv $ASN_DATA_DIR/asn6.csv; then
    # Combine IPv4 and IPv6 data
    cat $TEMPDIR/asn4.csv $TEMPDIR/asn6.csv > $ASN_DATA_DIR/asn.csv
    echo "✓ ASN data files created successfully"
    
    # Show statistics
    echo "Statistics:"
    echo "  IPv4 entries: $(wc -l < $ASN_DATA_DIR/asn4.csv)"
    echo "  IPv6 entries: $(wc -l < $ASN_DATA_DIR/asn6.csv)"
    echo "  Total entries: $(wc -l < $ASN_DATA_DIR/asn.csv)"
else
    echo "✗ Failed to copy ASN data files"
    rm -rf "$TEMPDIR"
    exit 1
fi

rm -f $TEMPDIR/*.bz2
rm -f $TEMPDIR/*.csv
rmdir $TEMPDIR