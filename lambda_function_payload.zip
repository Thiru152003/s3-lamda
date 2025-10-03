# lambda_function.py

import os
import json
import logging
import boto3
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

TABLE_NAME = os.environ['DYNAMODB_TABLE_NAME']
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    for record in event['Records']:
        try:
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            size = record['s3']['object'].get('size', 0)
            event_time = record.get('eventTime', datetime.utcnow().isoformat())

            table.put_item(
                Item={
                    'file_id': key,
                    'bucket_name': bucket,
                    'file_size_bytes': size,
                    'upload_time': event_time,
                    'processed_at': datetime.utcnow().isoformat()
                }
            )
            logger.info(f"✅ Stored {key} in {TABLE_NAME}")
        except Exception as e:
            logger.error(f"❌ Failed to process {key}: {str(e)}")
            raise e

    return {'statusCode': 200, 'body': json.dumps('Success')}
