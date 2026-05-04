#!/bin/bash

# --- Configuration ---
CT_ID="100"
REAL_RAID="/mnt/raidarr"                 # Actual path on host
VIRTUAL_RAID="/mnt/lxc_raid_${CT_ID}"     # Dynamic virtual path
LXC_DIR="/mnt/raidarr"                   # Destination inside the LXC
MAPPING_ID="101000"                      # Host UID (offset 100k + internal 1k)
CONF_FILE="/etc/pve/lxc/${CT_ID}.conf"

echo "### Starting Setup for LXC ${CT_ID} ###"

# 1. Install bindfs if missing
if ! command -v bindfs &> /dev/null; then
    echo "[+] Installing bindfs..."
    apt-get update && apt-get install -y bindfs
fi

# 2. Create the virtual mount point on host
if [ ! -d "$VIRTUAL_RAID" ]; then
    echo "[+] Creating virtual mount directory: $VIRTUAL_RAID"
    mkdir -p "$VIRTUAL_RAID"
fi

# 3. Mount with remapped permissions
if mountpoint -q "$VIRTUAL_RAID"; then
    echo "[!] $VIRTUAL_RAID is already mounted. Remounting to ensure settings..."
    umount "$VIRTUAL_RAID"
fi

echo "[+] Mounting $REAL_RAID to $VIRTUAL_RAID with UID $MAPPING_ID"
bindfs -u "$MAPPING_ID" \
       -g "$MAPPING_ID" \
       --create-for-user="$MAPPING_ID" \
       --create-for-group="$MAPPING_ID" \
       -o allow_other \
       "$REAL_RAID" "$VIRTUAL_RAID"

# 4. Add the VIRTUAL path to the LXC config
if [ ! -f "$CONF_FILE" ]; then
    echo "[ERROR] LXC config $CONF_FILE not found! Is the ID correct?"
    exit 1
fi

if grep -q "mp=.*$LXC_DIR" "$CONF_FILE"; then
    echo "[!] Mount point $LXC_DIR already exists in LXC config. Skipping."
else
    # Automatically find the next available mp number
    NEXT_MP=$(grep -o 'mp[0-9]\+:' "$CONF_FILE" | cut -d'p' -f2 | cut -d':' -f1 | sort -rn | head -n1)
    MP_INDEX=$(( ${NEXT_MP:- -1} + 1 ))
    
    echo "[+] Adding mp${MP_INDEX} to $CONF_FILE"
    echo "mp${MP_INDEX}: ${VIRTUAL_RAID},mp=${LXC_DIR}" >> "$CONF_FILE"
fi

# 5. Make bindfs sticky in /etc/fstab
FSTAB_ENTRY="${REAL_RAID} ${VIRTUAL_RAID} fuse.bindfs force-user=${MAPPING_ID},force-group=${MAPPING_ID},create-for-user=${MAPPING_ID},allow_other 0 0"

if grep -q "$VIRTUAL_RAID" /etc/fstab; then
    echo "[!] Fstab entry for $VIRTUAL_RAID already exists. Skipping."
else
    echo "[+] Adding entry to /etc/fstab"
    echo "$FSTAB_ENTRY" >> /etc/fstab
fi

echo "### Success! ###"
echo "1. Verify host view: ls -la $VIRTUAL_RAID"
echo "2. Restart container: pct stop $CT_ID && pct start $CT_ID"
