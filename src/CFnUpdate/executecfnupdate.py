import boto3
import botocore
from logging import getLogger
import json
import requests
import os

# xray patch
from aws_xray_sdk.core import patch

patch(["boto3"])

log = getLogger(__name__)


cfnclient = boto3.client("cloudformation")
ssm = boto3.client("ssm")
response = ssm.get_parameter(
    Name="webhookURL",
    WithDecryption=True
)
teams_url = response["Parameter"]["Value"]
snsclinet = boto3.client("sns")
aws_region = boto3.session.Session().region_name
account_id = boto3.client("sts").get_caller_identity().get("Account")
topic_arn = (
    "arn:aws:sns:"
    + aws_region
    + ":"
    + account_id
    + ":"
    + os.environ["ENV_NAME"]
    + "-CFn-Update-Notification"
)


def execute_upate_stack(event, context):
    change_service = event["Service"]
    response = cfnclient.describe_stacks(
        StackName=f"prod-{change_service}-stack")
    key_list = [key["ParameterKey"]
                for key in response["Stacks"][0]["Parameters"]]
    parameter_list = [
        {"ParameterKey": f"{key}", "UsePreviousValue": True} for key in key_list
    ]

    response = cfnclient.update_stack(
        StackName=f"prod-{change_service}-stack",
        UsePreviousTemplate=True,
        Parameters=parameter_list,
        Capabilities=["CAPABILITY_NAMED_IAM"],
    )
    log.info(f"Changed {change_service} Service.")

    waiter = cfnclient.get_waiter("stack_update_complete")

    # 30 sec * 26 times
    waiter.config.maxAttempts = 26

    try:
        waiter.wait(StackName=f"prod-{change_service}-stack")
    except botocore.exceptions.WaiterError as e:
        log.ingo(e)
        Msg = f"Updating {change_service} stack service."
        Success = False
    else:
        requests.post(
            teams_url,
            json.dumps(
                {
                    "title": "Update Stack Complete",
                    "text": f"{change_service} is changed.",
                }
            ),
        )
        Msg = f"Update {change_service} stack complete"
        Success = True
    finally:
        return {"Success": Success, "body": Msg, "Service": change_service}


def lambda_handler(event, context):
    response = execute_upate_stack(event, context)
    # send email if success. kick lambda for check if not
    if response["Success"]:
        snsclinet.publish(
            TopicArn=topic_arn,
            Message=response["body"],
            Subject="CFn Update Notification",
        )
    else:
        return {"Service": response["Service"]}
