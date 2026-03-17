
resource "aws_api_gateway_rest_api" "hra4you_api" {
  name        = "hra4you-port-allocation-api"
  description = "API pour allouer les ports SSH dynamiquement"

  tags = {
    Name = "hra4you-port-api"
  }
}


resource "aws_api_gateway_resource" "allocate_port" {
  rest_api_id = aws_api_gateway_rest_api.hra4you_api.id
  parent_id   = aws_api_gateway_rest_api.hra4you_api.root_resource_id
  path_part   = "allocate-port"
}


resource "aws_api_gateway_method" "allocate_port_get" {
  rest_api_id      = aws_api_gateway_rest_api.hra4you_api.id
  resource_id      = aws_api_gateway_resource.allocate_port.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true  
}


resource "aws_api_gateway_integration" "allocate_port" {
  rest_api_id      = aws_api_gateway_rest_api.hra4you_api.id
  resource_id      = aws_api_gateway_resource.allocate_port.id
  http_method      = "GET"
  type             = "AWS_PROXY"
  integration_http_method = "POST"
  uri              = aws_lambda_function.allocate_port.invoke_arn
}


resource "aws_api_gateway_usage_plan" "hra4you" {
  name = "hra4you-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.hra4you_api.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }

  throttle_settings {
    rate_limit  = 100
    burst_limit = 200
  }
}


resource "aws_api_gateway_api_key" "hra4you" {
  name        = "hra4you-port-api-key"
  description = "Clé API pour allouer les ports SSH"
  enabled     = true

  tags = {
    Name = "hra4you-api-key"
  }
}


resource "aws_api_gateway_usage_plan_key" "hra4you" {
  key_id        = aws_api_gateway_api_key.hra4you.id
  usage_plan_id = aws_api_gateway_usage_plan.hra4you.id
  key_type      = "API_KEY"
}


resource "aws_api_gateway_deployment" "hra4you" {
  depends_on = [aws_api_gateway_integration.allocate_port]

  rest_api_id = aws_api_gateway_rest_api.hra4you_api.id
}


resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.hra4you.id
  rest_api_id   = aws_api_gateway_rest_api.hra4you_api.id
  stage_name    = "prod"

  variables = {
    environment = "production"
  }

  tags = {
    Name = "hra4you-prod"
  }
}


output "api_endpoint" {
  value       = "${aws_api_gateway_stage.prod.invoke_url}/allocate-port"
  description = "URL complète pour appeler l'API"
}

output "api_key" {
  value       = aws_api_gateway_api_key.hra4you.value
  sensitive   = true
  description = "Clé API (à configurer dans terraform.tfvars)"
}

output "api_key_id" {
  value       = aws_api_gateway_api_key.hra4you.id
  description = "ID de la clé API"
}
