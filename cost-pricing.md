# eVaka AWS Cost & Pricing Documentation

Region: **eu-north-1 (EU Stockholm)** | Pricing model: **ON DEMAND** | Last updated: 2026-04-12

## Summary

A full development deployment of eVaka on AWS costs approximately **$180–185/month** when running 24/7 with on-demand pricing in the eu-north-1 (Stockholm) region, as of April 2026.

The main cost drivers are ECS Fargate compute (approx. $79/mo), networking including ALB and NAT Gateway (approx. $57/mo), and Aurora PostgreSQL Serverless v2 (approx. $27/mo at typical dev utilization). WAF, storage, and supporting services add roughly $20/month combined.

For development environments not used 24/7 and where Aurora auto-pauses frequently, the database cost can drop significantly. Additional savings are possible with Fargate Spot and scheduled scaling.

Key cost optimization opportunities include using Fargate Spot (up to 70% savings on ECS), switching to ARM/Graviton processors (20% savings), and adding VPC endpoints to reduce NAT Gateway data transfer charges. See [Cost Optimization Notes](#cost-optimization-notes) for details.

> **Note**: Prices are based on publicly available AWS on-demand pricing for eu-north-1 as of early 2026. Actual costs may vary — verify current rates using the [AWS Pricing Calculator](https://calculator.aws/).

---

## Unit Pricing Reference

### ECS Fargate

| Resource | x86 On-Demand | ARM On-Demand | x86 Spot | ARM Spot |
|----------|--------------|--------------|----------|----------|
| vCPU | $0.04450/hr | $0.03560/hr | $0.01335/hr | $0.01068/hr |
| Memory | $0.00490/GB-hr | $0.00392/GB-hr | $0.00147/GB-hr | $0.001176/GB-hr |
| Ephemeral Storage | $0.000116/GB-hr (above 20 GB free) | | | |

### Aurora PostgreSQL Serverless v2

| Resource | Unit Price |
|----------|-----------|
| ACU (compute) | $0.14 per ACU-hour |
| Storage | $0.11 per GB-month |
| I/O (Aurora Standard) | $0.21 per million requests |

### Application Load Balancer

| Resource | Unit Price |
|----------|-----------|
| ALB hour | $0.02394 per hour |
| LCU hour | $0.0076 per LCU-hour |

### NAT Gateway

| Resource | Unit Price |
|----------|-----------|
| NAT GW hour | $0.046 per hour |
| Data processed | $0.046 per GB |

### WAFv2

| Resource | Unit Price |
|----------|-----------|
| Web ACL | $5.00 per month |
| Rule | $1.00 per rule per month |
| Requests | $0.60 per million requests |

### S3 (Standard)

| Resource | Unit Price |
|----------|-----------|
| Storage (first 50 TB) | $0.023 per GB-month |

### ECR

| Resource | Unit Price |
|----------|-----------|
| Storage | $0.10 per GB-month |

### Secrets Manager

| Resource | Unit Price |
|----------|-----------|
| Secret | $0.40 per secret per month |
| API calls | $0.05 per 10,000 requests |

### CloudWatch Logs

| Resource | Unit Price |
|----------|-----------|
| Log ingestion (custom) | $0.54 per GB |
| Log storage | $0.028 per GB-month |
| WAF vended logs (first 10 TB) | $0.54 per GB |

### Route53

| Resource | Unit Price |
|----------|-----------|
| Hosted zone | $0.50 per zone per month |

---

## Monthly Cost Estimate (24/7 running)

730 hours/month assumed.

### ECS Fargate Services

| Service | vCPU | Memory (GB) | vCPU Cost | Memory Cost | Monthly |
|---------|------|-------------|-----------|-------------|---------|
| frontend | 0.25 | 0.5 | $0.04450 × 0.25 × 730 = $8.12 | $0.00490 × 0.5 × 730 = $1.79 | **$9.91** |
| apigw | 0.25 | 0.5 | $8.12 | $1.79 | **$9.91** |
| service | 1.0 | 2.0 | $0.04450 × 1.0 × 730 = $32.49 | $0.00490 × 2.0 × 730 = $7.15 | **$39.64** |
| valkey | 0.25 | 0.5 | $8.12 | $1.79 | **$9.91** |
| dummy-idp | 0.25 | 0.5 | $8.12 | $1.79 | **$9.91** |
| **Fargate Total** | | | | | **$79.28** |

### Aurora PostgreSQL Serverless v2

| Component | Calculation | Monthly |
|-----------|------------|---------|
| Compute (avg 0.5 ACU, auto-pause after 1hr idle) | $0.14 × 0.5 × 730 = $51.10 (max if always on) | **$0 – $51.10** |
| Compute (approx. 50% paused) | $0.14 × 0.5 × 365 | **approx. $25.55** |
| Storage (10 GB assumed) | $0.11 × 10 | **$1.10** |
| **Aurora Total (typical)** | | **approx. $26.65** |

### Networking

| Component | Calculation | Monthly |
|-----------|------------|---------|
| ALB | $0.02394 × 730 | **$17.48** |
| ALB LCU (low traffic, approx. 1 LCU avg) | $0.0076 × 1 × 730 | **$5.55** |
| NAT Gateway | $0.046 × 730 | **$33.58** |
| NAT data (10 GB assumed) | $0.046 × 10 | **$0.46** |
| **Networking Total** | | **approx. $57.07** |

### WAFv2

| Component | Calculation | Monthly |
|-----------|------------|---------|
| Web ACL (1) | $5.00 × 1 | **$5.00** |
| Rules (7 total: 2 custom + 5 AWS Managed) | $1.00 × 7 | **$7.00** |
| Requests (1M assumed) | $0.60 × 1 | **$0.60** |
| **WAF Total** | | **approx. $12.60** |

### Storage & Supporting Services

| Component | Calculation | Monthly |
|-----------|------------|---------|
| S3 (7 buckets, approx. 5 GB total) | $0.023 × 5 | **$0.12** |
| ECR (4 repos, approx. 4 GB total) | $0.10 × 4 | **$0.40** |
| Secrets Manager (3 secrets) | $0.40 × 3 | **$1.20** |
| Route53 (1 hosted zone) | $0.50 × 1 | **$0.50** |
| CloudWatch Logs (approx. 2 GB/month) | $0.54 × 2 + $0.028 × 2 | **$1.14** |
| **Supporting Total** | | **approx. $3.46** |

### EC2 Bastion (t3.nano)

t3.nano in eu-north-1 is **$0.0054/hr → approx. $3.94/month** (check [AWS EC2 pricing](https://aws.amazon.com/ec2/pricing/on-demand/) for current rates).

---

## Monthly Total Summary

| Category | Estimated Monthly Cost |
|----------|----------------------|
| ECS Fargate (5 services) | $79.28 |
| Aurora PostgreSQL Serverless v2 | approx. $26.65 |
| Networking (ALB + NAT GW) | approx. $57.07 |
| WAFv2 | approx. $12.60 |
| Storage & Supporting Services | approx. $3.46 |
| EC2 Bastion | approx. $3.94 |
| **TOTAL** | **approx. $183.00/month** |

---

## Assumptions

- All services running 24/7 (730 hours/month)
- Aurora auto-pauses approx. 50% of the time (dev/test workload)
- Low traffic: approx. 1M WAF requests/month, approx. 1 ALB LCU average
- 10 GB NAT Gateway data transfer
- 5 GB total S3 storage across 7 buckets, 4 GB ECR storage across 4 repositories
- 2 GB/month CloudWatch log ingestion
- dummy-idp is deployed (this is a conditional resource — omitting it saves approx. $10/month)
- Single-AZ deployment (dev/test); production would require multi-AZ and higher costs

## Exclusions

The following are either free-tier, negligible, or usage-dependent and not included in the estimate:

- Data transfer costs between AZs and to internet (usage-dependent)
- S3 request costs — PUT, GET, LIST (negligible at dev/test scale)
- AWS Backup storage costs (depends on RDS/S3 snapshot retention and sizes)
- SSM Session Manager (free for basic usage)
- ACM certificates (free for public certificates)
- Service Discovery / Cloud Map namespace (approx. $0.10/namespace/month)
- Elastic IP (free when attached to NAT Gateway)
- Terraform/Terragrunt state storage — S3 bucket + DynamoDB table (negligible)
- Route53 DNS query costs ($0.40 per million queries — negligible at dev/test scale)

## Cost Optimization Notes

- **Aurora Serverless v2 auto-pause** (min 0 ACU) is the biggest cost saver for dev/test — compute drops to $0 when idle. With typical dev/test usage patterns, Aurora may be paused 50–80% of the time.
- **NAT Gateway** is the single largest fixed cost (approx. $34/month). Adding VPC endpoints for S3 and ECR can reduce data processing charges and potentially allow removing the NAT Gateway entirely if no other internet access is needed from private subnets.
- **Fargate Spot** reduces ECS costs by approx. 70% — vCPU drops from $0.0445 to $0.01335/hr, memory from $0.0049 to $0.00147/GB-hr. Suitable for non-production workloads where occasional task interruption is acceptable.
- **ARM/Graviton Fargate tasks** offer approx. 20% savings — vCPU drops from $0.0445 to $0.0356/hr, memory from $0.0049 to $0.00392/GB-hr. Requires ARM-compatible container images.
- **ARM + Spot combined** offers the deepest discount — vCPU at $0.01068/hr (76% savings), memory at $0.001176/GB-hr (76% savings).
- **Scheduled scaling**: For dev/test environments not used outside business hours, consider scaling ECS services to 0 at night and weekends. Running only 10 hours/day on weekdays (approx. 220 hours/month) would reduce Fargate costs by approx. 70%.
