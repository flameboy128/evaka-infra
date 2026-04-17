resource "aws_route53_zone" "evaka" {
  name    = var.evaka_fqdn
  comment = "Public Route53 Zone"
}
