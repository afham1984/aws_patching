# EC2 Automated Patching and Snapshot Management

This project provides a complete solution for automatically patching EC2 instances, creating pre-patch EBS snapshots, and cleaning up old snapshots using AWS Lambda.

---

## Components

### ✅ 1. `snapshot_and_patch.sh`
- Reads private IPs of EC2 instances from a file
- Finds instance ID and root volume ID
- Creates a snapshot before patching
- Runs Ansible playbook after snapshot is completed

### ✅ 2. `ec2_patch_playbook.yml`
- Collects system info
- Runs `apt update` and `apt dist-upgrade`
- Logs patching details

### ✅ 3. `lambda_delete_old_snapshots.py`
- AWS Lambda function
- Deletes snapshots older than 2 days
- Targets only snapshots with the tag `Purpose=Patching`

---
## 📁 Folder Structure

ec2-auto-patch/
├── snapshot_and_patch.sh # Shell script to trigger snapshots & Ansible
├── ec2_patch_playbook.yml # Ansible playbook for apt-based updates
├── lambda_delete_old_snapshots.py # Lambda function to delete old snapshots
├── ip_list.txt # List of private EC2 IPs
├── README.md # This documentation


## Prerequisites

- EC2 instances with SSH access (Debian/Ubuntu)
- AWS CLI installed and configured
- Ansible installed
- IAM roles with permissions:
  - For shell script: `ec2:DescribeInstances`, `ec2:CreateSnapshot`, `ec2:CreateTags`
  - For Lambda: `ec2:DescribeSnapshots`, `ec2:DeleteSnapshot`

---

## Usage

### 🔹 Step 1: Create IP List File

```text
10.0.1.101
10.0.1.102

**### 🔹 Step 2: Run the Snapshot and Patch Script**
Update these placeholders in snapshot_and_patch.sh:
REPLACE_WITH_IP_LIST.txt → your IP list file
REPLACE_WITH_AWS_PROFILE → your AWS CLI profile
REPLACE_WITH_SSH_KEY_PATH → path to your EC2 SSH key
REPLACE_WITH_REMOTE_USER in the Ansible playbook

Run the script:
bash snapshot_and_patch.sh


🔹 Step 3: Deploy Lambda Function
Open AWS Lambda Console
Create a new function (Python 3.x)
Paste content from lambda_delete_old_snapshots.py
Attach a role with snapshot permissions
Create CloudWatch Event to trigger daily

 🔹 Step 4: Set up CloudWatch trigger:
Trigger: cron(0 2 * * ? *) (daily at 2 AM)

Target: Your Lambda function

Notes
This setup is for Debian-based systems
Supports daily patching with rollback via snapshots
Clean and reusable format for production or demo
