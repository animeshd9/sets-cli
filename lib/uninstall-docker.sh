#!/bin/bash

CONTAINER_NAME="sets-instance"
SERVICE_NAME="sets-instance"

if [ "$EUID" -ne 0 ]; then
    echo "This script needs to be run with sudo privileges."
    exit 1
fi

# Stop and remove the Docker container
docker stop "$CONTAINER_NAME" >/dev/null 2>&1
docker rm "$CONTAINER_NAME" >/dev/null 2>&1

# Remove the systemd service
systemctl stop "$SERVICE_NAME" >/dev/null 2>&1
systemctl disable "$SERVICE_NAME" >/dev/null 2>&1
rm -f "/etc/systemd/system/$SERVICE_NAME.service"

# Remove frpc and its configuration
systemctl stop frpc >/dev/null 2>&1
systemctl disable frpc >/dev/null 2>&1
rm -f /usr/bin/frpc
rm -rf /etc/frp

echo "✅ Uninstallation completed successfully."
