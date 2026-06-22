resource "random_password" "database" {
  length  = 32
  special = false
}
resource "aws_db_subnet_group" "main" {
  name       = "nearby-${var.environment}"
  subnet_ids = values(aws_subnet.private)[*].id
}
resource "aws_db_instance" "postgres" {
  identifier                   = "nearby-${var.environment}"
  engine                       = "postgres"
  engine_version               = "17.5"
  instance_class               = "db.t4g.medium"
  allocated_storage            = 50
  max_allocated_storage        = 500
  storage_encrypted            = true
  db_name                      = "nearby_connect"
  username                     = "nearby_admin"
  password                     = random_password.database.result
  db_subnet_group_name         = aws_db_subnet_group.main.name
  vpc_security_group_ids       = [aws_security_group.database.id]
  multi_az                     = true
  backup_retention_period      = 14
  deletion_protection          = true
  skip_final_snapshot          = false
  final_snapshot_identifier    = "nearby-${var.environment}-final"
  performance_insights_enabled = true
}
resource "aws_elasticache_subnet_group" "main" {
  name       = "nearby-${var.environment}"
  subnet_ids = values(aws_subnet.private)[*].id
}
resource "random_password" "redis" {
  length  = 32
  special = false
}
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "nearby-${var.environment}"
  description                = "Nearby Connect cache and realtime fanout"
  engine                     = "redis"
  node_type                  = "cache.t4g.small"
  port                       = 6379
  parameter_group_name       = "default.redis7"
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [aws_security_group.redis.id]
  auth_token                 = random_password.redis.result
  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  automatic_failover_enabled = true
  multi_az_enabled           = true
  num_cache_clusters         = 2
  snapshot_retention_limit   = 7
}
