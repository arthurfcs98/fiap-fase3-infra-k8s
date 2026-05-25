environment        = "prod"
cluster_name       = "fiap-fase3-eks"
kubernetes_version = "1.30"
vpc_cidr           = "10.20.0.0/16"

node_instance_types = ["t3.small"]
node_desired_size   = 2
node_min_size       = 1
node_max_size       = 3
