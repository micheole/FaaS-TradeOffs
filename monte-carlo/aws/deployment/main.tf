provider "aws" {
  region = "eu-central-1"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Reusing when using data, otherwise use resource to create new
resource "aws_iam_role" "iam_for_montecarlo" {
  name = "iam_for_montecarlo"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.iam_for_montecarlo.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["logs:*", "lambda:InvokeFunction"],
        Resource = "*"
      }
    ]
  })
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/../src/lambda.js"
  output_path = "lambda_function_src.zip"
}

resource "aws_lambda_function" "lambda" {
  filename      = "lambda_function_src.zip"
  function_name = "json_terraform_lambda_monte_carlo_testing"
  role          = aws_iam_role.iam_for_montecarlo.arn

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "nodejs18.x"
  handler = "lambda.handler"
}

# Create an API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name        = "json_terraform_monte_carlo_testing_api"
  description = "API for Lambda Function used to test Monte Carlo simulations"
}

# Create a resource for the API
resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "lambda"
}

# Create a method for the resource
resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "POST"  # Change this to GET if you want to use a GET request
  authorization = "NONE"  # No authorization needed for public access
}

# Integrate the method with the Lambda function
resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"  # Same as your method
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn
}

# Deploy the API
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "dev"

  depends_on = [
    aws_api_gateway_method.method,
    aws_api_gateway_integration.integration
  ]
}

# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "allow_apigateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Output the API endpoint
output "api_endpoint" {
  value = "${aws_api_gateway_deployment.deployment.invoke_url}/${aws_api_gateway_resource.resource.path_part}"
}
