variable  "profile" {
  description = "credential profile"
  type        = any
  default     = {}
}
variable "shared_credentials_files" {
  description = "shared credentials files"
  type        = any
  default     = {}
}
variable  "azs" {
  description = "aws_availability_zones"
  type        = any
  default     = {}
}
variable  "karpenter_azs" {
  description = "karpenter default nodepool aws_availability_zones"
  type        = any
  default     = {}
}
variable "eks_pod_subnet_ids" {
  description = "eks pod subnet ids"
  type        = any
  default     = {}
}
variable "cluster_name" {
  description = "cluster name"
  type        = any
  default     = {}
}
variable "cluster_endpoint" {
  description = "cluster endpoint"
  type        = any
  default     = {}
}
variable "cluster_version" {
  description = "cluster version"
  type        = any
  default     = {}
}
variable "oidc_provider_arn" {
  description = "oidc provider arn"
  type        = any
  default     = {}
}
variable "fargate_profiles" {
  description = "fargate profiles"
  type        = any
  default     = {}
}
variable "cluster_ca_certificate" {
  description = "cluster ca certificate"
  type        = any
  default     = {}
}
variable "cluster_primary_security_group_id" {
  description = "cluster primary security group id"
  type        = any
  default     = {}
}
variable "karpenter_version" {
  description = "karpenter version for install crd"
  type        = any
  default     = {}
}
variable "tags" {
  description = "tags"
  type        = any
  default     = {}
}