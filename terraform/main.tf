provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

resource "aws_vpc" "eks_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "eks-vpc"
    Environment  = var.env
    Project = var.project
  }
}

resource "aws_subnet" "public_subnets" {
  count                   = var.pub_subnet_count
  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = element(var.public_subnets, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.cluster_name}-public-${count.index + 1}"
    Environment  = var.env
    Poject = var.project
    "kubernetes.io/cluster/kafka-project" = "owned"
    "kubernetes.io/role/elb"               = 1
  }

  depends_on = [aws_vpc.eks_vpc]
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.eks_vpc.id
  tags = {
    Name =  "${var.cluster_name}-igw"
    Environment  = var.env
    Project = var.project
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
  depends_on = [aws_vpc.eks_vpc]
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
    Environment  = var.env
    Project = var.project
  }
}

resource "aws_route_table_association" "public_route_association" {
  count          = var.pub_subnet_count
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name = var.cluster_name
  cluster_version = "1.34"
 
  cluster_endpoint_public_access = true
  enable_cluster_creator_admin_permissions = true	

  cluster_upgrade_policy = {
    support_type = "STANDARD"
  }

  vpc_id     = aws_vpc.eks_vpc.id
  subnet_ids = aws_subnet.public_subnets[*].id

  eks_managed_node_groups = {
    nodes = {
      name = "${var.cluster_name}-ng"
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 2
      desired_size   = 1

      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      tags = {
      	Name    = "${var.cluster_name}-node"
      	Environment = var.env
      	Terraform   = "true"
      	Project = var.project
      }
    }
  }

  tags = {
    Environment = var.env
    Terraform   = "true"
    Project     = var.project
  }

  cluster_security_group_tags = {
    Name    = "${var.cluster_name}-cluster-sg"
    Environment     = var.env
    Project = var.project
  }
}

resource "null_resource" "k8s_config" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region $REGION --name $CLUSTER"
    environment = {
        REGION = var.region
        CLUSTER = var.cluster_name
    }
  }
  depends_on = [module.eks]
}
