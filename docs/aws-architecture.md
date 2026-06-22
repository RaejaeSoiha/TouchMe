# AWS architecture

```mermaid
flowchart TB
  Internet --> ALB[Application Load Balancer + ACM]
  ALB --> API[ECS Fargate API service]
  ALB --> Admin[ECS Fargate admin service]
  API --> RDS[(Multi-AZ RDS PostgreSQL/PostGIS)]
  API --> Redis[(Multi-AZ ElastiCache Redis)]
  API --> S3[(Private encrypted S3)]
  S3 --> CF[CloudFront media distribution]
  API --> SM[Secrets Manager]
  API --> CW[CloudWatch logs and metrics]
  NAT[Per-AZ NAT gateways] --> Stripe
  NAT --> Push[FCM/APNs]
```

The ALB, NAT gateways, and ECS tasks span two availability zones. Only the ALB is internet-facing. ECS, RDS, and ElastiCache use private subnets and least-privilege security groups. RDS has encryption, Multi-AZ failover, deletion protection, performance insights, and 14-day backups. Redis uses TLS, an auth token, encryption at rest, failover, and snapshots. S3 blocks public access; CloudFront accesses objects with origin access control.

