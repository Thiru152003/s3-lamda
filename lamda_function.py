import json
import boto3
from datetime import datetime

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
TABLE_NAME = 'FileMetadata'  # Must match Terraform

def lambda_handler(event, context):
    table = dynamodb.Table(TABLE_NAME)
    
    for record in event['Records']:
        # Extract S3 info
        bucket_name = record['s3']['bucket']['name']
        object_key = record['s3']['object']['key']
        size = record['s3']['object']['size']  # in bytes
        event_time = record['eventTime']

        # Optional: get file extension
        file_type = object_key.split('.')[-1].lower() if '.' in object_key else 'unknown'

        # Prepare item to store
        item = {
            'file_id': object_key,                     # Partition key
            'bucket_name': bucket_name,
            'file_size_bytes': size,
            'upload_time': event_time,
            'file_type': file_type,
            'processed_at': datetime.utcnow().isoformat()
        }

        # Save to DynamoDB
        try:
            table.put_item(Item=item)
            print(f"✅ Saved to DynamoDB: {object_key}")
        except Exception as e:
            print(f"❌ Error saving to DynamoDB: {str(e)}")
            raise e

    return {
        'statusCode': 200,
        'body': json.dumps('File metadata stored successfully!')
    }
