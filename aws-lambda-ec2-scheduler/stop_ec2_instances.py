"""
AWS Lambda Function: Stop EC2 Instances
========================================
Stops all running EC2 instances tagged with AutoSchedule=true.

Designed to be triggered by an EventBridge scheduled rule
(e.g., every day at 02:00 AM UTC).

Required IAM Permissions:
    - ec2:DescribeInstances
    - ec2:StopInstances
"""

import logging
import boto3
from botocore.exceptions import ClientError

# ── Logging ──────────────────────────────────────────────────────────────────
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


# ── Helper ───────────────────────────────────────────────────────────────────
def get_filtered_instance_ids(ec2_client, state_name: str) -> list[str]:
    """
    Return a list of EC2 instance IDs that match:
      • Tag  AutoSchedule = true
      • Instance state = *state_name* (e.g. 'running', 'stopped')
    """
    filters = [
        {"Name": "tag:AutoSchedule", "Values": ["true"]},
        {"Name": "instance-state-name", "Values": [state_name]},
    ]

    try:
        response = ec2_client.describe_instances(Filters=filters)
    except ClientError as exc:
        logger.error("Failed to describe instances: %s", exc)
        raise

    instance_ids = [
        instance["InstanceId"]
        for reservation in response.get("Reservations", [])
        for instance in reservation.get("Instances", [])
    ]
    return instance_ids


def stop_instances(ec2_client, instance_ids: list[str]) -> dict:
    """
    Stop the given EC2 instances and return the API response.
    """
    try:
        response = ec2_client.stop_instances(InstanceIds=instance_ids)
        logger.info(
            "Stop request accepted for %d instance(s): %s",
            len(instance_ids),
            instance_ids,
        )
        return response
    except ClientError as exc:
        logger.error("Failed to stop instances %s: %s", instance_ids, exc)
        raise


# ── Lambda Handler ───────────────────────────────────────────────────────────
def lambda_handler(event, context):
    """
    Entry point for AWS Lambda.
    Stops every *running* EC2 instance tagged AutoSchedule=true.
    """
    ec2 = boto3.client("ec2")

    logger.info("Searching for running instances with tag AutoSchedule=true …")
    instance_ids = get_filtered_instance_ids(ec2, state_name="running")

    if not instance_ids:
        logger.info("No running instances found matching the tag. Nothing to do.")
        return {
            "statusCode": 200,
            "body": "No running instances to stop.",
        }

    logger.info("Found %d running instance(s): %s", len(instance_ids), instance_ids)
    stop_instances(ec2, instance_ids)

    return {
        "statusCode": 200,
        "body": f"Successfully requested stop for {len(instance_ids)} instance(s).",
        "stoppedInstanceIds": instance_ids,
    }
