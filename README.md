# Microservice Cloud Monorepo

This repository contains a microservice architecture built on AWS ECS Fargate, Terraform, Docker Hub, Loki, and Grafana.

Services:
- `auth-api`
- `product-api`
- `gateway`
- `ecommerce`

Production architecture:
- ALB + ECS Fargate
- Tasks running in private subnets
- Cloud Map service discovery
- Application logs shipped to Loki through FireLens
- Correlation ID, user activity, and error tracking in Grafana
- Platform logs, ECS/ALB metrics, and alarms in CloudWatch
- Docker Hub image distribution

Deployment and infrastructure documentation:
- `terraform/README.md`

CI/CD workflow:
- `.github/workflows/build-and-deploy.yml`

Local development:
- `docker-compose.dev.yml`
- `docker-compose.yml`
