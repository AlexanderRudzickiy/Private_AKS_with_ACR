variable "public_cert_data" {
  type        = string
  description = "Public certificate data"
  sensitive   = true
}

variable "admin_password" {
  type = string
  description = "DevOps VM admin password"
  sensitive = true
}