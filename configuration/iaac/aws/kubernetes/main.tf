# aws --version
# aws eks --region us-east-1 update-kubeconfig --name in28minutes-cluster
# Uses default VPC and Subnet. Create Your Own VPC and Private Subnets for Prod Usage.
# terraform-backend-state-in28minutes-123
# AKIA4AHVNOD7OOO6T4KI


terraform {
  backend "s3" {
    bucket = "mybucket" # Will be overridden from build
    key    = "path/to/my/key" # Will be overridden from build
    region = "us-east-1"
  }
}

resource "aws_default_vpc" "default" {

}

data "aws_subnet_ids" "subnets" {
  vpc_id = aws_default_vpc.default.id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
 // load_config_file       = false
 // version                = "~> 1.9"
}

module "my-cluster" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "17.24.0"
  cluster_name    = "my-cluster"
  cluster_version = "1.24"
  subnets         = ["subnet-0b900a5420bbd4acf", "subnet-0d691af63605263b9", "subnet-09f0ff785ea9fbc41"] #CHANGE # Donot choose subnet from us-east-1e
  #subnets = data.aws_subnet_ids.subnets.ids
  vpc_id          = aws_default_vpc.default.id
  #vpc_id         = "vpc-1234556abcdef"

  node_groups = [
    {
      instance_type = "t2.micro"
      max_capacity  = 5
      desired_capacity = 3
      min_capacity  = 3
    }
  ]
}

data "aws_eks_cluster" "cluster" {
  name = module.my-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.my-cluster.cluster_id
}

resource "kubernetes_service_account" "example" {
  metadata {
    name = "terraform-example"
  }
  secret {
    name = "${kubernetes_secret.example.metadata.0.name}"
  }
  
}

resource "kubernetes_secret" "example" {
  metadata {
    annotations = {
      "kubernetes.io/service-account.name" = "terraform-example"
    }
  }
   type = "kubernetes.io/service-account-token"
}

# We will use ServiceAccount to connect to K8S Cluster in CI/CD mode
# ServiceAccount needs permissions to create deployments 
# and services in default namespace
resource "kubernetes_cluster_role_binding" "example" {
  metadata {
    name = "fabric8-rbac"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "terraform-example"
    namespace = "default"
  }
  
}

# Needed to set the default region
provider "aws" {
  region  = "us-east-1"
}
