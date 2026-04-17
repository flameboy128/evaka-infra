locals {
  evaka_buckets = [
    "deployment",
    "data",
    "attachments",
    "decisions",
    "fee-decisions",
    "voucher-value-decisions",
    "invoices"
  ]
}

resource "aws_s3_bucket" "evaka" {
  for_each      = toset(local.evaka_buckets)
  bucket_prefix = "${var.name_prefix}-${each.value}-"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "evaka_versioning" {
  for_each = aws_s3_bucket.evaka
  bucket   = each.value.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "evaka_lifecycle" {
  for_each = aws_s3_bucket.evaka
  bucket   = each.value.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

# evaka-srv prefix comes from https://github.com/espoon-voltti/evaka/blob/9b2aa37ff1a89db25f544bc867eba1f66a2b146f/service/entrypoint.sh#L15
# api-gw prefix comes from https://github.com/espoon-voltti/evaka/blob/9b2aa37ff1a89db25f544bc867eba1f66a2b146f/apigw/entrypoint.sh#L15

# Dummy-data for evaka-service
resource "aws_s3_object" "evaka_service_jwks" {
  bucket = aws_s3_bucket.evaka["deployment"].id
  key    = "evaka-srv/dummy_jwks.json"
  source = "./deployment-data/evaka-srv/dummy_jwks.json"
  etag   = filemd5("./deployment-data/evaka-srv/dummy_jwks.json")
}

resource "aws_s3_object" "evaka_service_trust_store" {
  bucket = aws_s3_bucket.evaka["deployment"].id
  key    = "evaka-srv/dummy_trust_store.jks"
  source = "./deployment-data/evaka-srv/dummy_trust_store.jks"
  etag   = filemd5("./deployment-data/evaka-srv/dummy_trust_store.jks")
}

# Dev data files for initialization
locals {
  dev_data_files = [
    "mock-vtj-dataset.json",
    "dev-data.sql",
    "service-need-options.sql",
    "employees.sql",
    "preschool-terms.sql",
    "club-terms.sql",
  ]
}

resource "aws_s3_object" "dev_data" {
  for_each = toset(local.dev_data_files)

  bucket = aws_s3_bucket.evaka["deployment"].id
  key    = "evaka-srv/dev-data/${each.value}"
  source = "./deployment-data/evaka-srv/dev-data/${each.value}"
  etag   = filemd5("./deployment-data/evaka-srv/dev-data/${each.value}")
}


# Data for evaka-apigw
resource "aws_s3_object" "evaka_apigw_ad_saml_private_cert" {
  bucket = aws_s3_bucket.evaka["deployment"].id
  key    = "api-gw/dummy_ad_saml_sp_sign_private_key.pem"
  source = "./deployment-data/api-gw/dummy_ad_saml_sp_sign_private_key.pem"
  etag   = filemd5("./deployment-data/api-gw/dummy_ad_saml_sp_sign_private_key.pem")
}

resource "aws_s3_object" "evaka_apigw_ad_saml_public_cert" {
  bucket = aws_s3_bucket.evaka["deployment"].id
  key    = "api-gw/dummy_ad_saml_idp_sign_public_cert.pem"
  source = "./deployment-data/api-gw/dummy_ad_saml_idp_sign_public_cert.pem"
  etag   = filemd5("./deployment-data/api-gw/dummy_ad_saml_idp_sign_public_cert.pem")
}

resource "aws_s3_object" "evaka_apigw_jwt_private_key" {
  bucket = aws_s3_bucket.evaka["deployment"].id
  key    = "api-gw/dummy_jwt_private_key.pem"
  source = "./deployment-data/api-gw/dummy_jwt_private_key.pem"
  etag   = filemd5("./deployment-data/api-gw/dummy_jwt_private_key.pem")
}

resource "aws_s3_object" "evaka_apigw_sfi_saml_private_cert" {
  bucket = aws_s3_bucket.evaka["deployment"].id
  key    = "api-gw/dummy_sfi_saml_sp_sign_private_key.pem"
  source = "./deployment-data/api-gw/dummy_sfi_saml_sp_sign_private_key.pem"
  etag   = filemd5("./deployment-data/api-gw/dummy_sfi_saml_sp_sign_private_key.pem")
}

resource "aws_s3_object" "evaka_apigw_sfi_saml_public_cert" {
  bucket = aws_s3_bucket.evaka["deployment"].id
  key    = "api-gw/dummy_sfi_saml_idp_sign_public_cert.pem"
  source = "./deployment-data/api-gw/dummy_sfi_saml_idp_sign_public_cert.pem"
  etag   = filemd5("./deployment-data/api-gw/dummy_sfi_saml_idp_sign_public_cert.pem")
}
