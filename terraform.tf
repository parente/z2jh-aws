provider "aws" {
  region = "us-east-1"
}

module "eks" {
  source  = "howdio/eks/aws"
  version = "0.6.0"

  name            = "jupyterhub"
  eks_version     = "1.12"
  node_ami_lookup = "amazon-eks-node-1.12-*"
  default_vpc     = true
}

resource "aws_ecr_repository" "hub_repo" {
  name = "k8s-hub"
}

resource "aws_ecr_repository" "user_repo" {
  name = "k8s-user"
}

output "hub_repo" {
  value = "${aws_ecr_repository.hub_repo.repository_url}"
}

output "user_repo" {
  value = "${aws_ecr_repository.user_repo.repository_url}"
}
