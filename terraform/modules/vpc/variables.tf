variable "vpc_cidr" {
  type        = string
  description = "CIDR block da VPC"
}

variable "cluster_name" {
  type        = string
  description = "Nome do cluster (usado em tags)"
}

variable "region" {
  type        = string
  description = "AWS region (informativo)"
}
