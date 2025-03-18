variable "profile" {
  description = "credential profile"
  type        = string
}

variable "shared_credentials_files" {
  description = "shared credentials files"
  type        = list(string)
  default     = []
}

variable "azs" {
  description = "aws_availability_zones"
  type        = list(string)
}

variable "eks_pod_subnet_ids" {
  description = "eks pod subnet ids"
  type        = list(string)
}

variable "cluster_name" {
  description = "cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "cluster endpoint"
  type        = string
}

variable "cluster_version" {
  description = "cluster version"
  type        = string
}

variable "oidc_provider_arn" {
  description = "oidc provider arn"
  type        = string
}



variable "cluster_ca_certificate" {
  description = "cluster ca certificate"
  type        = string
}

variable "cluster_primary_security_group_id" {
  description = "cluster primary security group id"
  type        = string
}

variable "karpenter_version" {
  description = "karpenter version for install crd"
  type        = string
}

variable "tags" {
  description = "tags"
  type        = map(string)
  default     = {}
}

variable "account_id" {
  description = "AWS 계정 ID"
  type        = string
}


variable "create_delay_dependencies" {
  description = "List of dependencies to wait for before creating addons"
  type        = list(string)
  default     = []
}



