#!/bin/bash
ASN_DATA_URL="${ASN_DATA_URL:-http://127.0.0.1/asn.csv}"

# Load configuration if available
if [ -f /etc/xt_asn/xt_asn.conf ]; then
    source /etc/xt_asn/xt_asn.conf
fi

# Ensure we have a valid URL
if [ "$ASN_DATA_URL" = "http://127.0.0.1/asn.csv" ]; then
    echo "Warning: Using default URL. Please configure ASN_DATA_URL in /etc/xt_asn/xt_asn.conf"
    echo "Set ASN_DATA_URL to point to your ASN data server."
    echo
    echo "Alternatively, you can run update-asndata.sh to process BGP data locally."
    exit 1
fi

# Detect package manager and install dependencies
if command -v apt-get >/dev/null 2>&1; then
    # Ubuntu/Debian
    echo "Installing dependencies with apt-get..."
    sudo apt-get update >/dev/null 2>&1
    sudo apt-get install -y libtext-csv-xs-perl libnet-ip-perl libnet-netmask-perl wget >/dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    # CentOS/RHEL
    echo "Installing dependencies with yum..."
    sudo yum install -y perl-Text-CSV_XS perl-Getopt-Long perl-IO wget >/dev/null 2>&1
elif command -v dnf >/dev/null 2>&1; then
    # Fedora/newer RHEL
    echo "Installing dependencies with dnf..."
    sudo dnf install -y perl-Text-CSV_XS perl-Getopt-Long perl-IO wget >/dev/null 2>&1
else
    echo "Warning: Unknown package manager. Please install Perl modules manually."
fi

TEMPDIR="`mktemp -d`"

# Get the directory where this script is located (for xt_asn_build)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create xt_asn directory with proper permissions
if [ ! -d /usr/share/xt_asn ]; then
    echo "Creating /usr/share/xt_asn directory..."
    if sudo mkdir -p /usr/share/xt_asn/{BE,LE}; then
        echo "✓ Directory created successfully"
    else
        echo "✗ Failed to create directory"
        exit 1
    fi
fi

# Download ASN data
echo "Downloading ASN data from $ASN_DATA_URL..."
if wget "$ASN_DATA_URL" -O "$TEMPDIR/asn.csv"; then
    echo "✓ Download completed"
    
    # Check if file has content
    if [ ! -s "$TEMPDIR/asn.csv" ]; then
        echo "✗ Downloaded file is empty"
        rm -rf "$TEMPDIR"
        exit 1
    fi
    
    echo "Processing ASN data..."
    if perl "$SCRIPT_DIR/xt_asn_build" -D /usr/share/xt_asn "$TEMPDIR/asn.csv"; then
        echo "✓ ASN database created successfully"
        
        # Show statistics
        echo "Database statistics:"
        echo "  IPv4 files: $(find /usr/share/xt_asn -name "*.iv4" | wc -l)"
        echo "  IPv6 files: $(find /usr/share/xt_asn -name "*.iv6" | wc -l)"
        echo "  Total size: $(du -sh /usr/share/xt_asn | cut -f1)"
    else
        echo "✗ Failed to process ASN data"
        rm -rf "$TEMPDIR"
        exit 1
    fi
else
    echo "✗ Failed to download ASN data"
    rm -rf "$TEMPDIR"
    exit 1
fi

# Clean up
rm -f $TEMPDIR/*.csv
rmdir $TEMPDIR

echo "✓ ASN database update completed successfully"