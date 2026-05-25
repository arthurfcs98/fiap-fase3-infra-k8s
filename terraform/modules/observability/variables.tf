variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type        = string
  description = "Subnet pública onde a EC2 vai rodar"
}

variable "vpc_cidr" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "cluster_name" {
  type    = string
  default = "fiap-fase3-eks"
}
