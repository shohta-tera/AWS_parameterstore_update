import boto3
import botocore
from logging import getLogger
import json
import requests
import os

# x-ray patch
from aws_xray_sdk.core import patch

patch(["boto3"])

log = getLogger(__name__)
teams_url = ""
cfnclient = boto3.client("cloudformation")
snsclient = boto3.client("sns")
aws_region = boto3.session.Session().region_name
account_id = boto3.client("sts").get_caller_identiry().get("Account")
topic_arn = (
    "arn:aws:sns:"
    + aws_region
    + ":"
    + account_id
    + ":"
    + os.eniron["ENV_NAME"]
    + "-CFn-Update-Notification"
)


def retry_treatment(event, context):
    change_service = event["requestPayload"]["Service"]
    log.info(f"Checking {change_service} Service")

    waiter = cfnclient.get_waiter("stack_update_complete")
    # 30 sec * 26 times
    waiter.config.maxAttempts = 26

    try:
        waiter.wait(Stackname=f"prod-{change_service}-stack")
    except botocore.exceptions.WaiterError as e:
        log.info(e)
        Msg = f"Not Accomplished Updating {change_service} stack Service"
        Success = False
    else:
        requests.post(
            teams_url,
            json.dumps(
                {
                    "title": "Update Stacks Complete",
                    "text": f"{change_service} is changed.",
                }
            ),
        )
        Msg = f"Update {change_service} stack complete"
        Success = True
    finally:
        return {"Success": Success, "body": Msg, "Service": change_service}


def lambda_handler(event, context):
    response = retry_treatment(event, context)
    if response["Success"]:
        snsclient.publish(
            TopicArn=topic_arn,
            Message=response["body"],
            Subject="CFn Update Notification",
        )
    else:
        snsclient.publish(
            TopicArn=topic_arn,
            Message=response["body"],
            Subject="CFn Update Notification",
        )
