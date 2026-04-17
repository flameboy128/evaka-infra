# eVaka Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│  CI/CD (GitHub Actions)                                                                 │
│                                                                                         │
│  ┌─────────────────────────────┐       ┌──────────────────────────────────┐             │
│  │  evaka repo                 │       │  evaka-infra repo                │             │
│  │  build-push-ecr.yml         │       │  terragrunt-apply.yml            │             │
│  │                             │       │                                  │             │
│  │  Builds & pushes images:    │       │  Terragrunt run --all apply      │             │
│  │  - dummy-idp                │       │  (deployments/dev/)              │             │
│  │  - evaka/api-gateway        │       │                                  │             │
│  │  - evaka/frontend-common    │       │  Stacks:                         │             │
│  │  - evaka/service            │       │  01-github → 02-base →           │             │
│  │                             │       │  03-evaka  → 04-backup           │             │
│  └──────────┬──────────────────┘       └──────────┬───────────────────────┘             │
│             │ OIDC                                │ OIDC                                │
│             │ (github-actions-role-app)           │ (github-actions-role-infra)         │
└─────────────┼─────────────────────────────────────┼─────────────────────────────────────┘
              │                                     │
              ▼                                     ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│  AWS Account                                                                            │
│                                                                                         │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐   │
│  │  IAM (01-github stack)                                                           │   │
│  │  - GitHub OIDC Provider                                                          │   │
│  │  - github-actions-role-infra (AdministratorAccess)                               │   │
│  │  - github-actions-role-app   (AdministratorAccess)                               │   │
│  └──────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                         │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐   │
│  │  ECR Repositories (02-base stack)                                                │   │
│  │  - dummy-idp                                                                     │   │
│  │  - evaka/api-gateway                                                             │   │
│  │  - evaka/frontend-common                                                         │   │
│  │  - evaka/service                                                                 │   │
│  └──────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                         │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐   │
│  │  VPC  10.0.0.0/16  (02-base stack)                                               │   │
│  │                                                                                  │   │
│  │  ┌────────────────────────────────────────────────────────────────────────────┐  │   │
│  │  │  Public Subnets (10.0.0.0/24 AZ-a, 10.0.1.0/24 AZ-b)                       │  │   │
│  │  │                                                                            │  │   │
│  │  │         Internet                                                           │  │   │
│  │  │            │                                                               │  │   │
│  │  │     ┌──────┴──────┐                                                        │  │   │
│  │  │     │     IGW     │                                                        │  │   │
│  │  │     └──────┬──────┘                                                        │  │   │
│  │  │            │                                                               │  │   │
│  │  │     ┌──────┴──────────────────────────────────┐                            │  │   │
│  │  │     │  WAF (03-evaka stack)                   │                            │  │   │
│  │  │     │  - Geo-blocking (FI only)               │                            │  │   │
│  │  │     │  - AWS Managed Rules (Core, Bad Inputs, │                            │  │   │
│  │  │     │    IP Reputation, Anonymous IP, SQLi)   │                            │  │   │
│  │  │     │  - Rate limiting (5000/5min)            │                            │  │   │
│  │  │     └──────┬──────────────────────────────────┘                            │  │   │
│  │  │            │                                                               │  │   │
│  │  │     ┌──────┴──────────────────────────────────┐                            │  │   │
│  │  │     │  ALB (public, HTTPS)                    │                            │  │   │
│  │  │     │  - Route53: evaka_fqdn → ALB            │                            │  │   │
│  │  │     │  - ACM Certificate (DNS validated)      │                            │  │   │
│  │  │     │  - HTTP→HTTPS redirect                  │                            │  │   │
│  │  │     │  - TLS 1.3 policy                       │                            │  │   │
│  │  │     │                                         │                            │  │   │
│  │  │     │  Routing:                               │                            │  │   │
│  │  │     │    /idp/*  → dummy-idp:9090             │                            │  │   │
│  │  │     │    /*      → frontend:8080 (default)    │                            │  │   │
│  │  │     └──────┬─────────────┬────────────────────┘                            │  │   │
│  │  │            │             │                                                 │  │   │
│  │  │     ┌──────┴───┐   ┌─────┴──────┐                                          │  │   │
│  │  │     │ NAT GW   │   │            │                                          │  │   │
│  │  │     └──────┬───┘   │            │                                          │  │   │
│  │  └────────────┼───────┼────────────┼──────────────────────────────────────────┘  │   │
│  │               │       │            │                                             │   │
│  │  ┌────────────┼───────┼────────────┼──────────────────────────────────────────┐  │   │
│  │  │  Private Subnets (10.0.2.0/24 AZ-a, 10.0.3.0/24 AZ-b)                      │  │   │
│  │  │            │       │            │                                          │  │   │
│  │  │            │       │            │                                          │  │   │
│  │  │  ┌─────────┼───────┼────────────┼──────────────────────────────────────┐   │  │   │
│  │  │  │  ECS Cluster (Fargate) — 03-evaka stack                             │   │  │   │
│  │  │  │  Service Connect + Cloud Map DNS                                    │   │  │   │
│  │  │  │         │       │            │                                      │   │  │   │
│  │  │  │         │  ┌────┴─────┐ ┌────┴──────┐                               │   │  │   │
│  │  │  │         │  │ frontend │ │ dummy-idp │                               │   │  │   │
│  │  │  │         │  │ :8080    │ │ :9090     │  (optional)                   │   │  │   │
│  │  │  │         │  │ 256cpu   │ │ 256cpu    │                               │   │  │   │
│  │  │  │         │  │ 512MB    │ │ 512MB     │                               │   │  │   │
│  │  │  │         │  └────┬─────┘ └───────────┘                               │   │  │   │
│  │  │  │         │       │ :3000                                             │   │  │   │
│  │  │  │         │  ┌────┴──────────┐                                        │   │  │   │
│  │  │  │         │  │ apigw (Node)  │──────────┐                             │   │  │   │
│  │  │  │         │  │ :3000         │          │ :6379                       │   │  │   │
│  │  │  │         │  │ 256cpu/512MB  │    ┌─────┴──────┐                      │   │  │   │
│  │  │  │         │  └────┬──────────┘    │  Valkey    │                      │   │  │   │
│  │  │  │         │       │ :8888         │  :6379     │                      │   │  │   │
│  │  │  │         │  ┌────┴──────────┐    │  256/512MB │                      │   │  │   │
│  │  │  │         │  │ service (JVM) │    └────────────┘                      │   │  │   │
│  │  │  │         │  │ :8888         │                                        │   │  │   │
│  │  │  │         │  │ 1024cpu/2048MB│                                        │   │  │   │
│  │  │  │         │  │ Sidecars:     │                                        │   │  │   │
│  │  │  │         │  │ - db-wait     │                                        │   │  │   │
│  │  │  │         │  │ - dev-data-   │                                        │   │  │   │
│  │  │  │         │  │   loader      │                                        │   │  │   │
│  │  │  │         │  │ - vtj-loader  │                                        │   │  │   │
│  │  │  │         │  └───┬───────┬───┘                                        │   │  │   │
│  │  │  │         │      │       │                                            │   │  │   │
│  │  │  └─────────┼──────┼───────┼────────────────────────────────────────────┘   │  │   │
│  │  │            │      │       │                                                │  │   │
│  │  │            │      │  ┌────┴──────────────────────────────┐                 │  │   │
│  │  │            │      │  │  Aurora PostgreSQL Serverless v2  │                 │  │   │
│  │  │            │      │  │  (02-base stack)                  │                 │  │   │
│  │  │            │      │  │  0-4 ACU, auto-pause 1hr          │                 │  │   │
│  │  │            │      │  │  Storage encrypted                │                 │  │   │
│  │  │            │      │  └───────────────────────────────────┘                 │  │   │
│  │  │            │      │                                                        │  │   │
│  │  │     ┌──────┴──────┴──────┐                                                 │  │   │
│  │  │     │  EC2 Bastion       │                                                 │  │   │
│  │  │     │  t3.nano           │                                                 │  │   │
│  │  │     │  SSM managed       │                                                 │  │   │
│  │  │     │  (DB access)       │                                                 │  │   │
│  │  │     └────────────────────┘                                                 │  │   │
│  │  │                                                                            │  │   │
│  │  └────────────────────────────────────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                         │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐   │
│  │  Supporting Services                                                             │   │
│  │                                                                                  │   │
│  │  S3 Buckets (03-evaka):              Secrets Manager (02-base):                  │   │
│  │  - deployment (config/certs)         - rds_master password                       │   │
│  │  - data                              - evaka_application password                │   │
│  │  - attachments                       - evaka_migration password                  │   │
│  │  - decisions                                                                     │   │
│  │  - fee-decisions                     SSM Parameter Store (03-evaka):             │   │
│  │  - voucher-value-decisions           - Container image tags                      │   │
│  │  - invoices                                                                      │   │
│  │                                      CloudWatch Logs:                            │   │
│  │  Route53 (02-base):                  - /ecs/*/evaka-frontend                     │   │
│  │  - Public hosted zone                - /ecs/*/evaka-apigw                        │   │
│  │                                      - /ecs/*/evaka-service                      │   │
│  │  AWS Backup (04-backup):             - /ecs/*/valkey                             │   │
│  │  - Daily (retain 3 days)             - /ecs/*/dummy-idp                          │   │
│  │  - Weekly (retain 30 days)           - WAF logs                                  │   │
│  └──────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘


 ═══════════════════════════════════════════════════════════════
  REQUEST FLOW
 ═══════════════════════════════════════════════════════════════

  User → DNS (Route53) → WAF → ALB (:443)
    ├── /idp/*   → dummy-idp (:9090)     ← dummy SAML IdP for dev
    └── /*       → frontend  (:8080)     ← nginx serving React SPA
                      │
                      │ /api/*
                      ▼
                   apigw (:3000)          ← Node.js API gateway
                   │         │               (auth, sessions, routing)
                   │         │
                   │    Valkey (:6379)     ← Session store
                   │
                   ▼
               service (:8888)            ← JVM backend (Kotlin/Spring)
               │         │
               │         ▼
               │    Aurora PostgreSQL      ← Primary database
               │
               ▼
            S3 Buckets                    ← Documents, attachments, config


 ═══════════════════════════════════════════════════════════════
  INFRASTRUCTURE STACKS (Terragrunt ordering)
 ═══════════════════════════════════════════════════════════════

  01-github   → GitHub OIDC IAM roles
  02-base     → VPC, RDS, ECR, Route53, Bastion, Secrets Manager
  03-evaka    → ECS Cluster, Services, ALB, WAF, S3, Service Discovery
  04-backup   → AWS Backup vault & plans


 ═══════════════════════════════════════════════════════════════
  EVAKA-SERVICE STARTUP SEQUENCE
 ═══════════════════════════════════════════════════════════════

  The evaka-service ECS task contains multiple containers that
  start in a specific order using ECS container dependencies.
  This handles Aurora Serverless v2 auto-pause wake-up and
  loads test data on first deployment.

  ┌────────────┐
  │  db-wait   │  postgres:17-alpine
  │            │  Polls Aurora with pg_isready every 3s
  │            │  until the database responds.
  └─────┬──────┘
        │ SUCCESS
        ▼
  ┌─────────────────┐
  │  evaka-service  │  Main application (JVM/Spring)
  │                 │  1. Downloads config from S3
  │                 │  2. Flyway runs DB migrations
  │                 │  3. Spring Boot starts
  │                 │  4. Health check: /health
  └──┬──────────────┘
     │ HEALTHY
     ▼
  ┌──────────────┐
  │ dev-data     │  postgres:17-alpine
  │ -loader      │  Checks care_area count.
  │              │  If 0, loads dev SQL files
  │              │  via psql. Skips if data
  │              │  already exists.
  └──────┬───────┘
         │ SUCCESS
         ▼
  ┌──────────────┐
  │ vtj-loader   │  curlimages/curl
  │              │  POSTs mock VTJ persons
  │              │  to dev-api endpoint.
  └──────────────┘

  JDBC URL includes ?connectTimeout=60 to tolerate
  Aurora wake-up latency during Flyway connection.
```
