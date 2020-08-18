import boto3
from logging import getLogger
import json
import os

# xray patck
from aws_xray_sdk.core import patch

patch(["boto3"])

log = getLogger(__name__)

queue_name = os.environ["ENV_NAME"] + "-InvokeChangeLambdaQueue"
sqs = boto3.resource("sqs")
queue = sqs.get_queue_by_name(QueueName=queue_name)
client_lambda = boto3.client("lambda")


def app_push_tag_from_queue(event, context):
    log.info(json.dumps(event))

    # Receive all until queue is all read.
    service_list = []
    delete_list = []
    process_count = 0
    while process_count < 3:
        msg_list = queue.receive_messages(
            MaxNumberOfMessages=10, VisibilityTimeout=10, WaitTimeSeconds=20
        )
        for message in msg_list:
            message.delete()
        if len(msg_list) != 0:
            delete_list[len(delete_list) : len(delete_list)] = msg_list
            process_count = 0
        else:
            process_count += 1
    for message in delete_list:
        notify_msg = json.loads(message.body)["Message"]
        msg_only = notify_msg.split("/")
        if msg_only[2] == "prod":
            service_list.append(msg_only[3])

    # remove dupulicate service list
    change_services = list(set(service_list))
    log.info("Update Service: ", change_services)
    for change_service in change_services:
        client_lambda.invoke(
            FunctionName=os.environ["ENV_NAME"] + "-CFn-Update-Executer",
            InvocationType="Event",
            Payload=json.dumps({"Service": change_service}),
        )
        log.info(f"Kicked Lambda for {change_service} Service Update.")


def lambda_handler(event, context):
    try:
        app_push_tag_from_queue(event, context)
    except Exception as e:
        log.info(e)
