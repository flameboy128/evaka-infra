# AWS Infrastructure for eVaka

Infrastructure-as-Code for deploying a simple development environment of [eVaka](https://github.com/espoon-voltti/evaka) on AWS using Terraform/OpenTofu and Terragrunt.

> **Note**: This setup is not production-ready — additional hardening (IAM policies, WAF, monitoring, multi-AZ, etc.) is needed before running production workloads.

## About

This project was originally developed by [NordHero Oy](https://www.nordhero.com) for the [Municipality of Petäjävesi](https://www.petajavesi.fi), where NordHero implemented and maintained development, testing, and production environments. From the beginning of the project, the goal was to open-source the end result to help other Finnish municipalities adopt eVaka as an ERP for early childhood education.

This repository provides a generalized template for a development environment, with testing and production environment templates to follow.

## Trademark notes

- eVaka is an ERP system for early childhood education in Finland, jointly developed by the cities of Espoo, Oulu, Tampere, and Turku. The eVaka trademark is registered by the City of Espoo.
- eVaka is open source software published at https://github.com/espoon-voltti/evaka
- NordHero Oy is not a core developer of the eVaka system but helps municipalities plan, deploy, customize, and manage eVaka on AWS and integrate it with other systems.

## Architecture overview

The project consists of two repositories under a common project root (you will clone both during the [Deployment Guide](#deployment-guide)):

```
<project-root>/
├── evaka/              # eVaka application repo (cloned from espoon-voltti/evaka in Step 8)
└── evaka-infra/        # eVaka infrastructure repo (cloned in Step 2)
```

The infrastructure runs on a VPC with public and private subnets across two availability zones. Application services (frontend, API gateway, backend, Valkey, and a dummy IdP for dev) run on ECS Fargate behind an ALB with WAF protection. Data is stored in Aurora PostgreSQL Serverless v2, S3 buckets, and Secrets Manager. CI/CD is handled by GitHub Actions using OIDC authentication, and an SSM-managed bastion host provides database access. See [architecture-diagram.md](architecture-diagram.md) for a detailed visual diagram, request flow, and service startup sequence.

> **Note**: This is a starting-point template — the architecture can be adapted to your needs. For example, the frontend could be served via S3 and CloudFront instead of a container, Valkey could be replaced with Amazon ElastiCache, or the database could run as a container instead of Aurora Serverless. Feel free to modify the stacks to suit your requirements.

The infrastructure is organized into four stacks:

| Stack | Description |
|-------|-------------|
| `01-github` | GitHub Actions OIDC integration for CI/CD |
| `02-base` | VPC, RDS Aurora PostgreSQL, Route53, ECR, bastion host, Secrets Manager |
| `03-evaka` | ECS cluster, ALB, WAF, CloudWatch, application services (frontend, API gateway, backend, Valkey) |
| `04-backup` | AWS Backup vault with daily and weekly backup plans |

## Estimated AWS costs

A full development deployment of eVaka on AWS costs approximately **$180–185/month** when running 24/7 with on-demand pricing in the eu-north-1 (Stockholm) region, as of April 2026.

The main cost drivers are ECS Fargate compute (approx. $79/mo), networking including ALB and NAT Gateway (approx. $57/mo), and Aurora PostgreSQL Serverless v2 (approx. $27/mo at typical dev utilization). WAF, storage, and supporting services add roughly $20/month combined.

For development environments not used 24/7 and where Aurora auto-pauses frequently, the database cost can drop significantly. Additional savings are possible with Fargate Spot and scheduled scaling.

See [cost-pricing.md](cost-pricing.md) for a detailed breakdown, unit pricing reference, and optimization tips.

## Repository structure

```
<project-root>/
├── evaka/                            # eVaka application repository
│   ├── .github/workflows/            # GitHub Actions workflows (replaced in Step 8)
│   ├── apigw/                        # API gateway (Node.js)
│   ├── dummy-idp/                    # Dummy identity provider for dev
│   ├── frontend/                     # Frontend application
│   └── service/                      # Backend service (Java/Kotlin)
└── evaka-infra/                      # This infra repository
    ├── deployments/
    │   ├── root.hcl                  # Shared Terragrunt configuration
    │   └── dev/                      # Example dev environment
    │       ├── env.hcl.template      # Configuration template
    │       ├── env.hcl               # Environment-specific configuration (created in Step 3)
    │       ├── 01-github/
    │       ├── 02-base/
    │       ├── 03-evaka/
    │       │   └── deployment-data/  # Dummy certs/keys/mock data uploaded to S3
    │       └── 04-backup/
    ├── stacks/                       # Terraform modules
    │   ├── 01-github/
    │   ├── 02-base/
    │   ├── 03-evaka/
    │   └── 04-backup/
    ├── github-workflows_for_evaka/   # GitHub Actions workflows for the eVaka app repo
    └── github-workflows_for_infra/   # GitHub Actions workflows for the eVaka infra repo
```

## Prerequisites

- GitHub organization for eVaka application and eVaka infrastructure repositories
- AWS account where eVaka will be deployed
- A parent domain (e.g., `yourorg.fi`) where you can add NS records for DNS delegation
- AWS CLI [configured](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-quickstart.html) with appropriate credentials
- AWS [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) for the AWS CLI installed
- [Terraform](https://developer.hashicorp.com/terraform/install) (or [OpenTofu](https://opentofu.org/)) and [Terragrunt](https://docs.terragrunt.com/getting-started/install/) installed
- [Docker](https://www.docker.com/) installed (for building and pushing container images)

## Deployment guide

### Step 1: Create empty repos for eVaka app and eVaka infra in GitHub

Sign into GitHub.com and create two empty repositories for eVaka application and eVaka infrastructure in your organization, for example `evaka` and `evaka-infra`.

- `evaka` - **eVaka app repo** - can be public if it does not contain proprietary components, customizations, or integrations — which is typically the case for a standard eVaka setup.
- `evaka-infra` - **eVaka infra repo** - should be **private**. It will contain `env.hcl` with your AWS account ID and other environment-specific configuration. While true secrets are stored in AWS Secrets Manager, keeping the infra repository private avoids exposing account and infrastructure details.

Do not initialize repositories with a README, .gitignore, or license.

### Step 2: Clone and push the eVaka infra repo to your GitHub

Clone this eVaka infrastructure repository into your project root, remove any GitHub settings and workflows from the upstream and push it to your GitHub organization's eVaka infrastructure repository:

```bash
cd <project-root>
git clone <this-repo-url> evaka-infra

cd evaka-infra # <project-root>/evaka-infra
git remote set-url origin git@github.com:<YourOrg>/evaka-infra.git

# Remove any upstream GitHub settings and workflows that may exist.
git rm -r .github 2>/dev/null && git commit -m "ci: remove upstream GitHub settings and workflows" || echo "No .github files to delete."

git push -u origin main
```

### Step 3: Configure environment parameters

```bash
cd deployments/dev # <project-root>/evaka-infra/deployments/dev
cp env.hcl.template env.hcl
```

Edit `env.hcl` and set the required values:

| Variable | Description | Example |
|----------|-------------|---------|
| `env` | Environment name, used in resource names and tags | `dev` |
| `aws_account_id` | AWS account ID | `123456789012` |
| `aws_region` | AWS region for deployment | `eu-north-1` |
| `evaka_app_repository_name` | Your eVaka application GitHub repository | `YourOrg/evaka` |
| `evaka_infra_repository_name` | Your eVaka infrastructure GitHub repository | `YourOrg/evaka-infra` |
| `evaka_fqdn` | Fully qualified domain name for eVaka (a Route53 Hosted Zone will be created for it) | `evaka-dev.yourorg.fi` |
| `log_retention_in_days` | How many days to store logs | `30` |
| `allow_access_from` | CIDR blocks allowed to access the application | `{ "1.2.3.4/32": "Your office" }` |

> **Note**: The `env.hcl` file contains your AWS account ID and environment-specific configuration. It will be committed to the repository in Step 11. This is why the eVaka infra repository should be **private** (see Step 1). True secrets (database passwords, etc.) are stored in AWS Secrets Manager, not in `env.hcl`.

### Step 4: Deploy GitHub integration

This allows GitHub Actions to deploy images from the eVaka application repository to AWS ECR and to deploy eVaka infrastructure changes from the evaka-infra repository to the AWS account.

> **Note**: Before running terragrunt commands, you should have AWS credentials configured for your command line session. You can use command `aws sts get-caller-identity` to see if AWS CLI credentials are valid.

```bash
cd 01-github # <project-root>/evaka-infra/deployments/dev/01-github
terragrunt init --backend-bootstrap # Answer 'y', when asked to create remote state S3 bucket
terragrunt plan -out plan.out
terragrunt apply plan.out
```

This creates an IAM OIDC identity provider and role that GitHub Actions can assume without long-lived credentials.

> **Security Note**: The default configuration grants `AdministratorAccess` to the GitHub Actions role. For production, restrict permissions to only the required services (ECS, ECR, S3, RDS, etc.).

### Step 5: Deploy base infrastructure

```bash
cd ../02-base # <project-root>/evaka-infra/deployments/dev/02-base
terragrunt init --backend-bootstrap
terragrunt plan -out plan.out
terragrunt apply plan.out
```

This creates VPC, RDS Aurora PostgreSQL, Route53 Hosted Zone, ECR repositories, Secrets Manager secrets, EC2 bastion host, security groups, and IAM roles.

### Step 6: Set up DNS delegation

The base stack (Step 5) creates a Route53 Hosted Zone and outputs its name servers. For example:

```
r53_hosted_zone_name = "evaka-dev.yourorg.fi"
r53_nameservers = tolist([
  "ns-1234.awsdns-13.org",
  "ns-234.awsdns-14.com",
  "ns-2345.awsdns-41.co.uk",
  "ns-312.awsdns-18.net",
])
```

Create an NS record in your parent domain's DNS (e.g., `yourorg.fi`) pointing to these name servers:

- Record name: `evaka-dev` (the subdomain part)
- Record type: NS
- Value: the four name servers from the output
- TTL: 300 seconds (can be increased once stable)

Verify that DNS delegation is working:

```bash
dig NS evaka-dev.yourorg.fi +short
```

The output should return the four name servers listed above. If it returns empty results, wait a few minutes and try again.

> **Note**: DNS delegation is not needed until Step 9, where ACM certificate validation requires it. You can continue with Steps 7 and 8 while DNS propagation is in progress.

### Step 7: Configure database

Connect to the bastion host and RDS to create application database users.

Get the required details using the CLI:

```bash
# You should be in <project-root>/evaka-infra/deployments/dev/02-base

export AWS_REGION=$(terragrunt show -json | jq -r '.values.outputs.aws_region.value')
echo "AWS Region: $AWS_REGION"
export BASTION_INSTANCE_ID=$(terragrunt show -json | jq -r '.values.outputs.ec2_bastion_instance_id.value')
echo "bastion-instance-id: $BASTION_INSTANCE_ID"

echo "rds-writer-endpoint: $(terragrunt show -json | jq -r '.values.outputs.rds_database_endpoint_address.value')"
echo "rds_master-password: $(aws secretsmanager get-secret-value --secret-id $(terragrunt show -json | jq -r '.values.outputs.rds_master_password_secret_arn.value') --query 'SecretString' --output text)"
echo "migration-password: $(aws secretsmanager get-secret-value --secret-id $(terragrunt show -json | jq -r '.values.outputs.evaka_db_migration_user_password_arn.value') --query 'SecretString' --output text)"
echo "application-password: $(aws secretsmanager get-secret-value --secret-id $(terragrunt show -json | jq -r '.values.outputs.evaka_db_application_user_password_arn.value') --query 'SecretString' --output text)"
```

You can also get the required details from the AWS Management Console:
- **Bastion host ID** — AWS EC2 Console > Instances > `<prefix>-ec2-bastion`
- **RDS writer endpoint** — AWS RDS Console > `<prefix>-rds` > Connectivity > Writer endpoint
- **Passwords** — AWS Secrets Manager > `<prefix>-rds-rds_master`, `<prefix>-rds-evaka_migration`, `<prefix>-rds-evaka_application`

Connect to the database via bastion host:

```bash
# Connect to bastion
aws ssm start-session --target $BASTION_INSTANCE_ID
sudo -i -u ec2-user

# Connect to RDS — enter the rds_master password when prompted
psql -U rds_master -d template1 -h <rds-writer-endpoint>
```

Run the following SQL (replace `<migration-password>` and `<application-password>` with the actual passwords from above):

```sql
CREATE ROLE "evaka_migration_role";
CREATE ROLE "evaka_migration" WITH LOGIN PASSWORD '<migration-password>' IN ROLE "evaka_migration_role";

CREATE ROLE "evaka_application_role";
CREATE ROLE "evaka_application" WITH LOGIN PASSWORD '<application-password>' IN ROLE "evaka_application_role";

GRANT ALL PRIVILEGES ON DATABASE "evaka" TO "evaka_migration_role" WITH GRANT OPTION;

\c evaka

CREATE SCHEMA IF NOT EXISTS ext;
CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA ext;
CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA ext;

GRANT ALL ON SCHEMA "public" TO "evaka_migration_role";
GRANT ALL ON SCHEMA "ext" TO "evaka_migration_role";
GRANT USAGE ON SCHEMA "ext" TO "evaka_application_role";
\q
```
```bash
# Close the bastion connection
exit
exit
```

> **Note**: Extensions and the `ext` schema are created as `rds_master` because they require superuser privileges. The rest of the schema is managed automatically by eVaka's Flyway migrations on startup.

### Step 8: Clone and push the eVaka app repo to your GitHub

Clone [Espoo eVaka application repository](https://github.com/espoon-voltti/evaka) into your project root, remove any GitHub settings and workflows from the upstream, add this project's GitHub Actions workflows and push it to your GitHub organization's eVaka application repository:

```bash
cd ../../../.. # <project-root>
git clone https://github.com/espoon-voltti/evaka.git evaka

cd evaka # <project-root>/evaka
git remote set-url origin git@github.com:<YourOrg>/evaka.git
git checkout -b main

git rm -r .github
mkdir -p .github/workflows
cp ../evaka-infra/github-workflows_for_evaka/build-push-ecr.yml .github/workflows/
git add .github

git commit -m "ci: replace GitHub Actions workflows"
git push -u origin main
```

Get the details for your eVaka application GitHub repository:
```bash
cd ../evaka-infra/deployments/dev/01-github # <project-root>/evaka-infra/deployments/dev/01-github
echo "GH_ACTIONS_ROLE_ARN: $(terragrunt show -json | jq -r '.values.outputs.github_app_role_arn.value')"

cd ../02-base # <project-root>/evaka-infra/deployments/dev/02-base
echo "ECR_HOST: $(terragrunt show -json | jq -r '.values.outputs.ecr_host.value')"

echo "AWS_REGION: $(terragrunt show -json | jq -r '.values.outputs.aws_region.value')"
```

Add the target AWS account details to the eVaka application repository on GitHub:
1.  In your eVaka application repository GitHub page, navigate to Settings > Environments
1.  Add a new environment: `dev`
1.  Add Environment secrets:
  - `GH_ACTIONS_ROLE_ARN` - IAM role ARN for OIDC authentication. Example: `arn:aws:iam::123456789012:role/github-actions-role-app`
  - `ECR_HOST` - ECR registry URL. Example: `123456789012.dkr.ecr.eu-north-1.amazonaws.com`
  - `AWS_REGION` - AWS region where ECR repositories exist. Example: `eu-north-1`

Then trigger the build workflow in GitHub Actions to build and push container images to ECR:
1.  In your eVaka application repository GitHub page, navigate to Actions > Simple Build and Push to ECR (dev) *(you might need to select "Enable Actions on this repository")*
1.  Click "Run workflow", select Branch: main, click "Run workflow"
1.  Wait until all 4 jobs have completed. This takes approximately 12 minutes.

### Step 9: Deploy eVaka application

```bash
cd ../03-evaka # <project-root>/evaka-infra/deployments/dev/03-evaka
terragrunt init --backend-bootstrap
terragrunt plan -out plan.out
terragrunt apply plan.out
```

This creates an ECS cluster and services, Application Load Balancer, WAF, CloudWatch logs, Cloud Map service discovery, and application security groups.

Terragrunt will output two URLs:
- evaka_url - URL for parents
- evaka_employee_url - URL for employees

### Step 10: Deploy backups

```bash
cd ../04-backup # <project-root>/evaka-infra/deployments/dev/04-backup
terragrunt init --backend-bootstrap
terragrunt plan -out plan.out
terragrunt apply plan.out
```

This creates an AWS Backup vault with:
- Daily backups at midnight UTC (retained 3 days)
- Weekly backups on Sundays at midnight UTC (retained 30 days)

### Step 11: Enable CI/CD for the eVaka infra repo

Commit and push pending changes to your eVaka infrastructure GitHub repository. These changes are already deployed via terragrunt.

```bash
cd ../../../ # <project-root>/evaka-infra/

git add -A
git status # verify that only intended files are staged

git commit -m "initial dev-environment"
git push
```

> **Note**: Verify that `deployments/dev/env.hcl` is included in the staged files. Terragrunt reads configuration from this file, and GitHub Actions workflows will fail without it.

Get the details for your eVaka infrastructure GitHub repository:
```bash
cd deployments/dev/01-github # <project-root>/evaka-infra/deployments/dev/01-github
echo "GH_ACTIONS_ROLE_ARN: $(terragrunt show -json | jq -r '.values.outputs.github_infra_role_arn.value')"

cd ../02-base # <project-root>/evaka-infra/deployments/dev/02-base
echo "AWS_REGION: $(terragrunt show -json | jq -r '.values.outputs.aws_region.value')"
```

Add the target AWS account details to the eVaka infrastructure repository on GitHub.
1.  In your eVaka infrastructure repository GitHub page, navigate to Settings > Environments
1.  Add a new environment: `dev`
1.  Add Environment secrets:
  - `GH_ACTIONS_ROLE_ARN` - IAM role ARN for OIDC authentication. Example: `arn:aws:iam::123456789012:role/github-actions-role-infra`
  - `AWS_REGION` - AWS region for deployment. Example: `eu-north-1`

Add GitHub Actions workflows to the repository:

```bash
cd ../../.. # <project-root>/evaka-infra/

mkdir -p .github/workflows
cp github-workflows_for_infra/terragrunt-plan.yml github-workflows_for_infra/terragrunt-apply.yml .github/workflows

git add .github/workflows
git commit -m "ci: add GitHub Actions workflows"
git push
```

This adds two workflows:
- Terragrunt Plan (dev) - Runs automatically on pull requests to the `main` branch. Formats, validates, and plans all stacks against dev environment, then posts the plan output as a PR comment.
- Terragrunt Apply (dev) - Runs automatically when changes to `stacks/` or `deployments/` are pushed to the `main` branch. Validates and applies all stacks against dev environment.

Workflows can also be triggered manually. It is recommended to run Terragrunt Plan first, review the output, and then run Terragrunt Apply to avoid unintended changes.

## Removing resources

Deployed resources can be removed with `terragrunt destroy`:

```bash
cd <project-root>/evaka-infra/deployments/dev/04-backup
# answer "yes", when asked "Do you really want to destroy all resources?"
# If you get an error: Error: Failed to load plugin schemas, run terragrunt init
terragrunt destroy 

cd ../03-evaka
terragrunt destroy

cd ../02-base
terragrunt destroy

cd ../01-github
terragrunt destroy
```

The command will not destroy the Terraform state S3 bucket and possibly inactive ECS task definitions. Those can be removed with:
```bash
# List S3 buckets
aws s3 ls

# Remove the S3 bucket
aws s3 rm s3://evaka-dev-tf-state-123456789012 # Replace with your bucket name
```

```bash
# De-register any active eVaka task definitions
for arn in $(for family in dummy-idp evaka-apigw evaka-frontend evaka-service valkey; do
  aws ecs list-task-definitions \
    --family-prefix "$family" \
    --status ACTIVE \
    --region eu-north-1 \
    --query 'taskDefinitionArns[]' \
    --output text | tr '\t' '\n'
done); do
  echo "Deregistering: $arn"
  aws ecs deregister-task-definition \
    --task-definition "$arn" \
    --region eu-north-1 \
    --output text --query 'taskDefinition.taskDefinitionArn'
done
```

```bash
# Remove inactive eVaka task definitions
for arn in $(for family in dummy-idp evaka-apigw evaka-frontend evaka-service valkey; do
  aws ecs list-task-definitions \
    --family-prefix "$family" \
    --status INACTIVE \
    --region eu-north-1 \
    --query 'taskDefinitionArns[]' \
    --output text | tr '\t' '\n'
done); do
  echo "Deleting: $arn"
  aws ecs delete-task-definitions \
    --task-definitions "$arn" \
    --region eu-north-1 \
    --output text --query 'taskDefinitions[].taskDefinitionArn'
done
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the [Apache License 2.0](LICENSE).