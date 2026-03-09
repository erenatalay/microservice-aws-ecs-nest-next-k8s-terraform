# AWS ECS + Terraform + Loki/Grafana

Bu klasor AWS ECS Fargate, Docker Hub, Loki ve Grafana tabanli production mimarisini kurar.

Kurulan ana bilesenler:
- 2 AZ uzerinde public ve private subnet yapisi
- NAT Gateway ile private ECS task cikisi
- Application Load Balancer
- ECS Cluster ve uygulama servisleri
- Cloud Map service discovery
- ECS autoscaling
- ALB access logs (S3)
- Loki icin S3 storage
- Grafana icin EFS persistence
- CloudWatch uzerinde platform loglari, ECS/ALB metric ve alarm'lar

Servisler:
- `auth-api`
- `product-api`
- `gateway`
- `ecommerce`
- `loki`
- `grafana`

Izlenebilirlik modeli:
- Uygulama loglari `awsfirelens` ile Loki'ye akar
- Her request logunda `correlationId`, `userId`, `statusCode`, `durationMs`, `outcome` bulunur
- Grafana `/grafana` altindan Loki datasource ile acilir
- CloudWatch sadece platform loglari, ALB metrikleri ve ECS metrikleri icin kullanilir

Gerekli degiskenler:
- `auth_database_url`
- `product_database_url`
- `jwt_secret`
- `grafana_admin_password`
- `jwt_refresh_secret` (opsiyonel, bos ise `jwt_secret` kullanilir)
- `dockerhub_repository_credentials_secret_arn` (Docker Hub private image kullaniliyorsa)

Hizli kullanim:

```bash
cd terraform
terraform init
terraform plan -var-file=environments/production.tfvars -var="grafana_admin_password=CHANGE_ME"
terraform apply -var-file=environments/production.tfvars -var="grafana_admin_password=CHANGE_ME"
```

Log takibi:
- `grafana_url` output'unu ac
- Explore ekraninda Loki datasource sec
- Correlation id icin su LogQL'i kullan:

```logql
{service=~"auth-api|product-api|gateway|ecommerce"} | json | correlationId="REPLACE_WITH_CORRELATION_ID"
```

- Belirli bir kullanici icin:

```logql
{service=~"auth-api|product-api|gateway"} | json | userId="REPLACE_WITH_USER_ID"
```

- Son hatalar icin:

```logql
{service=~"auth-api|product-api|gateway|ecommerce"} | json | outcome="error"
```

Onemli notlar:
- Loki retention ayari `loki_retention_period`, S3 saklama suresi `loki_s3_retention_days` ile yonetilir
- Grafana state'i EFS'te tutulur; datasource tanimi Terraform tarafinda bootstrap edilir
- Uygulama loglari artik CloudWatch Logs Insights yerine Grafana Loki uzerinden takip edilmelidir
