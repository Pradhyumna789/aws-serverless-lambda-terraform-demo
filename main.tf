resource "aws_iam_role" "my-lambda-role" {
    name = "my-lambda-role"

    assume_role_policy = file("${path.module}/role.json")
}

resource "aws_iam_policy" "my-lambda-policy" {
    name = "my-lambda-policy"

    policy = file("${path.module}/policy.json")
}

resource "aws_iam_role_policy_attachment" "attaching-policy-and-role" {
    role = aws_iam_role.my-lambda-role.name
    policy_arn = aws_iam_policy.my-lambda-policy.arn
}

resource "aws_lambda_layer_version" "lambda-bcrypt-layer" {
    layer_name = "my-lambda-bcrypt-layer"
    filename = "${path.module}/nodejs.zip"
    compatible_runtimes = ["nodejs22.x"]
}

resource "aws_lambda_function" "my-lambda-function" {
    filename = "${path.module}/index.zip"
    function_name = "my-lambda-func"
    role = aws_iam_role.my-lambda-role.arn
    handler = "index.handler"
    runtime = "nodejs22.x"
    source_code_hash = filebase64sha256("${path.module}/index.zip")

    layers = [aws_lambda_layer_version.lambda-bcrypt-layer.arn]
}


# Integrating api gateway with lambda

resource "aws_api_gateway_rest_api" "example" {
  name        = "ServerlessExample"
  description = "Terraform Serverless Application Example"
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  parent_id   = "${aws_api_gateway_rest_api.example.root_resource_id}"
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = "${aws_api_gateway_rest_api.example.id}"
  resource_id   = "${aws_api_gateway_resource.proxy.id}"
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  resource_id = "${aws_api_gateway_method.proxy.resource_id}"
  http_method = "${aws_api_gateway_method.proxy.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.my-lambda-function.invoke_arn}"
}

resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = "${aws_api_gateway_rest_api.example.id}"
  resource_id   = "${aws_api_gateway_rest_api.example.root_resource_id}"
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
  resource_id = "${aws_api_gateway_method.proxy_root.resource_id}"
  http_method = "${aws_api_gateway_method.proxy_root.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.my-lambda-function.invoke_arn}"
}

resource "aws_api_gateway_deployment" "example" {
  depends_on = [
    aws_api_gateway_integration.lambda,
    aws_api_gateway_integration.lambda_root,
  ]

  rest_api_id = "${aws_api_gateway_rest_api.example.id}"
}

resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.example.id
  rest_api_id   = aws_api_gateway_rest_api.example.id
  stage_name    = "test"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.my-lambda-function.function_name}"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.example.execution_arn}/*/*"
}
