# AWS ECS + Terraform + Loki/Grafana

This directory provisions a production-only AWS ECS Fargate architecture with Docker Hub, Loki, and Grafana.

Main components:
- Public and private subnets across 2 availability zones
- NAT Gateway for outbound traffic from private ECS tasks
- Application Load Balancer
- ECS cluster and application services
- Cloud Map service discovery
- ECS autoscaling
- ALB access logs (S3)
- S3 storage for Loki
- EFS persistence for Grafana
- Platform logs, ECS/ALB metrics, and alarms in CloudWatch

Services:
- `auth-api`
- `product-api`
- `gateway`
- `ecommerce`
- `loki`
- `grafana`

Observability model:
- Application logs flow to Loki through `awsfirelens`
- Each request log includes `correlationId`, `userId`, `statusCode`, `durationMs`, and `outcome`
- Grafana is exposed under `/grafana` with Loki as the log datasource
- CloudWatch is used for platform logs plus ECS and ALB metrics

Required variables:
- `auth_database_url`
- `product_database_url`
- `jwt_secret`
- `grafana_admin_password`
- `jwt_refresh_secret` (optional, falls back to `jwt_secret` when empty)
- `dockerhub_repository_credentials_secret_arn` (only if Docker Hub images are private)

Database note:
- Terraform does not create databases in this setup
- The services connect to your existing databases using `AUTH_DATABASE_URL` and `PRODUCT_DATABASE_URL`
- Database name, host, username, and password come entirely from the URLs you provide

Quick start:

```bash
cd terraform
terraform init
terraform plan -var-file=environments/production.tfvars -var="grafana_admin_password=CHANGE_ME"
terraform apply -var-file=environments/production.tfvars -var="grafana_admin_password=CHANGE_ME"
```

GitHub Actions note:
- The workflow stores Terraform state in a persistent AWS S3 backend
- Deterministic resources left behind by an interrupted first deploy are imported automatically when possible
- This prevents recurring `already exists` errors on later workflow runs

Log inspection:
- Open the `grafana_url` Terraform output
- In Grafana Explore, select the Loki datasource
- Use this LogQL query for a correlation ID:

```logql
{service=~"auth-api|product-api|gateway|ecommerce"} | json | correlationId="REPLACE_WITH_CORRELATION_ID"
```

- For a specific user:

```logql
{service=~"auth-api|product-api|gateway"} | json | userId="REPLACE_WITH_USER_ID"
```

- For recent failures:

```logql
{service=~"auth-api|product-api|gateway|ecommerce"} | json | outcome="error"
```

Important notes:
- Loki retention is controlled by `loki_retention_period`, while S3 object retention is controlled by `loki_s3_retention_days`
- Grafana state is persisted on EFS, and the datasource is bootstrapped by Terraform
- Application logs should now be inspected in Grafana Loki instead of CloudWatch Logs Insights
