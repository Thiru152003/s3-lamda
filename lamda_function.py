import json
import os
import logging
import boto3
from datetime import datetime
from botocore.exceptions import ClientError

# -----------------------------
# Configure logging
# -----------------------------
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# -----------------------------
# Initialize AWS clients (outside handler for reuse)
# -----------------------------
dynamodb = boto3.resource('dynamodb')
table_name = os.getenv('DYNAMODB_TABLE_NAME', 'FileMetadata')  # Use env var for flexibility
table = dynamodb.Table(table_name)

# -----------------------------
# Helper: Validate S3 record
# -----------------------------
def validate_s3_record(record):
    """Ensure the record has expected S3 structure."""
    try:
        bucket_name = record['s3']['bucket']['name']
        object_key = record['s3']['object']['key']
        event_time = record.get('eventTime', datetime.utcnow().isoformat())
        size = record['s3']['object'].get('size', 0)
        return {
            'bucket_name': bucket_name,
            'object_key': object_key,
            'size': size,
            'event_time': event_time
        }
    except KeyError as e:
        logger.error(f"Malformed S3 record: missing key {e} in record: {record}")
        raise ValueError(f"Invalid S3 event record: {e}")

# -----------------------------
# Main Lambda Handler
# -----------------------------
def lambda_handler(event, context):
    """
    Triggered by S3 ObjectCreated events.
    Processes each file upload and stores metadata in DynamoDB.
    """
    logger.info("Lambda invoked with event: %s", json.dumps(event))

    if 'Records' not in event:
        logger.warning("No 'Records' in event. Skipping.")
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'No Records found in event'})
        }

    processed_count = 0
    errors = []

    for i, record in enumerate(event['Records']):
        try:
            # Skip non-S3 events (e.g., if other services send to same Lambda)
            if record.get('eventSource') != 'aws:s3':
                logger.info(f"Skipping non-S3 record {i}")
                continue

            # Extract and validate S3 info
            file_data = validate_s3_record(record)

            # Prepare DynamoDB item
            item = {
                'file_id': file_data['object_key'],           # Partition key
                'bucket_name': file_data['bucket_name'],
                'file_size_bytes': file_data['size'],
                'upload_time': file_data['event_time'],
                'processed_at': datetime.utcnow().isoformat(),
                'aws_request_id': context.aws_request_id,
                'region': record.get('awsRegion', 'unknown')
            }

            # Write to DynamoDB
            try:
                table.put_item(Item=item)
                logger.info("✅ Successfully stored file metadata", extra={'item': item})
                processed_count += 1
            except ClientError as e:
                error_msg = f"Failed to write to DynamoDB: {e}"
                logger.error(error_msg)
                errors.append({
                    'file': file_data['object_key'],
                    'error': str(e)
                })
                # Do NOT raise — continue processing other records

        except Exception as e:
            error_msg = f"Error processing record {i}: {str(e)}"
            logger.exception(error_msg)  # Logs full traceback
            errors.append({
                'record_index': i,
                'error': str(e)
            })

    # Final response
    response_body = {
        'processed_files': processed_count,
        'total_records': len(event['Records']),
        'errors': errors
    }

    logger.info("Lambda execution completed", extra=response_body)

    status_code = 500 if errors else 200
    return {
        'statusCode': status_code,
        'body': json.dumps(response_body, default=str)
    }
