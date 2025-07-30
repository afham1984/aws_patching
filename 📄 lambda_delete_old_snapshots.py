import boto3
from datetime import datetime, timezone, timedelta

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    retention_days = 2
    delete_before = datetime.now(timezone.utc) - timedelta(days=retention_days)

    snapshots = ec2.describe_snapshots(OwnerIds=['self'])['Snapshots']
    deleted = 0

    for snapshot in snapshots:
        start_time = snapshot['StartTime']
        tags = {tag['Key']: tag['Value'] for tag in snapshot.get('Tags', [])}

        if tags.get('Purpose') == 'Patching' and start_time < delete_before:
            ec2.delete_snapshot(SnapshotId=snapshot['SnapshotId'])
            print(f"Deleted snapshot: {snapshot['SnapshotId']}")
            deleted += 1

    print(f"Total snapshots deleted: {deleted}")
