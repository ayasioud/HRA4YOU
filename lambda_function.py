import json
import boto3
import os

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    try:
        
        response = table.update_item(
            Key={'counter_id': 'ssh_ports'},
            UpdateExpression='SET next_port = next_port + :inc',
            ExpressionAttributeValues={':inc': 1},
            ReturnValues='ALL_NEW'
        )

        allocated_port = int(response['Attributes']['next_port']) - 1

        
        if 'httpMethod' in event:
            return {
                'statusCode': 200,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'port': allocated_port,
                    'status': 'success'
                })
            }

        
        return {
            'port': allocated_port,
            'status': 'success'
        }

    except Exception as e:
        if 'httpMethod' in event:
            return {
                'statusCode': 500,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({'error': str(e), 'status': 'failed'})
            }
        return {'error': str(e), 'status': 'failed'}
