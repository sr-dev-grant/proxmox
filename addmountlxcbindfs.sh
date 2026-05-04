#!/bin/bash

# --- Configuration ---
CT_ID="100"
REAL_RAID="/mnt/raidarr"          # Actual path on host
VIRTUAL_RAID="/mnt/lxc_raid_${CT_ID}"  # Virtual path with remapped IDs
LXC_DIR="/mnt/raidarr"            # Inside the LXC
MAPPING_ID="101000"
CONF_FILE="/etc/pve/lxc/${CT_ID}.conf"

# 1. Install bindfs if missing
if ! command -v bindfs &> /dev/null; then
    apt-get update && apt-get install -y bindfs
fi

# 2. Create the virtual mount point on host
mkdir -p "$VIRTUAL_RAID"

# 3. Mount with remapped permissions (Host remains untouched)
# This makes everything in REAL_RAID look like it's owned by 101000 inside VIRTUAL_RAID
bindfs --map=root/root:@101000/@101000 "$REAL_RAID" "$VIRTUAL_RAID"

# 4. Add the VIRTUAL path to the LXC config
if ! grep -q "$VIRTUAL_RAID" "$CONF_FILE"; then
    echo "mp0: $VIRTUAL_RAID,mp=$LXC_DIR" >> "$CONF_FILE"
    echo "Added mount point to $CONF_FILE"
fi
