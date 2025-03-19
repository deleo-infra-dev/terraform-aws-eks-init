################################################################################
# 프로바이더 설정
################################################################################

# EKS 클러스터 인증 데이터 소스
data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

# Karpenter 아티팩트가 호스팅되는 퍼블릭 ECR에 필요
provider "aws" {
  shared_credentials_files = var.shared_credentials_files
  profile                  = var.profile
  region                   = "us-east-1"
  alias                    = "virginia"
}

# 쿠버네티스 프로바이더 설정
provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}

# kubectl 프로바이더 설정
provider "kubectl" {
  apply_retry_count      = 5
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.this.token
}

# Helm 프로바이더 설정
provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# 테라폼 설정
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.47"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9"
    }
  }
}