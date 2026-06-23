#!/bin/bash
set -e

# ============================================================================
# TraffMonetizer One-Click Installer for Linux
# Usage: bash install.sh --token YOUR_TOKEN --device DEVICE_NAME
# ============================================================================

TOKEN=""
DEVICE_NAME=""
INSTALL_DIR="/usr/local/bin"
SERVICE_FILE="/etc/systemd/system/traffmonetizer.service"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64)
        ASSET_NAME="traffmonetizer"
        ;;
    aarch64|arm64)
        ASSET_NAME="traffmonetizer_linux_arm64"
        ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        echo "Supported: x86_64/amd64, aarch64/arm64"
        exit 1
        ;;
esac

GITHUB_BASE="https://github.com/XTBANNY/tm-installer/releases/latest/download"
BINARY_URL="${GITHUB_BASE}/${ASSET_NAME}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --token)
            TOKEN="$2"
            shift 2
            ;;
        --device)
            DEVICE_NAME="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: bash install.sh --token YOUR_TOKEN --device DEVICE_NAME"
            echo ""
            echo "Options:"
            echo "  --token    Your TraffMonetizer token (required)"
            echo "  --device   Device name displayed on dashboard (required)"
            echo "  -h         Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate inputs
if [[ -z "$TOKEN" || -z "$DEVICE_NAME" ]]; then
    echo "ERROR: --token and --device are required."
    echo "Usage: bash install.sh --token YOUR_TOKEN --device DEVICE_NAME"
    exit 1
fi

echo "========================================="
echo " TraffMonetizer One-Click Installer"
echo "========================================="

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root (sudo)."
    exit 1
fi

# Verify architecture is supported
if [[ "$ARCH" != "x86_64" && "$ARCH" != "amd64" && "$ARCH" != "aarch64" && "$ARCH" != "arm64" ]]; then
    echo "ERROR: Unsupported architecture: $ARCH"
    echo "Supported: x86_64, amd64, aarch64, arm64"
    exit 1
fi

echo "Detected architecture: $ARCH ($ASSET_NAME)"

# Check if already installed
if [[ -f "$INSTALL_DIR/traffmonetizer" ]]; then
    echo "INFO: traffmonetizer binary already installed. Updating..."
    OLD_PID=$(pgrep -f traffmonetizer 2>/dev/null || true)
    STOPPED=false
fi

# Download binary
echo "[1/4] Downloading binary..."
TMPDIR=$(mktemp -d)
curl -sSL -f -o "$TMPDIR/$ASSET_NAME" "$BINARY_URL"

if [[ ! -f "$TMPDIR/$ASSET_NAME" ]] || [[ ! -x "$TMPDIR/$ASSET_NAME" ]]; then
    echo "ERROR: Download failed. Please check your network connection and try again."
    echo "You can also download manually from:"
    echo "  https://github.com/XTBANNY/tm-installer/releases"
    rm -rf "$TMPDIR"
    exit 1
fi

FILE_SIZE=$(stat -c%s "$TMPDIR/$ASSET_NAME" 2>/dev/null || echo 0)
if [[ "$FILE_SIZE" -lt 1000000 ]]; then
    echo "ERROR: Downloaded file is too small (${FILE_SIZE} bytes). Download may have failed."
    rm -rf "$TMPDIR"
    exit 1
fi

echo "  Downloaded: $(du -h "$TMPDIR/$ASSET_NAME" | cut -f1)"

# Install binary
echo "[2/4] Installing binary..."
chmod +x "$TMPDIR/$ASSET_NAME"
mv "$TMPDIR/$ASSET_NAME" "$INSTALL_DIR/traffmonetizer"
rm -rf "$TMPDIR"

# Create systemd service
echo "[3/4] Creating systemd service..."
cat > "$SERVICE_FILE" << SERVICE_EOF
[Unit]
Description=TraffMonetizer Traffic Sharing Client
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=${INSTALL_DIR}/traffmonetizer start accept --token ${TOKEN} --device-name ${DEVICE_NAME}
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE_EOF

# Enable and start service
echo "[4/4] Starting service..."
systemctl daemon-reload
systemctl enable traffmonetizer.service

# Stop old process if exists
if [[ -n "$OLD_PID" ]]; then
    kill "$OLD_PID" 2>/dev/null || true
    sleep 2
fi

systemctl start traffmonetizer.service
sleep 2

# Check status
if systemctl is-active --quiet traffmonetizer.service; then
    echo ""
    echo "========================================="
    echo " Installation Successful!"
    echo "========================================="
    echo ""
    echo " Service:    traffmonetizer.service"
    echo " Binary:     $INSTALL_DIR/traffmonetizer"
    echo " Token:      ${TOKEN:0:8}****"
    echo " Device:     $DEVICE_NAME"
    echo ""
    echo " View logs:  journalctl -u traffmonetizer -f"
    echo " Status:     systemctl status traffmonetizer"
    echo ""
    echo " To uninstall:"
    echo "   systemctl stop traffmonetizer"
    echo "   systemctl disable traffmonetizer"
    echo "   rm -f $INSTALL_DIR/traffmonetizer /etc/systemd/system/traffmonetizer.service"
    echo "   systemctl daemon-reload"
    echo ""
else
    echo "ERROR: Service failed to start. Check logs:"
    echo "  journalctl -u traffmonetizer -n 50 --no-pager"
    exit 1
fi
