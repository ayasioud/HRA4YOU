import json
import boto3
import os
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])


def _extract_instance_name(event):
    if isinstance(event, dict):
        if event.get('instance_name'):
            return str(event['instance_name']).strip()
        body = event.get('body')
        if body:
            try:
                parsed = json.loads(body) if isinstance(body, str) else body
                value = parsed.get('instance_name')
                if value:
                    return str(value).strip()
            except Exception:
                return None
    return None


def _allocate_next_port():
    response = table.update_item(
        Key={'counter_id': 'ssh_ports'},
        UpdateExpression='SET next_port = next_port + :inc',
        ExpressionAttributeValues={':inc': 1},
        ReturnValues='ALL_NEW'
    )
    return int(response['Attributes']['next_port']) - 1


def _get_or_create_port_for_instance(instance_name):
    mapping_key = f"instance#{instance_name}"
    existing = table.get_item(Key={'counter_id': mapping_key}).get('Item')
    if existing and 'port' in existing:
        return int(existing['port'])

    allocated_port = _allocate_next_port()

    try:
        table.update_item(
            Key={'counter_id': mapping_key},
            UpdateExpression='SET port = :port',
            ExpressionAttributeValues={':port': allocated_port},
            ConditionExpression='attribute_not_exists(counter_id)'
        )
        return allocated_port
    except ClientError as exc:
        if exc.response.get('Error', {}).get('Code') != 'ConditionalCheckFailedException':
            raise
        current = table.get_item(Key={'counter_id': mapping_key}).get('Item')
        if not current or 'port' not in current:
            raise
        return int(current['port'])


def lambda_handler(event, context):
    try:
        instance_name = _extract_instance_name(event)
        if instance_name:
            allocated_port = _get_or_create_port_for_instance(instance_name)
        else:
            allocated_port = _allocate_next_port()

        if 'httpMethod' in event:
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'port': allocated_port, 'status': 'success'})
            }

        return {'port': allocated_port, 'status': 'success'}

    except Exception as e:
        if 'httpMethod' in event:
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': str(e), 'status': 'failed'})
            }
        return {'error': str(e), 'status': 'failed'}