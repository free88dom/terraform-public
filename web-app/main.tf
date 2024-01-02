terraform {
    cloud { 
        organization = "jiriSvoboda" 
        workspaces { name = "github-workspace" } 
        }
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 4.16"
        }
    }
    required_version = ">= 1.6.0"
}

provider "aws" {
    region = "eu-west-1" 
    default_tags {
        tags = {
            ManagedByTerraform  = "true"
            TestingTag          = "test"
        }
    }
}
# Lambda 
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


resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "index.py"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "test_lambda" {
  filename      = "lambda_function_payload.zip"
  function_name = "HelloWorldFunction"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "index.lambda_handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.10"
}

data "aws_iam_policy_document" "lambda_logging" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:*"]
  }
}

data "aws_iam_policy_document" "lambda_dynamo_access" {
  statement {
    effect = "Allow"

    actions = [
            "dynamodb:PutItem",
            "dynamodb:DeleteItem",
            "dynamodb:GetItem",
            "dynamodb:Scan",
            "dynamodb:Query",
            "dynamodb:UpdateItem"
    ]

    resources = ["${aws_dynamodb_table.dynamodb_table.arn}"]
  }
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = data.aws_iam_policy_document.lambda_logging.json
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_iam_policy" "lambda_dynamo_access" {
  name        = "lambda_dynamo_access"
  path        = "/"
  description = "IAM policy for accessing DynamoDB"
  policy      = data.aws_iam_policy_document.lambda_dynamo_access.json
}

resource "aws_iam_role_policy_attachment" "lambda_dynamo_access" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_dynamo_access.arn
}

# API GW 
resource "aws_api_gateway_rest_api" "test_rest_api" {
    name = "HelloWorldAPI"
    endpoint_configuration {
    types = ["EDGE"]
  }
}

# API GW --------

resource "aws_api_gateway_method" "test_api_options_method" {
    rest_api_id   = "${aws_api_gateway_rest_api.test_rest_api.id}"
    resource_id   = "${aws_api_gateway_rest_api.test_rest_api.root_resource_id}"
    http_method   = "OPTIONS"
    authorization = "NONE"
}

resource "aws_api_gateway_integration" "test_api_options_integration" {
    rest_api_id   = "${aws_api_gateway_rest_api.test_rest_api.id}"
    resource_id   = "${aws_api_gateway_rest_api.test_rest_api.root_resource_id}"
    http_method   = "${aws_api_gateway_method.test_api_options_method.http_method}"
    type          = "MOCK"
    request_templates = {
        "application/json" = "{\"statusCode\": 200}"
    }
    depends_on = [aws_api_gateway_method.test_api_options_method]
}

resource "aws_api_gateway_method_response" "test_api_options_200" {
    rest_api_id   = "${aws_api_gateway_rest_api.test_rest_api.id}"
    resource_id   = "${aws_api_gateway_rest_api.test_rest_api.root_resource_id}"
    http_method   = "${aws_api_gateway_method.test_api_options_method.http_method}"
    status_code   = "200"
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
        "method.response.header.Access-Control-Allow-Headers" = true
        "method.response.header.Access-Control-Allow-Methods" = true
    }
    response_models = {
        "application/json" = "Empty" 
            }
    depends_on = [aws_api_gateway_method.test_api_options_method]
}

resource "aws_api_gateway_integration_response" "test_api_options_integration_response" {
    rest_api_id   = "${aws_api_gateway_rest_api.test_rest_api.id}"
    resource_id   = "${aws_api_gateway_rest_api.test_rest_api.root_resource_id}"
    http_method   = "${aws_api_gateway_method.test_api_options_method.http_method}"
    status_code   = "${aws_api_gateway_method_response.test_api_options_200.status_code}"
    response_parameters = {
        "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
        "method.response.header.Access-Control-Allow-Methods" = "'*'"
        "method.response.header.Access-Control-Allow-Origin" = "'*'"
    }
    depends_on = [aws_api_gateway_method_response.test_api_options_200]
}



# ---------------------


resource "aws_api_gateway_method" "cors_method" {
    rest_api_id   = "${aws_api_gateway_rest_api.test_rest_api.id}"
    resource_id   = "${aws_api_gateway_rest_api.test_rest_api.root_resource_id}"
    http_method   = "POST"
    authorization = "NONE"
}

resource "aws_api_gateway_method_response" "cors_method_response_200" {
    rest_api_id   = "${aws_api_gateway_rest_api.test_rest_api.id}"
    resource_id   = "${aws_api_gateway_rest_api.test_rest_api.root_resource_id}"
    http_method   = "${aws_api_gateway_method.cors_method.http_method}"
    status_code   = "200"
    response_parameters = {
        "method.response.header.Access-Control-Allow-Origin" = true
    }
    response_models = {
        "application/json" = "Empty" 
            }
    
    depends_on = [aws_api_gateway_method.cors_method]
}

resource "aws_api_gateway_integration" "integration" {
    rest_api_id   = "${aws_api_gateway_rest_api.test_rest_api.id}"
    resource_id   = "${aws_api_gateway_rest_api.test_rest_api.root_resource_id}"
    http_method   = "${aws_api_gateway_method.cors_method.http_method}"
    integration_http_method = "POST"
    type          = "AWS"
    uri           = "arn:aws:apigateway:eu-west-1:lambda:path/2015-03-31/functions/${aws_lambda_function.test_lambda.arn}/invocations"
    depends_on    = [aws_api_gateway_method.cors_method, aws_lambda_function.test_lambda]
    
}

resource "aws_api_gateway_integration_response" "cors_integration_response" {
    rest_api_id   = "${aws_api_gateway_rest_api.test_rest_api.id}"
    resource_id   = "${aws_api_gateway_rest_api.test_rest_api.root_resource_id}"
    http_method   = "${aws_api_gateway_method.cors_method.http_method}"
    status_code   = "${aws_api_gateway_method_response.cors_method_response_200.status_code}"
    response_parameters = {

        "method.response.header.Access-Control-Allow-Origin" = "'*'"
    }
    response_templates =  {
        "application/json" = ""
        }
    depends_on = [aws_api_gateway_method_response.cors_method_response_200]
}

resource "aws_api_gateway_deployment" "deployment" {
    rest_api_id   = "${aws_api_gateway_rest_api.test_rest_api.id}"
    stage_name    = "Dev"
    depends_on    = [aws_api_gateway_integration.integration]
}
resource "aws_lambda_permission" "apigw_lambda" {
    statement_id  = "AllowExecutionFromAPIGateway"
    action        = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.test_lambda.arn}"
    principal     = "apigateway.amazonaws.com"
    source_arn    = "arn:aws:execute-api:eu-west-1:746234921045:${aws_api_gateway_rest_api.test_rest_api.id}/*/${aws_api_gateway_method.cors_method.http_method}/"
}

# DynamoDB

resource "aws_dynamodb_table" "dynamodb_table" {
  name           = "HelloWorldDatabase"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "ID"

  attribute {
    name = "ID"
    type = "S"
  }
}