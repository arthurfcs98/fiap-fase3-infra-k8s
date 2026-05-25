# VPC Endpoints para recursos que Lambdas em VPC precisam acessar.
#
# Sem NAT Gateway (decisão blitz pra economizar ~$32/mês), Lambdas em VPC
# não têm internet — então precisam de Interface VPC Endpoints para os
# serviços AWS que consomem (Secrets Manager).
#
# Custo: ~$0.01/h por endpoint × 2 AZ = ~$0.02/h × 24h = ~$0.50/dia.

resource "aws_security_group" "vpce" {
  name        = "${var.cluster_name}-vpce-sg"
  description = "Allow HTTPS from VPC to VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.cluster_name}-vpce-sg" }
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.public[*].id
  security_group_ids  = [aws_security_group.vpce.id]
  private_dns_enabled = true

  tags = { Name = "${var.cluster_name}-vpce-secretsmanager" }
}
