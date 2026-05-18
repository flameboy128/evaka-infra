# eVaka development infrastructure configuration template
# Copy this file to env.hcl and customize the values marked with TODO comments
# Avoid using nordic alphabets even in descriptions

locals {
  env             = "dev"
  aws_account_id  = "926058918693"  # TODO: Replace with your AWS account ID
  aws_region      = "eu-north-1"    # TODO: Change if using different region

  evaka_app_repository_name   = "flameboy128/evaka"        # TODO: Replace with your eVaka application GitHub repository
  evaka_infra_repository_name = "flameboy128/evaka-infra"  # TODO: Replace with your eVaka infrastructure GitHub repository

  evaka_fqdn  = "evaka-dev.petajavesi.fi"  # Fully qualified domain name for eVaka (a Route53 Hosted Zone will be created for it)
  
  log_retention_in_days = 30  # TODO: Replace with your preferred log retention in days

  # Network access control - Apply 03-evaka stack for changes to take effect
  # TODO: Restrict to your IP addresses for security
  # Note: DO NOT ALLOW ACCESS FROM EVERYWHERE!
  allow_access_from = {
    "84.231.96.172/32" : "Allow from a single IP address"
  }

  # For simple dev environment, values below don't need to be edited

  name_prefix = "evaka-${local.env}"

  # Container images - these will be built and pushed to your ECR
  evaka_image_tag       = "latest"
  evaka_dummy_idp_image = "${local.aws_account_id}.dkr.ecr.${local.aws_region}.amazonaws.com/dummy-idp:${local.evaka_image_tag}"
  evaka_frontend_image  = "${local.aws_account_id}.dkr.ecr.${local.aws_region}.amazonaws.com/evaka/frontend-common:${local.evaka_image_tag}"
  evaka_apigw_image     = "${local.aws_account_id}.dkr.ecr.${local.aws_region}.amazonaws.com/evaka/api-gateway:${local.evaka_image_tag}"
  evaka_service_image   = "${local.aws_account_id}.dkr.ecr.${local.aws_region}.amazonaws.com/evaka/service:${local.evaka_image_tag}"

  # Frontend environment variables
  evaka_frontend_envvars = {
    RESOLVER : "169.254.169.253 valid=5s ipv6=off"
    ENDUSER_GW_URL : "http://apigw.evaka.local:3000"
    INTERNAL_GW_URL : "http://apigw.evaka.local:3000"
    RATE_LIMIT_CIDR_WHITELIST: "0.0.0.0/0;::/0"
    HTTP_SCHEME : "http"  # TODO: Change to "https" in production
  }

  # API Gateway environment variables
  evaka_apigw_envvars = {
    VOLTTI_ENV : "dev"
    NODE_ENV : "local" # local, test. Note: 'test' is for automated test env
    JWT_PRIVATE_KEY: "/home/evaka/s3/dummy_jwt_private_key.pem"
    EVAKA_BASE_URL : "https://${local.evaka_fqdn}"
    EVAKA_SERVICE_URL : "http://evaka-service:8888"
    SFI_SAML_CALLBACK_URL: "https://${local.evaka_fqdn}/api/application/auth/saml/login/callback",
    SFI_SAML_ENTRYPOINT: "https://${local.evaka_fqdn}/idp/sso",
    SFI_SAML_LOGOUT_URL: "https://${local.evaka_fqdn}/idp/slo",
    SFI_SAML_ISSUER: "https://${local.evaka_fqdn}/api/application/auth/saml/"

    REDIS_HOST : "ecs-valkey"
    REDIS_PORT : "6379"
    REDIS_DISABLE_SECURITY : "true"
    AD_MOCK: "true"
    SFI_MODE: "test"
    
    ENABLE_DEV_API : "true"
    INCLUDE_ALL_ERROR_MESSAGES: "true"
    PRETTY_LOGS: "true"
  }

  # Service environment variables
  evaka_service_envvars = {
    VOLTTI_ENV: "test"
    SPRING_PROFILES_ACTIVE: "production"
    SPRING_PROFILES_INCLUDE: "enable_dev_api,enable_mock_integration_endpoint"
    
    JAVA_OPTS: "-server -Djava.security.egd=file:/dev/./urandom -Xms1024m -Xss512k -Xmx1024m -XX:TieredStopAtLevel=1"

    ESPOO_INTEGRATION_INVOICE_ENABLED: "false"
    
    EVAKA_ASYNC_JOB_RUNNER_DISABLE_RUNNER: "false"
    EVAKA_BUCKET_PROXY_THROUGH_NGINX: "true"

    EVAKA_FRONTEND_BASE_URL_FI : "https://${local.evaka_fqdn}"
    EVAKA_FRONTEND_BASE_URL_SV : "https://${local.evaka_fqdn}"

    EVAKA_INTEGRATION_DVV_MODIFICATIONS_PASSWORD: ""
    EVAKA_INTEGRATION_DVV_MODIFICATIONS_URL : ""
    EVAKA_INTEGRATION_DVV_MODIFICATIONS_USER_ID: ""
    EVAKA_INTEGRATION_DVV_MODIFICATIONS_XROAD_CLIENT_ID: ""
    
    EVAKA_INTEGRATION_VARDA_SOURCE_SYSTEM: ""
    EVAKA_INTEGRATION_VARDA_URL: "http://localhost:8888/mock-integration/varda/api"
    
    EVAKA_INTEGRATION_VTJ_USERNAME: ""
    EVAKA_INTEGRATION_VTJ_XROAD_TRUST_STORE_LOCATION: "file:///home/evaka/s3/dummy_trust_store.jks"
    EVAKA_INTEGRATION_VTJ_XROAD_TRUST_STORE_PASSWORD: "password"
    EVAKA_INTEGRATION_VTJ_XROAD_TRUST_STORE_TYPE: "JKS"
    
    EVAKA_JWT_PUBLIC_KEYS_URL : "file:///home/evaka/s3/dummy_jwks.json"
  }

}