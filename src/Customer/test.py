import boto3
import os

ssm = boto3.client("ssm")

def get_env_val():
    response = ssm.get_parameter(
        Name="webhookURL",
        WithDecryption=True
    )
    return response["Parameter"]["Value"]

def lambda_handler(evnt, context):
    webhookURL = get_env_val()
    print(f"WebHookURL is {webhookURL}")