terraform {
  backend "s3" {
    bucket         = "fiap-fase3-tfstate-235841326345"
    key            = "infra-k8s/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "fiap-fase3-tflock"
    encrypt        = true
  }
}
