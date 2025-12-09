#!/bin/bash
# Oracle Instant Client ODBC Driver Installation Script
# This script downloads and installs Oracle Instant Client libraries
# Required for ODBC connections to Oracle databases

set -e

echo "========================================="
echo "Oracle Instant Client Installation"
echo "========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
   echo "ERROR: This script must be run as root"
   exit 1
fi

# Configuration
ORACLE_VERSION="19.3"
ORACLE_RELEASE="19.3.0.0.0"
INSTALL_DIR="/usr/lib/oracle/${ORACLE_VERSION}/client64"
LIB_DIR="${INSTALL_DIR}/lib"

echo "Installing Oracle Instant Client version ${ORACLE_VERSION}..."
echo "Installation directory: ${INSTALL_DIR}"

# Install dependencies
echo "Installing dependencies..."
apk add --no-cache \
    curl \
    unzip \
    libaio \
    libaio-dev \
    libnsl \
    libc6-compat

# Create installation directory
echo "Creating installation directory..."
mkdir -p ${LIB_DIR}

# Download Oracle Instant Client (you'll need to provide the actual files)
# Oracle requires registration, so users must download manually
echo ""
echo "========================================="
echo "MANUAL DOWNLOAD REQUIRED"
echo "========================================="
echo "Due to Oracle licensing, you must manually download Oracle Instant Client:"
echo ""
echo "1. Visit: https://www.oracle.com/database/technologies/instant-client/linux-x86-64-downloads.html"
echo "2. Download the following for version ${ORACLE_VERSION}:"
echo "   - instantclient-basic-linux.x64-${ORACLE_RELEASE}dbru.zip"
echo "   - instantclient-odbc-linux.x64-${ORACLE_RELEASE}dbru.zip"
echo "   - instantclient-sqlplus-linux.x64-${ORACLE_RELEASE}dbru.zip (optional)"
echo "3. Place the files in: docker/drivers/"
echo ""
read -p "Press Enter once you've placed the files in docker/drivers/..."

# Extract Oracle Instant Client
BASIC_FILE="docker/drivers/instantclient-basic-linux.x64-${ORACLE_RELEASE}dbru.zip"
ODBC_FILE="docker/drivers/instantclient-odbc-linux.x64-${ORACLE_RELEASE}dbru.zip"

if [ ! -f "${BASIC_FILE}" ]; then
    echo "ERROR: Basic client file not found at ${BASIC_FILE}"
    exit 1
fi

if [ ! -f "${ODBC_FILE}" ]; then
    echo "ERROR: ODBC driver file not found at ${ODBC_FILE}"
    exit 1
fi

echo "Extracting Oracle Instant Client..."
unzip -o "${BASIC_FILE}" -d /usr/lib/oracle/
unzip -o "${ODBC_FILE}" -d /usr/lib/oracle/

# Move extracted files to proper location
mv /usr/lib/oracle/instantclient_* ${INSTALL_DIR}/

# Set up environment
echo "Setting up environment variables..."
cat >> /etc/profile.d/oracle.sh <<EOF
export ORACLE_HOME=${INSTALL_DIR}
export LD_LIBRARY_PATH=${LIB_DIR}:\${LD_LIBRARY_PATH}
export PATH=${INSTALL_DIR}:\${PATH}
export TNS_ADMIN=${INSTALL_DIR}/network/admin
EOF

# Source environment
source /etc/profile.d/oracle.sh

# Create symbolic links for ODBC
echo "Creating symbolic links..."
cd ${LIB_DIR}
ln -sf libclntsh.so.19.1 libclntsh.so
ln -sf libocci.so.19.1 libocci.so

# Update ODBC configuration to point to Oracle driver
echo "Updating ODBC configuration..."
echo "" >> /etc/odbcinst.ini
echo "[Oracle 19 ODBC driver]" >> /etc/odbcinst.ini
echo "Description     = Oracle ODBC driver for Oracle 19" >> /etc/odbcinst.ini
echo "Driver          = ${LIB_DIR}/libsqora.so.19.1" >> /etc/odbcinst.ini
echo "Setup           = " >> /etc/odbcinst.ini
echo "FileUsage       = 1" >> /etc/odbcinst.ini
echo "CPTimeout       = " >> /etc/odbcinst.ini
echo "CPReuse         = " >> /etc/odbcinst.ini

echo ""
echo "========================================="
echo "Installation Complete!"
echo "========================================="
echo "Oracle Instant Client installed at: ${INSTALL_DIR}"
echo "You can now configure Oracle data sources in /app/odbc/odbc.ini"
echo ""
echo "Verify installation with:"
echo "  odbcinst -q -d"
echo ""
echo "Test connection with:"
echo "  sqlplus username/password@hostname:1521/service_name"

