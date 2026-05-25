data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "random_password" "grafana_admin" {
  length  = 16
  special = false
}

resource "aws_security_group" "observability" {
  name        = "${var.cluster_name}-observability-sg"
  description = "Grafana stack VM: ingress for UI, OTLP and Prom remote-write"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana UI"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "OTLP HTTP from VPC"
    from_port   = 4318
    to_port     = 4318
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "OTLP gRPC from VPC"
    from_port   = 4317
    to_port     = 4317
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Prometheus remote-write / scrape from VPC"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Loki push from VPC"
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-observability-sg" }
}

# IAM instance profile pré-criado no Academy
data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}

resource "aws_instance" "observability" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.observability.id]
  associate_public_ip_address = true
  iam_instance_profile        = data.aws_iam_instance_profile.lab.name
  key_name                    = "vockey"

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/files/user-data.sh", {
    grafana_admin_password = random_password.grafana_admin.result
    cluster_name           = var.cluster_name
  })

  tags = {
    Name = "${var.cluster_name}-observability"
  }
}
