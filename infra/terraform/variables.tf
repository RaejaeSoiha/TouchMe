variable "aws_region" {
  type    = string
  default = "us-west-2"
}
variable "environment" {
  type    = string
  default = "production"
}
variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}
variable "availability_zones" {
  type    = list(string)
  default = ["us-west-2a", "us-west-2b"]
}
variable "api_image" {
  type = string
}
variable "admin_image" {
  type = string
}
variable "domain_name" {
  type = string
}
variable "certificate_arn" {
  type = string
}
variable "jwt_access_secret" {
  type      = string
  sensitive = true
}
variable "jwt_refresh_secret" {
  type      = string
  sensitive = true
}
variable "stripe_secret_key" {
  type      = string
  sensitive = true
}
variable "stripe_webhook_secret" {
  type      = string
  sensitive = true
}
variable "stripe_premium_price_id" {
  type      = string
  sensitive = true
}
variable "google_client_id" {
  type      = string
  sensitive = true
}
variable "apple_client_id" {
  type      = string
  sensitive = true
}
variable "smtp_host" {
  type = string
}
variable "smtp_port" {
  type    = number
  default = 587
}
variable "smtp_user" {
  type      = string
  sensitive = true
}
variable "smtp_password" {
  type      = string
  sensitive = true
}
variable "smtp_from" {
  type = string
}
variable "firebase_project_id" {
  type = string
}
variable "firebase_client_email" {
  type      = string
  sensitive = true
}
variable "firebase_private_key" {
  type      = string
  sensitive = true
}
variable "api_desired_count" {
  type    = number
  default = 2
}
