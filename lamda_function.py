import json
import boto3

def lambda_handler(event, context):
    """
    Triggered when an object is created in the S3 bucket.
    Logs bucket name and object key.
    """
    print("Received event from S3:")
    print(json.dumps(event, indent=2))

    for record in event['Records']:
        bucket_name = record['s3']['bucket']['name']
        object_key = record['s3']['object']['key']
        print(f"New file uploaded: s3://{bucket_name}/{object_key}")

        # Example: You could add logic here to:
        # - Resize image
        # - Parse CSV
        # - Copy to another bucket
        # - Write to DynamoDB, etc.

    return {
        'statusCode': 200,
        'body': json.dumps('File processed successfully!')
    }
