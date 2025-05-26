
################################################################################
# locals
################################################################################
locals {

  # ------------------------------------------------------------ #

  region                   = var.region                   # AWS Region
  profile                  = var.profile                  # AWS Profile
  shared_credentials_files = var.shared_credentials_files # AWS Shared Credentials Files

  # ------------------------------------------------------------ #

  eks_addons_ready = true # EKS Addons 준비 여부

  # ------------------------------------------------------------ #

  cluster_name      = var.cluster_name      # EKS Cluster Name 
  cluster_endpoint  = var.cluster_endpoint  # EKS Cluster Endpoint 
  cluster_version   = var.cluster_version   # EKS Cluster Version
  oidc_provider_arn = var.oidc_provider_arn # OIDC Provider ARN 

  # ------------------------------------------------------------ #
  # EKS Addons Version (EKS Addons 버전 설정 - 별도 정의)
  # ------------------------------------------------------------ #

  coredns_version        = var.coredns_version        # CoreDNS Version
  vpc_cni_version        = var.vpc_cni_version        # VPC CNI Version
  kube_proxy_version     = var.kube_proxy_version     # Kube Proxy Version
  karpenter_version      = var.karpenter_version      # Karpenter Version
  metrics_server_version = var.metrics_server_version # Metrics Server Version


}