#!/bin/bash

# --- Configuration ---
CT_ID="100"                   # The ID of your LXC container
HOST_DIR="/mnt/raidarr"       # The source path on the Proxmox host
LXC_DIR="/mnt/raidarr"        # The mount point inside the LXC
MAPPING_ID="101000"           # Host UID for container user 1000
CONF_FILE="/etc/pve/lxc/${CT_ID}.conf"

echo "### Starting Mount Point Setup for LXC ${CT_ID} ###"

# 1. Create the directory on the host if it doesn't exist
if [ ! -d "$HOST_DIR" ]; then
    echo "[+] Creating host directory: $HOST_DIR"
    mkdir -p "$HOST_DIR"
else
    echo "[!] Host directory $HOST_DIR already exists."
fi

# 2. Set ownership for the container user (UID 101000)
echo "[+] Setting ownership to $MAPPING_ID:$MAPPING_ID on $HOST_DIR"
chown -R "$MAPPING_ID":"$MAPPING_ID" "$HOST_DIR"

# 3. Check if the LXC config exists
if [ ! -f "$CONF_FILE" ]; then
    echo "[ERROR] Configuration file for LXC ${CT_ID} not found at $CONF_FILE"
    exit 1
fi

# 4. Add the mount point to the config if not already present
if grep -q "$HOST_DIR" "$CONF_FILE"; then
    echo "[!] Mount point already exists in $CONF_FILE. Skipping config update."
else
    # Find the next available mp number (mp0, mp1, etc.)
    NEXT_MP=$(grep -o 'mp[0-9]\+:' "$CONF_FILE" | cut -d'p' -f2 | cut -d':' -f1 | sort -rn | head -n1)
    
    # If no mp exists, start at 0, otherwise increment
    if [ -z "$NEXT_MP" ]; then
        MP_INDEX=0
    else
        MP_INDEX=$((NEXT_MP + 1))
    fi

    echo "[+] Adding mp${MP_INDEX} to $CONF_FILE"
    echo "mp${MP_INDEX}: ${HOST_DIR},mp=${LXC_DIR}" >> "$CONF_FILE"
fi

echo "### Setup Complete ###"
echo "Please restart LXC ${CT_ID} to apply changes."
