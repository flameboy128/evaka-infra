# Route53
data "aws_route53_zone" "evaka" {
  name         = var.evaka_fqdn
  private_zone = false
}

resource "aws_route53_record" "evaka" {
  zone_id = data.aws_route53_zone.evaka.zone_id
  name    = var.evaka_fqdn
  type    = "A"

  alias {
    name                   = aws_lb.alb.dns_name
    zone_id                = aws_lb.alb.zone_id
    evaluate_target_health = false
  }
}


# Certificate
resource "aws_acm_certificate" "evaka" {
  domain_name       = var.evaka_fqdn
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "evaka_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.evaka.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.evaka.zone_id
}

resource "aws_acm_certificate_validation" "evaka" {
  certificate_arn         = aws_acm_certificate.evaka.arn
  validation_record_fqdns = [for record in aws_route53_record.evaka_cert_validation : record.fqdn]
}


# Security Group
resource "aws_security_group" "alb" {
  name        = join("-", [lower(var.name_prefix), "alb"])
  description = "Security group for ${var.name_prefix} ALB in public subnet"
  vpc_id      = var.vpc_id

  # Normally, Terraform first deletes the existing security group resource and then creates a new one. When a security group is associated with a resource, the delete won't succeed. 
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = join("-", [lower(var.name_prefix), "alb"])
  }
}

# Allow all out
resource "aws_vpc_security_group_egress_rule" "evaka_alb_allow_all_out_ipv4" {
  description       = "Default allow all out rule"
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Allow HTTPS from allowed IP addresses
resource "aws_vpc_security_group_ingress_rule" "evaka_alb_allow_https_from" {
  for_each = var.allow_access_from

  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS in from ${each.value}"
  cidr_ipv4         = each.key
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# Allow HTTP from allowed IP addresses (for redirect to HTTPS)
resource "aws_vpc_security_group_ingress_rule" "evaka_alb_allow_http_from" {
  for_each = var.allow_access_from

  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP in from ${each.value}"
  cidr_ipv4         = each.key
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}


# Application Load Balancer
resource "aws_lb" "alb" {
  name               = join("-", [lower(var.name_prefix), "alb"])
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  enable_deletion_protection = false
  enable_http2               = true
  enable_xff_client_port     = true
}

# HTTP Listener (redirect to HTTPS)
resource "aws_lb_listener" "alb_redirect_http_to_https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS Listener for frontend
resource "aws_lb_listener" "alb_https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.evaka.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.evaka_frontend.arn
  }
}

# Listener rule for dummy-idp (path-based routing)
resource "aws_lb_listener_rule" "alb_https_rule_dummy_idp" {
  count = var.evaka_dummy_idp_image != "" ? 1 : 0

  listener_arn = aws_lb_listener.alb_https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dummy_idp[0].arn
  }

  condition {
    path_pattern {
      values = ["/idp/*"]
    }
  }
}


# Target Group for frontend
resource "aws_lb_target_group" "evaka_frontend" {
  name        = join("-", [lower(var.name_prefix), "frontend"])
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = 5

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }

  stickiness {
    enabled = true
    type    = "lb_cookie"
  }
}

# Target Group for dummy-idp
resource "aws_lb_target_group" "dummy_idp" {
  count = var.evaka_dummy_idp_image != "" ? 1 : 0

  name        = join("-", [lower(var.name_prefix), "dummy-idp"])
  port        = 9090
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  deregistration_delay = 5

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    matcher             = "200"
  }
}
