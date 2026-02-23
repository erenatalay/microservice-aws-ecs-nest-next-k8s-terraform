# Microservice Cloud Monorepo (AWS ECS)

Bu proje **AWS ECS (Fargate) + Terraform** mimarisi kullanır.

## Servisler
- `auth-api`
- `product-api`
- `gateway`
- `ecommerce`

## Deploy
Terraform dosyaları:
- `terraform/`

Detaylı kurulum/deploy dokümanı:
- `terraform/README.md`

## CI/CD
GitHub Actions workflow:
- `.github/workflows/build-and-deploy.yml`

Akış:
1. Docker image'lar ECR'a push edilir.
2. Terraform `plan/apply` ile ECS servisleri güncellenir.

## Lokal Geliştirme
Lokal geliştirme için mevcut Docker Compose yapısı kullanılabilir:
- `docker-compose.dev.yml`
- `docker-compose.yml`
