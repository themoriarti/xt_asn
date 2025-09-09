# Installation Guide for xt_asn

This document provides detailed installation instructions for the xt_asn iptables module on various Linux distributions.

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Ubuntu/Debian Installation](#ubuntudebian-installation)
3. [CentOS/RHEL Installation](#centosrhel-installation)
4. [Arch Linux Installation](#arch-linux-installation)
5. [Manual Compilation](#manual-compilation)
6. [Post-Installation Setup](#post-installation-setup)
7. [Troubleshooting](#troubleshooting)

## System Requirements

### Minimum Requirements
- Linux kernel 3.7 or higher
- 512MB RAM
- 100MB free disk space
- Root or sudo access

### Supported Architectures
- x86_64 (primary)
- i386
- ARM64 (experimental)

### Supported Distributions
- Ubuntu 18.04+ LTS
- Debian 9+ (Stretch)
- CentOS 7+
- RHEL 7+
- Fedora 28+
- Arch Linux
- openSUSE Leap 15+

## Ubuntu/Debian Installation

### Method 1: Package Installation (Recommended)

```bash
# Add repository (if available)
curl -fsSL https://repo.example.com/gpg | sudo apt-key add -
echo "deb https://repo.example.com/ubuntu $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/xt-asn.list

# Update package list
sudo apt update

# Install xt_asn
sudo apt install xt-asn
```

### Method 2: Manual Build

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install build dependencies
sudo apt install -y \
    build-essential \
    linux-headers-$(uname -r) \
    iptables-dev \
    autotools-dev \
    autoconf \
    automake \
    libtool \
    pkg-config \
    git

# Install runtime dependencies
sudo apt install -y \
    bgpdump \
    libtext-csv-xs-perl \
    libnet-ip-perl \
    libnet-netmask-perl \
    wget \
    curl

# Clone repository
git clone https://github.com/username/xt_asn.git
cd xt_asn

# Build and install
./autogen.sh
./configure
make -j$(nproc)
sudo make install

# Load module
sudo depmod -a
sudo modprobe xt_asn
```

### Ubuntu 20.04 LTS Specific Notes

```bash
# Additional packages for Ubuntu 20.04
sudo apt install -y linux-headers-generic

# Verify kernel headers
ls /usr/src/linux-headers-$(uname -r)/
```

### Ubuntu 22.04 LTS Specific Notes

```bash
# For newer Ubuntu versions, ensure compatibility
sudo apt install -y dkms

# Build with DKMS support
sudo dkms add .
sudo dkms build xt_asn/2.1.0
sudo dkms install xt_asn/2.1.0
```

## CentOS/RHEL Installation

### CentOS 7

```bash
# Install EPEL repository
sudo yum install -y epel-release

# Install development tools
sudo yum groupinstall -y "Development Tools"
sudo yum install -y kernel-devel kernel-headers

# Install dependencies
sudo yum install -y \
    iptables-devel \
    autoconf \
    automake \
    libtool \
    bgpdump \
    perl-Net-IP \
    perl-Net-Netmask \
    perl-Text-CSV_XS

# Build and install
git clone https://github.com/username/xt_asn.git
cd xt_asn
./autogen.sh
./configure
make -j$(nproc)
sudo make install

# Load module
sudo depmod -a
sudo modprobe xt_asn

# Enable on boot
echo "xt_asn" | sudo tee /etc/modules-load.d/xt_asn.conf
```

### CentOS 8/RHEL 8

```bash
# Enable PowerTools repository
sudo dnf config-manager --set-enabled powertools

# Install development tools
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y kernel-devel kernel-headers

# Install dependencies
sudo dnf install -y \
    iptables-devel \
    autoconf \
    automake \
    libtool \
    bgpdump \
    perl-Net-IP \
    perl-Net-Netmask \
    perl-Text-CSV_XS

# Continue with build process...
```

### Rocky Linux 8.6

```bash
# This is the tested configuration from the original README
sudo dnf install -y \
    gcc \
    kernel-devel-$(uname -r) \
    kernel-headers-$(uname -r) \
    iptables-devel \
    autoconf \
    automake \
    libtool \
    make

# Install Perl dependencies
sudo dnf install -y \
    perl-Net-IP \
    perl-Net-Netmask \
    bgpdump \
    wget

# Build as shown above
```

## Arch Linux Installation

### Using AUR (Recommended)

```bash
# Install AUR helper (if not already installed)
sudo pacman -S base-devel git

# Install from AUR
yay -S xt-asn-git
# or
trizen -S xt-asn-git
```

### Manual Build

```bash
# Install dependencies
sudo pacman -S \
    base-devel \
    linux-headers \
    iptables \
    autoconf \
    automake \
    libtool \
    bgpdump \
    perl-net-ip \
    perl-text-csv_xs

# Build and install
git clone https://github.com/username/xt_asn.git
cd xt_asn
./autogen.sh
./configure
make -j$(nproc)
sudo make install

# Load module
sudo depmod -a
sudo modprobe xt_asn
```

## Manual Compilation

### Advanced Configuration Options

```bash
# Configure with custom options
./configure \
    --prefix=/usr/local \
    --with-kbuild=/lib/modules/$(uname -r)/build \
    --with-xtlibdir=/usr/local/lib/xtables \
    --enable-debug

# Available configure options
./configure --help
```

### Cross-Compilation

```bash
# For ARM64 targets
./configure \
    --host=aarch64-linux-gnu \
    --with-kbuild=/path/to/target/kernel/build \
    CC=aarch64-linux-gnu-gcc

make -j$(nproc)
```

### Building without Kernel Module

```bash
# Build only userspace components
./configure --without-kbuild
make
```

## Post-Installation Setup

### 1. Verify Installation

```bash
# Check if module is loaded
lsmod | grep xt_asn

# Test iptables integration
iptables -m asn --help

# Check installed files
ls -la /usr/lib*/xtables/libxt_asn.so
ls -la /lib/modules/$(uname -r)/extra/xt_asn.ko
```

### 2. Configure ASN Data Sources

```bash
# Create configuration directory
sudo mkdir -p /etc/xt_asn

# Edit update script
sudo cp asn/update-asndata.sh /usr/local/bin/
sudo cp asn/download-asndata.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/*asndata.sh

# Configure paths
sudo sed -i 's|ASN_DATA_DIR="~"|ASN_DATA_DIR="/var/lib/xt_asn"|' /usr/local/bin/update-asndata.sh
sudo sed -i 's|ASN_DATA_URL="http://127.0.0.1/asn.csv"|ASN_DATA_URL="http://your-server.com/asn.csv"|' /usr/local/bin/download-asndata.sh

# Remove safety exits
sudo sed -i '/echo "You need to set/,+1d' /usr/local/bin/update-asndata.sh
sudo sed -i '/echo "You need to set/,+1d' /usr/local/bin/download-asndata.sh
```

### 3. Generate Initial Database

```bash
# Create database directory
sudo mkdir -p /usr/share/xt_asn/{BE,LE}

# Download and process initial data
sudo /usr/local/bin/download-asndata.sh
```

### 4. Setup Automatic Updates

```bash
# Add cron job for daily updates
echo "0 6 * * * /usr/local/bin/download-asndata.sh" | sudo crontab -

# Or use systemd timer
sudo tee /etc/systemd/system/xt-asn-update.service <<EOF
[Unit]
Description=Update xt_asn ASN database
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/download-asndata.sh
User=root
EOF

sudo tee /etc/systemd/system/xt-asn-update.timer <<EOF
[Unit]
Description=Daily xt_asn database update
Requires=xt-asn-update.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl enable xt-asn-update.timer
sudo systemctl start xt-asn-update.timer
```

### 5. Enable Module on Boot

```bash
# Method 1: modules-load.d
echo "xt_asn" | sudo tee /etc/modules-load.d/xt_asn.conf

# Method 2: /etc/modules (Debian/Ubuntu)
echo "xt_asn" | sudo tee -a /etc/modules

# Method 3: rc.local
echo "modprobe xt_asn" | sudo tee -a /etc/rc.local
sudo chmod +x /etc/rc.local
```

## Troubleshooting

### Module Won't Load

**Error: Module not found**
```bash
# Check if module was installed
find /lib/modules/$(uname -r) -name "xt_asn*"

# Rebuild module index
sudo depmod -a

# Check for conflicts
lsmod | grep -i asn
```

**Error: Version magic mismatch**
```bash
# Rebuild against current kernel
make clean
./configure --with-kbuild=/lib/modules/$(uname -r)/build
make
sudo make install
sudo depmod -a
```

### Compilation Errors

**Error: kernel headers not found**
```bash
# Ubuntu/Debian
sudo apt install linux-headers-$(uname -r)

# CentOS/RHEL
sudo yum install kernel-devel-$(uname -r)

# Verify installation
ls /lib/modules/$(uname -r)/build
```

**Error: xtables.h not found**
```bash
# Ubuntu/Debian
sudo apt install iptables-dev

# CentOS/RHEL
sudo yum install iptables-devel
```

### Runtime Issues

**Error: Cannot read ASN database**
```bash
# Check database directory
ls -la /usr/share/xt_asn/

# Check permissions
sudo chown -R root:root /usr/share/xt_asn/
sudo chmod -R 644 /usr/share/xt_asn/*

# Regenerate database
sudo /usr/local/bin/download-asndata.sh
```

**Error: Size mismatch**
```bash
# Unload and reload module
sudo rmmod xt_asn
sudo modprobe xt_asn

# If persistent, rebuild module
cd /path/to/xt_asn/source
make clean && make && sudo make install
sudo depmod -a
sudo modprobe xt_asn
```

### Performance Issues

**High CPU usage**
```bash
# Check database size
du -sh /usr/share/xt_asn/

# Monitor module performance
cat /proc/modules | grep xt_asn
```

### Getting Help

If you encounter issues not covered here:

1. Check the [GitHub Issues](https://github.com/username/xt_asn/issues)
2. Run diagnostics:
   ```bash
   # Collect system information
   uname -a
   lsb_release -a
   iptables --version
   lsmod | grep xt_asn
   dmesg | grep -i asn
   ```
3. Create a new issue with the diagnostic information

## Security Considerations

### File Permissions

```bash
# Secure installation directories
sudo chmod 755 /usr/share/xt_asn
sudo chmod 644 /usr/share/xt_asn/*/*
sudo chmod 755 /usr/local/bin/*asndata.sh
```

### Network Security

- Use HTTPS for ASN data downloads
- Verify data integrity with checksums
- Implement proper firewall rules during updates

### System Security

- Run updates with minimal privileges
- Monitor log files for suspicious activity
- Regular security updates for dependencies

---

This installation guide should cover most common scenarios. For specific deployment requirements or enterprise setups, please consult the project documentation or contact the maintainers.
