# WAF Web ACL
resource "aws_wafv2_web_acl" "evaka_alb" {
  count = var.waf_enabled ? 1 : 0

  name  = join("-", [lower(var.name_prefix), "waf"])
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rule 1: Geo-blocking - Allow only Finland
  rule {
    name     = "geo-blocking"
    priority = 10

    action {
      block {}
      # In case you want to count rule invokes instead of blocking, use:
      # count {}
    }

    statement {
      not_statement {
        statement {
          geo_match_statement {
            country_codes = ["FI"]
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "GeoBlocking"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS Managed Rules - Core Rule Set
  rule {
    name     = "aws-managed-core-rule-set"
    priority = 20

    override_action {
      # none {}
      # In case you want to count rule invokes instead of blocking, use:
      count {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: AWS Managed Rules - Known Bad Inputs
  rule {
    name     = "aws-managed-known-bad-inputs"
    priority = 30

    override_action {
      # none {}
      # In case you want to count rule invokes instead of blocking, use:
      count {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: AWS Managed Rules - Amazon IP Reputation List
  rule {
    name     = "aws-managed-ip-reputation-list"
    priority = 40

    override_action {
      # none {}
      # In case you want to count rule invokes instead of blocking, use:
      count {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  # Rule 5: AWS Managed Rules - Anonymous IP list
  rule {
    name     = "aws-managed-anonymous-ip-list"
    priority = 50

    override_action {
      # none {}
      # In case you want to count rule invokes instead of blocking, use:
      count {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAnonymousIpList"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAnonymousIpList"
      sampled_requests_enabled   = true
    }
  }

  # Rule 6: AWS Managed Rules - SQL database managed rule group
  rule {
    name     = "aws-managed-sql-rule-set"
    priority = 60

    override_action {
      # none {}
      # In case you want to count rule invokes instead of blocking, use:
      count {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesSQLiRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesSQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Rule 7: Rate-based blanket rule
  rule {
    name     = "rate-based-rule-blanket"
    priority = 100

    action {
      # block {}
      # In case you want to count rule invokes instead of blocking, use:
      count {}
    }

    statement {
      rate_based_statement {
        evaluation_window_sec = 300
        limit                 = 5000
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateBasedRuleBlanket"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = join("-", [lower(var.name_prefix), "waf"])
    sampled_requests_enabled   = true
  }

  tags = {
    Name = join("-", [lower(var.name_prefix), "waf"])
  }
}

# Associate WAF with ALB
resource "aws_wafv2_web_acl_association" "evaka_alb" {
  count = var.waf_enabled ? 1 : 0

  resource_arn = aws_lb.alb.arn
  web_acl_arn  = aws_wafv2_web_acl.evaka_alb[0].arn
}

# CloudWatch Log Group for WAF
resource "aws_cloudwatch_log_group" "evaka_alb_waf" {
  count = var.waf_enabled ? 1 : 0

  name              = "aws-waf-logs-${var.name_prefix}"
  retention_in_days = var.log_retention_in_days
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "evaka_alb" {
  count = var.waf_enabled ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.evaka_alb[0].arn
  log_destination_configs = [aws_cloudwatch_log_group.evaka_alb_waf[0].arn]
  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}
