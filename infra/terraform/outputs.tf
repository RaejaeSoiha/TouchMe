output "load_balancer_dns" {
  value = aws_lb.main.dns_name
}
output "media_domain" {
  value = aws_cloudfront_distribution.media.domain_name
}
output "media_bucket" {
  value = aws_s3_bucket.media.id
}
output "ecs_cluster" {
  value = aws_ecs_cluster.main.name
}
output "api_ecr_repository" {
  value = aws_ecr_repository.api.repository_url
}
output "admin_ecr_repository" {
  value = aws_ecr_repository.admin.repository_url
}
output "runtime_secret_arn" {
  value     = aws_secretsmanager_secret.runtime.arn
  sensitive = true
}
