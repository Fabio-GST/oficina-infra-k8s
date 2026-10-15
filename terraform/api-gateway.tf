# ---------------------------------------------------------------------------
# API Gateway (HTTP API) por ambiente — ponto único de entrada.
#
# Fluxo: cliente → API Gateway → VPC Link → NLB interno (criado pelo Service
# type=LoadBalancer da API no repo oficina-api) → pods da API.
#
# A rota POST /auth/cpf é adicionada pelo repo oficina-auth-lambda no mesmo
# gateway (id publicado no SSM). Só é criado com habilitar_gateway = true,
# porque depende do NLB já existir.
# ---------------------------------------------------------------------------
# Localiza o NLB que o cloud-controller criou para o Service da API.
data "aws_lbs" "api" {
  for_each = var.habilitar_gateway ? toset(var.ambientes) : toset([])

  tags = {
    "kubernetes.io/service-name" = "${local.namespaces[each.key]}/${var.nome_service_api}"
  }
}

locals {
  # Só ganha gateway o ambiente cuja API já publicou o NLB (ex.: hml antes de prod).
  ambientes_gateway = toset([
    for amb in var.ambientes : amb
    if var.habilitar_gateway && length(data.aws_lbs.api[amb].arns) > 0
  ])
}

data "aws_lb" "api" {
  for_each = local.ambientes_gateway
  arn      = one(data.aws_lbs.api[each.key].arns)
}

data "aws_lb_listener" "api" {
  for_each          = local.ambientes_gateway
  load_balancer_arn = data.aws_lb.api[each.key].arn
  port              = 80
}

resource "aws_security_group" "vpc_link" {
  for_each = local.ambientes_gateway

  name        = "${var.nome_cluster}-${each.key}-vpc-link"
  description = "Saida do VPC Link do API Gateway para o NLB da API"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.cidr_vpc]
  }
}

resource "aws_apigatewayv2_vpc_link" "api" {
  for_each = local.ambientes_gateway

  name               = "${var.nome_cluster}-${each.key}"
  security_group_ids = [aws_security_group.vpc_link[each.key].id]
  subnet_ids         = module.vpc.private_subnets
}

resource "aws_apigatewayv2_api" "api" {
  for_each = local.ambientes_gateway

  name          = "${var.nome_cluster}-${each.key}"
  protocol_type = "HTTP"
  description   = "Entrada unica da oficina (${each.key}): API no EKS + autenticacao por CPF na Lambda"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["authorization", "content-type", "x-request-id", "x-webhook-token"]
  }
}

resource "aws_apigatewayv2_integration" "api" {
  for_each = local.ambientes_gateway

  api_id             = aws_apigatewayv2_api.api[each.key].id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = data.aws_lb_listener.api[each.key].arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.api[each.key].id

  # Propaga o id de correlação gerado pelo gateway para os logs da API.
  request_parameters = {
    "overwrite:header.x-request-id" = "$context.requestId"
  }
}

resource "aws_apigatewayv2_route" "proxy" {
  for_each = local.ambientes_gateway

  api_id    = aws_apigatewayv2_api.api[each.key].id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.api[each.key].id}"
}

resource "aws_apigatewayv2_route" "raiz" {
  for_each = local.ambientes_gateway

  api_id    = aws_apigatewayv2_api.api[each.key].id
  route_key = "ANY /"
  target    = "integrations/${aws_apigatewayv2_integration.api[each.key].id}"
}

resource "aws_cloudwatch_log_group" "gateway" {
  for_each = local.ambientes_gateway

  name              = "/aws/apigateway/${var.nome_cluster}-${each.key}"
  retention_in_days = 7
}

resource "aws_apigatewayv2_stage" "padrao" {
  for_each = local.ambientes_gateway

  api_id      = aws_apigatewayv2_api.api[each.key].id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.gateway[each.key].arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      path           = "$context.path"
      status         = "$context.status"
      latencyMs      = "$context.responseLatency"
      integrationErr = "$context.integrationErrorMessage"
    })
  }
}
