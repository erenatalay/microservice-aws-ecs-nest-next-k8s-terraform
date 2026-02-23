# AWS ECS + Terraform

Bu klasör **AWS ECS (Fargate)** üzerinde çalışan yapı için düzenlendi.

Kurulan bileşenler:
- VPC + 2 public subnet
- Internet Gateway + route table
- Application Load Balancer (ALB)
- ECS Cluster (Fargate)
- Cloud Map service discovery (`auth-api.svc.local`, vb.)
- CloudWatch log group
- IAM task/execution role
- 4 ECS service:
  - `auth-api` (3001)
  - `product-api` (3002)
  - `gateway` (4000)
  - `ecommerce` (3000)

ALB routing:
- `/api*` ve `/graphql*` -> `gateway`
- diğer tüm yollar -> `ecommerce`

## Gereksinimler

- Terraform `>= 1.5`
- AWS hesabı ve yeterli IAM izinleri
- İmajların bir container registry’de (tercihen ECR) hazır olması

## Hızlı Kullanım

```bash
cd terraform
terraform init
terraform plan -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

## Önemli Değişkenler

`environments/*.tfvars` içinde mutlaka doldur:
- `auth_api_image`
- `product_api_image`
- `gateway_image`
- `ecommerce_image`
- `auth_database_url`
- `product_database_url`
- `jwt_secret`

Opsiyonel:
- `public_app_url`
- `next_public_graphql_url`

Boş bırakılırsa Terraform otomatik ALB DNS’ini kullanır.

## Örnek Deploy Akışı

1. ECR repository’lerine image push et.
2. `environments/dev.tfvars` içindeki image URI’larını güncelle.
3. DB URL ve JWT secret değerlerini gir.
4. `terraform apply` çalıştır.
5. Çıktıdaki `alb_dns_name` veya `public_app_url` ile uygulamaya eriş.

## Notlar

- Bu yapı minimum çalışan ECS/Fargate altyapısıdır.
- Production için öneriler:
  - HTTPS listener + ACM sertifikası
  - WAF
  - RDS/Aurora + Secrets Manager
  - ECS autoscaling
  - Private subnet + NAT
