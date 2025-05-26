################################################################################
# AWS Region
################################################################################
variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

################################################################################
# AWS Profile
################################################################################
variable "profile" {
  description = "AWS credential profile"
  type        = string
  default     = "deleoec"
}

################################################################################
# AWS Shared Credentials Files
################################################################################
variable "shared_credentials_files" {
  description = "AWS shared credentials files"
  type        = list(string)
  default     = ["~/.aws/credentials"]
}

################################################################################
# AWS Availability Zones
################################################################################
variable "azs" {
  description = "AWS availability zones"
  type        = list(string)
  default     = []
}

################################################################################
# EKS Pod Subnet IDs
################################################################################
variable "eks_pod_subnet_ids" {
  description = "EKS Pod Subnet IDs"
  type        = list(string)
  default     = []
}

################################################################################
# EKS Cluster
################################################################################
variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

################################################################################
# EKS Cluster Endpoint
################################################################################
variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

################################################################################
# EKS Cluster Version
################################################################################
variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
}

################################################################################
# OIDC Provider ARN
################################################################################
variable "oidc_provider_arn" {
  description = "OIDC provider ARN"
  type        = string
}

################################################################################
# Fargate Profiles
################################################################################
variable "fargate_profiles" {
  description = "Fargate profiles"
  type        = map(any)
  default     = {}
}

################################################################################
# EKS Cluster CA Certificate
################################################################################
variable "cluster_ca_certificate" {
  description = "EKS cluster CA certificate"
  type        = string
}

################################################################################
# EKS Cluster Primary Security Group ID
################################################################################
variable "cluster_primary_security_group_id" {
  description = "EKS cluster primary security group ID"
  type        = string
}

################################################################################
# Karpenter Version
################################################################################
variable "karpenter_version" {
  description = "Karpenter version for install CRD"
  type        = string
  default     = "0.37.0"
}

################################################################################
# Tags
################################################################################
variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}

################################################################################
# CoreDNS Version
################################################################################
variable "coredns_version" {
  description = "CoreDNS version"
  type        = string
  default     = "v1.11.4-eksbuild.2"
}

################################################################################
# VPC CNI Version
################################################################################
variable "vpc_cni_version" {
  description = "VPC CNI version"
  type        = string
  default     = "v1.19.3-eksbuild.1"
}

################################################################################
# Kube Proxy Version
################################################################################
variable "kube_proxy_version" {
  description = "Kube Proxy version"
  type        = string
  default     = "v1.19.3-eksbuild.1"
}

################################################################################
# Metrics Server Version
################################################################################
variable "metrics_server_version" {
  description = "Metrics Server version"
  type        = string
  default     = "v1.19.3-eksbuild.1"
}
