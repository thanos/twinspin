#!/bin/bash
# IBM DB2 ODBC Driver Installation Script
# This script downloads and installs IBM DB2 client libraries
# Required for ODBC connections to DB2 databases

set -e

echo "========================================="
echo "IBM DB2 ODBC Driver Installation"
echo "========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
   echo "ERROR: This script must be run as root"
   exit 1
fi

# Configuration
DB2_VERSION="11.5.8.0"
DB2_CLIENT_URL="https://public.dhe.ibm.com/ibmdl/export/pub/software/data/db2/drivers/odbc_cli"
INSTALL_DIR="/opt/ibm/db2/clidriver"

echo "Installing IBM DB2 ODBC driver version ${DB2_VERSION}..."
echo "Installation directory: ${INSTALL_DIR}"

# Install dependencies
echo "Installing dependencies..."
apk add --no-cache \
    curl \
    tar \
    gzip \
    libc6-compat \
    libstdc++ \
    ncurses-libs

# Create installation directory
echo "Creating installation directory..."
mkdir -p ${INSTALL_DIR}

# Download DB2 client (you'll need to provide the actual download URL)
# IBM requires registration, so users must download manually
echo ""
echo "========================================="
echo "MANUAL DOWNLOAD REQUIRED"
echo "========================================="
echo "Due to IBM licensing, you must manually download the DB2 client:"
echo ""
echo "1. Visit: https://www.ibm.com/support/pages/download-initial-version-115-clients-and-drivers"
echo "2. Download: IBM Data Server Driver Package (Linux AMD64)"
echo "3. Place the file in: docker/drivers/ibm_data_server_driver_package_linuxx64_v11.5.tar.gz"
echo ""
read -p "Press Enter once you've placed the file in docker/drivers/..."

# Extract DB2 client
DRIVER_FILE="docker/drivers/ibm_data_server_driver_package_linuxx64_v11.5.tar.gz"

if [ ! -f "${DRIVER_FILE}" ]; then
    echo "ERROR: Driver file not found at ${DRIVER_FILE}"
    exit 1
fi

echo "Extracting DB2 client..."
tar -xzf "${DRIVER_FILE}" -C /opt/ibm/

# Set up environment
echo "Setting up environment variables..."
cat >> /etc/profile.d/db2.sh <<EOF
export DB2_HOME=${INSTALL_DIR}
export PATH=\${DB2_HOME}/bin:\${PATH}
export LD_LIBRARY_PATH=\${DB2_HOME}/lib:\${LD_LIBRARY_PATH}
EOF

# Source environment
source /etc/profile.d/db2.sh

# Update ODBC configuration to point to DB2 driver
echo "Updating ODBC configuration..."
echo "" >> /etc/odbcinst.ini
echo "[IBM DB2 ODBC DRIVER]" >> /etc/odbcinst.ini
echo "Description     = IBM DB2 ODBC Driver" >> /etc/odbcinst.ini
echo "Driver          = ${INSTALL_DIR}/lib/libdb2o.so" >> /etc/odbcinst.ini
echo "FileUsage       = 1" >> /etc/odbcinst.ini
echo "DontDLClose     = 1" >> /etc/odbcinst.ini

echo ""
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo "DB2 ODBC driver installed at: ${INSTALL_DIR}"
echo "You can now configure DB2 data sources in /app/odbc/odbc.ini"
echo ""
echo "Verify installation with:"
echo "  odbcinst -q -d"
