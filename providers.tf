################################################################################
# AWS 프로바이더 설정
# us-east-1 리전용 별칭 프로바이더 (ECR Public 토큰용)
################################################################################
provider "aws" {
  alias = "virginia"
  region = "us-east-1"
  
  # 상위 모듈에서 제공하는 자격 증명 사용
  shared_credentials_files = var.shared_credentials_files
  profile                  = var.profile
}

################################################################################
# EKS 클러스터 인증 데이터
################################################################################
data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

################################################################################
# Kubernetes 프로바이더 설정
################################################################################
provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}

################################################################################
# Kubectl 프로바이더 설정
################################################################################
provider "kubectl" {
  apply_retry_count      = 5
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.this.token
}

################################################################################
# Helm 프로바이더 설정
################################################################################
provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

################################################################################
# Terraform 버전 및 요구 프로바이더
################################################################################
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