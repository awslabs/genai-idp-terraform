# Copyright Amazon.com, Inc. or its affiliates. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# ALB hosting for the Web UI. Internal ALB -> S3 interface VPC endpoint (IP
# targets) serving the Web UI bucket via host-header rewrite. Mirrors upstream
# IDP nested/alb-hosting/template.yaml. The two upstream CloudFormation custom
# resources are replaced with native Terraform:
#   - Custom::RegisterTargets  -> data.aws_network_interface + aws_lb_target_group_attachment
#   - Custom::SGIngressManager -> aws_vpc_security_group_ingress_rule per CIDR

data "aws_partition" "current" {}
data "aws_region" "current" {}

###########################################################################
# Security groups
###########################################################################
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "${var.name_prefix} Web UI ALB security group"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-alb-sg" })
}

# Inbound HTTPS from the allowed CIDRs (replaces the SGIngressManager custom resource).
resource "aws_vpc_security_group_ingress_rule" "alb_from_cidrs" {
  for_each = toset(var.alb_allowed_cidrs)

  security_group_id = aws_security_group.alb.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
  description       = "Allow HTTPS from allowed CIDR"
}

resource "aws_security_group" "endpoint" {
  name        = "${var.name_prefix}-s3-endpoint-sg"
  description = "${var.name_prefix} S3 VPC endpoint security group"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name_prefix}-s3-endpoint-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "endpoint_from_alb" {
  security_group_id            = aws_security_group.endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Allow HTTPS from ALB security group"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_endpoint" {
  security_group_id            = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.endpoint.id
  description                  = "Allow HTTPS to S3 VPC endpoint security group"
}

resource "aws_vpc_security_group_egress_rule" "endpoint_to_alb" {
  security_group_id            = aws_security_group.endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.alb.id
  description                  = "Allow HTTPS responses back to ALB security group"
}

# Optional: app Lambdas reach S3 through the same VPCE (presigned URLs).
# Gated on manage_lambda_sg_rules (a plan-known bool) rather than on
# lambda_security_group_id != null, so the count is determinable even when the
# Lambda security group is created in the same apply (its id is unknown at plan).
resource "aws_vpc_security_group_ingress_rule" "endpoint_from_lambda" {
  count                        = var.manage_lambda_sg_rules ? 1 : 0
  security_group_id            = aws_security_group.endpoint.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = var.lambda_security_group_id
  description                  = "Allow HTTPS from app Lambda security group"
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_endpoint" {
  count                        = var.manage_lambda_sg_rules ? 1 : 0
  security_group_id            = var.lambda_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.endpoint.id
  description                  = "Allow HTTPS to S3 VPC endpoint security group"
}

###########################################################################
# S3 interface VPC endpoint
###########################################################################
resource "aws_vpc_endpoint" "s3" {
  vpc_endpoint_type   = "Interface"
  service_name        = "com.amazonaws.${data.aws_region.current.id}.s3"
  vpc_id              = var.vpc_id
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.endpoint.id]
  private_dns_enabled = false

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowWebUIBucketRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = ["arn:${data.aws_partition.current.partition}:s3:::${var.web_ui_bucket_name}/*"]
      },
      {
        Sid       = "AllowWebUIBucketList"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:ListBucket"]
        Resource  = ["arn:${data.aws_partition.current.partition}:s3:::${var.web_ui_bucket_name}"]
      },
      {
        Sid       = "AllowSameAccountS3Operations"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:PutObject", "s3:AbortMultipartUpload", "s3:ListBucket", "s3:GetBucketLocation", "s3:ListMultipartUploadParts", "s3:DeleteObject"]
        Resource  = ["arn:${data.aws_partition.current.partition}:s3:::*"]
        Condition = {
          StringEquals = {
            "aws:PrincipalAccount" = data.aws_caller_identity.current.account_id
            "aws:ResourceAccount"  = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })

  tags = merge(var.tags, { Name = "${var.name_prefix}-s3-endpoint" })
}

data "aws_caller_identity" "current" {}

###########################################################################
# Target group + native target registration (replaces RegisterTargets CR)
###########################################################################
resource "aws_lb_target_group" "s3" {
  name        = "${var.name_prefix}-s3-tg"
  target_type = "ip"
  protocol    = "HTTPS"
  port        = 443
  vpc_id      = var.vpc_id

  health_check {
    protocol            = "HTTPS"
    port                = "443"
    path                = "/"
    matcher             = "200,307,405"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-s3-target-group" })
}

# The VPCE has one ENI per subnet; count is known at plan (subnet count), while
# the ENI ids/IPs resolve after apply. Register each ENI's private IP as a target.
data "aws_network_interface" "vpce" {
  count = length(var.subnet_ids)
  id    = tolist(aws_vpc_endpoint.s3.network_interface_ids)[count.index]
}

resource "aws_lb_target_group_attachment" "s3" {
  count            = length(var.subnet_ids)
  target_group_arn = aws_lb_target_group.s3.arn
  target_id        = data.aws_network_interface.vpce[count.index].private_ip
  port             = 443
  # The VPCE ENI IPs are inside the VPC, so the target's AZ must be the ENI's
  # actual AZ. "all" is only valid for IP targets outside the VPC (on-prem or
  # peered) and is rejected by ELB for in-VPC IPs.
  availability_zone = data.aws_network_interface.vpce[count.index].availability_zone
}

###########################################################################
# Application Load Balancer + HTTPS listener + rules
###########################################################################
resource "aws_lb" "this" {
  name                       = "${var.name_prefix}-webui-alb"
  load_balancer_type         = "application"
  internal                   = var.alb_scheme == "internal"
  subnets                    = var.subnet_ids
  security_groups            = [aws_security_group.alb.id]
  idle_timeout               = 60
  enable_http2               = true
  drop_invalid_header_fields = true

  dynamic "access_logs" {
    for_each = var.logging_bucket_name != null ? [1] : []
    content {
      enabled = true
      bucket  = var.logging_bucket_name
      prefix  = "alb-access-logs"
    }
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-webui-alb" })
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type = "fixed-response"
    fixed_response {
      status_code  = "404"
      content_type = "text/plain"
      message_body = "Not Found"
    }
  }
}

locals {
  s3_vhost = "${var.web_ui_bucket_name}.s3.${data.aws_region.current.id}.${data.aws_partition.current.dns_suffix}"
}

# Rule 1: root path -> rewrite to /index.html (SPA entry), rewrite Host to the
# bucket S3 vhost, forward to the S3 target group.
resource "aws_lb_listener_rule" "root" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 1

  condition {
    path_pattern {
      values = ["/"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.s3.arn
  }

  # Rewrite Host to the bucket's S3 virtual-hosted endpoint so S3 serves the object.
  transform {
    type = "host-header-rewrite"
    host_header_rewrite_config {
      rewrite {
        regex   = ".*"
        replace = local.s3_vhost
      }
    }
  }

  # Rewrite the leading "/" to "/index.html" (SPA entry). Matching only the
  # leading slash preserves the query string, required for OAuth callbacks
  # ("/?code=...&state=..."); "^/$" would miss when a query string is present.
  transform {
    type = "url-rewrite"
    url_rewrite_config {
      rewrite {
        regex   = "^/"
        replace = "/index.html"
      }
    }
  }

  depends_on = [aws_lb_target_group_attachment.s3]
}

# Rule 2: all other paths -> serve static assets (Host rewrite only).
resource "aws_lb_listener_rule" "catch_all" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 2

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.s3.arn
  }

  transform {
    type = "host-header-rewrite"
    host_header_rewrite_config {
      rewrite {
        regex   = ".*"
        replace = local.s3_vhost
      }
    }
  }

  depends_on = [aws_lb_target_group_attachment.s3]
}
