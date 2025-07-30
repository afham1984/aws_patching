#!/bin/bash

# Exit on any error
set -e

# Constants
NOW=$(date +"%Y-%m-%d_%H%M")
DATE=$(date +%Y-%m-%d)
LOG_FILE="patch_snapshot_${NOW}.log"
TAG_NAME="Pre-Patch-Snapshot"
IP_FILE="REPLACE_WITH_IP_LIST.txt"
PROFILE="REPLACE_WITH_AWS_PROFILE"
SSH_KEY="REPLACE_WITH_SSH_KEY_PATH"
ANSIBLE_PLAYBOOK="ec2_patch_playbook.yml"
LOG_DIR="./logs"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Output log
exec > >(tee -a "$LOG_FILE") 2>&1

# Check input file
if [ ! -f "$IP_FILE" ]; then
  echo "ERROR: IP list file '$IP_FILE' not found."
  exit 1
fi

# Temp file to store snapshot metadata
TMP_FILE="snapshot_info_${NOW}.tmp"
> "$TMP_FILE"

echo "Starting snapshot process on: $(date)"
echo "----------------------------------------"

while read -r INSTANCE_IP; do
  [ -z "$INSTANCE_IP" ] && continue

  echo "Processing IP: $INSTANCE_IP"

  INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=private-ip-address,Values=$INSTANCE_IP" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text \
    --profile "$PROFILE")

  if [ -z "$INSTANCE_ID" ]; then
    echo "Error: No instance found with IP $INSTANCE_IP"
    continue
  fi

  ROOT_VOLUME_ID=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[].Instances[].BlockDeviceMappings[?DeviceName==\\/dev/xvda || DeviceName==\\/dev/sda1].Ebs.VolumeId" \
    --output text \
    --profile "$PROFILE")

  if [ -z "$ROOT_VOLUME_ID" ]; then
    echo "Error: No root volume found for instance $INSTANCE_ID"
    continue
  fi

  SNAPSHOT_ID=$(aws ec2 create-snapshot \
    --volume-id "$ROOT_VOLUME_ID" \
    --description "Pre-patch snapshot of $INSTANCE_ID on $DATE" \
    --query "SnapshotId" \
    --output text \
    --profile "$PROFILE")

  aws ec2 create-tags --resources "$SNAPSHOT_ID" --tags \
    Key=Name,Value="$TAG_NAME" \
    Key=InstanceId,Value="$INSTANCE_ID" \
    Key=Date,Value="$DATE" \
    Key=Purpose,Value="Patching" \
    --profile "$PROFILE"

  echo "Snapshot initiated: $SNAPSHOT_ID"

  echo "$INSTANCE_IP,$INSTANCE_ID,$ROOT_VOLUME_ID,$SNAPSHOT_ID" >> "$TMP_FILE"

done < "$IP_FILE"

echo ""
echo "All snapshots initiated. Waiting for 5 minutes..."
sleep 300

echo ""
echo "Snapshot status report:"
printf "%-15s %-20s %-20s %-20s %-15s\n" "Instance IP" "Instance ID" "Root Volume ID" "Snapshot ID" "Status"
echo "---------------------------------------------------------------------------------------------------------------"

while IFS=',' read -r INSTANCE_IP INSTANCE_ID ROOT_VOLUME_ID SNAPSHOT_ID; do
  STATUS=$(aws ec2 describe-snapshots --snapshot-ids "$SNAPSHOT_ID" \
    --query "Snapshots[0].State" --output text \
    --profile "$PROFILE")

  printf "%-15s %-20s %-20s %-20s %-15s\n" "$INSTANCE_IP" "$INSTANCE_ID" "$ROOT_VOLUME_ID" "$SNAPSHOT_ID" "$STATUS"

  if [ "$STATUS" == "completed" ]; then
    echo "Running Ansible patch playbook on $INSTANCE_IP..."
    ANSIBLE_LOG_FILE="$LOG_DIR/${INSTANCE_IP}_${NOW}.log"

    ansible-playbook "$ANSIBLE_PLAYBOOK" -i "${INSTANCE_IP}," --private-key "$SSH_KEY" | tee "$ANSIBLE_LOG_FILE"

    echo "Ansible execution finished. Log saved to: $ANSIBLE_LOG_FILE"
  else
    echo "Skipping Ansible playbook for $INSTANCE_IP due to snapshot status: $STATUS"
  fi

done < "$TMP_FILE"

echo ""
echo "Done. Main script log: $LOG_FILE"
rm -f "$TMP_FILE"
