################################################################################
# AWS Provider
# - Default Region: data.aws_region.current.name (ap-northeast-2)
################################################################################
provider "aws" {
  region                   = var.region
  profile                  = var.profile
  shared_credentials_files = var.shared_credentials_files
}

################################################################################
# Kubernetes Provider
# - EKS Cluster Endpoint: var.cluster_endpoint
# - EKS Cluster CA Certificate: var.cluster_ca_certificate
# - EKS Cluster Auth Token: data.aws_eks_cluster_auth.this.token
################################################################################
provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}

################################################################################
# Kubectl Provider
# - EKS Cluster Endpoint: var.cluster_endpoint
# - EKS Cluster CA Certificate: var.cluster_ca_certificate
# - EKS Cluster Auth Token: data.aws_eks_cluster_auth.this.token
################################################################################
provider "kubectl" {
  apply_retry_count      = 5
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  load_config_file       = false
  token                  = data.aws_eks_cluster_auth.this.token
}

################################################################################
# Helm Provider
# - EKS Cluster Endpoint: var.cluster_endpoint
# - EKS Cluster CA Certificate: var.cluster_ca_certificate
# - EKS Cluster Auth Token: data.aws_eks_cluster_auth.this.token
################################################################################
provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}