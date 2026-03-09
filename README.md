# Microservice Cloud Monorepo

Bu repo AWS ECS Fargate, Terraform, Docker Hub, Loki ve Grafana tabanli mikroservis yapisini icerir.

Servisler:
- `auth-api`
- `product-api`
- `gateway`
- `ecommerce`

Uretim mimarisi:
- ALB + ECS Fargate
- Private subnet uzerinde calisan task'lar
- Cloud Map service discovery
- FireLens ile Loki'ye akan uygulama loglari
- Grafana uzerinden correlation id, kullanici ve hata takibi
- CloudWatch uzerinde platform loglari, ECS/ALB metric ve alarm takibi
- Docker Hub image dagitimi

Deploy ve altyapi dokumani:
- `terraform/README.md`

CI/CD workflow:
- `.github/workflows/build-and-deploy.yml`

Lokal gelistirme:
- `docker-compose.dev.yml`
- `docker-compose.yml`
