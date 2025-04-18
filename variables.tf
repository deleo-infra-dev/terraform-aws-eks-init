# Profile
variable  "profile" {
  description = "credential profile"
  type        = string
  default     = "deleokr"
}
# Region
variable "region" {
  description = "aws region"
  type    = string
  default = "ap-northeast-2"
}
# Shared Credentials Files
variable "shared_credentials_files" {
  description = "shared credentials files"
  type        = list(string)
  default     = ["$HOME/.aws/credentials"]
}
# Availability Zones
variable  "azs" {
  description = "aws_availability_zones"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2b", "ap-northeast-2c"]
}
# EKS Pod Subnet IDs
variable "eks_pod_subnet_ids" {
  description = "eks pod subnet ids"
  type        = list(string)
   default     = ["subnet-xxxxxx1", "subnet-xxxxxx2", "subnet-xxxxxx3"]  # 각 가용영역에 대한 실제 서브넷 ID
}
# EKS Cluster Name
variable "cluster_name" {
  description = "cluster name"
  type        = string
  default     = "temp-eks"
}
# EKS Cluster Endpoint
variable "cluster_endpoint" {
  description = "cluster endpoint"
  type        = string
  default     = "https://test-eks.ap-northeast-2.eks.amazonaws.com"
}
# EKS Cluster Version
variable "cluster_version" {
  description = "cluster version"
  type        = string
  default     = "1.30"
}
# OIDC Provider ARN
variable "oidc_provider_arn" {
  description = "oidc provider arn"
  type        = string
  default     = "arn:aws:iam::123456789012:oidc-provider/oidc.eks.ap-northeast-2.amazonaws.com/id/12345678901234567890123456789012"
}

# Fargate Profiles
variable "fargate_profiles" {
  description = "fargate profiles"
  type        = any
  default     = {}
}
# Cluster CA Certificate
variable "cluster_ca_certificate" {
  description = "cluster ca certificate"
  type        = string
  default     = "LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSURGekNDQWYrZ0F3SUJBZ0lVSUdyWnE2dnZYeG9DbWRrRzM3UHVmdUNhUFZzd0RRWUpLb1pJaHZjTkFRRUwKQlFBd0d6RVpNQmNHQTFVRUF3d1FkR1Z6ZEM1bGVHRnRjR3hsTG1OdmJUQWVGdzB5TlRBME1EUXdNVE0wTURSYQpGdzB5TmpBME1EUXdNVE0wTURSYU1Cc3hHVEFYQmdOVkJBTU1FSFJsYzNRdVpYaGhiWEJzWlM1amIyMHdnZ0VpCk1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQkR3QXdnZ0VLQW9JQkFRQ3k1YnA3OGxzUTNSQlNYSGtqa3BMSUFrTnoKQTNrOUE1MHdBclQyQWoxU1dPOGwrbWNzMUl1cllsemJQRGRPVUJ5Q29tOUdWdWlidkIvNWI4V1VuVXdWTW1LYgpmL3VTM0JDMGkycWJpMUdLQmc1NC9CRU5NNysyak84OGpRVXovWW42a3QzcmNZcjVFU2YrSHFUb0t1d1NONXppCnVpOTRuMk1kblJHd1BxVGdkWG5RaFNCQ2NGQXlBNWxsZU1BVjBjdmd1VzFleCtiSlRnbUVBVDZ1UDRSa3VXTTEKTFVUZFJIOEdZZW9lQUtuY091ei9URnBVaHFMQXJIbHFoK0g0eHJ3UWVjcytGeklyY3M2eXJQbG5CV3pSc0dFagpFVGJIMzFleTZoWnFzQ3F4OG5pSmFlc2N6Tm0wZlR5ZWRXL2FpRDJtbVhZTXpTdmZZOTVlM3FFK0NpNjFBZ01CCkFBR2pVekJSTUIwR0ExVWREZ1FXQkJRajhhbXB3ajA1SDRJUGQvZ1AyQ1lrRzhkSFhUQWZCZ05WSFNNRUdEQVcKZ0JRajhhbXB3ajA1SDRJUGQvZ1AyQ1lrRzhkSFhUQVBCZ05WSFJNQkFmOEVCVEFEQVFIL01BMEdDU3FHU0liMwpEUUVCQ3dVQUE0SUJBUUNUWGpJM0ZjMmhvTnRDS2VUM3FEUUlvN3RwemNrOHRNWEtsZUR5bEI4NkkvcVEwNzNoCjErVzlzS2RJVmNqMkxDbVVhdnZqVWRGU0JRMlBZYUM0ZjJmekdMa09vZ0JtajNzOHd6RStQVmluRitrQVRpT1kKWXpFVWZqenlQV2FKVnNyRFF4OUNZS3R0Sjh2cDFFdjZlMFgzME9NOWxHZnEvQUU0aHUrTkZUTDJneXp4Njh1awpqS3pYejZjR01Ecy9ScmNkMFplenpUbnNLYnVpK2xXZmZLVGdVSXV1QWRzbnpQVnlKR0RMaDRmNTJRQWhrNS9MClhObW1jRkRMbGUrZVNSZUxneTdHRm5lK2ZEcjFIc2QyMlUzbkFMNnlKbS9adTFkZEZ0eDQ1cmNSbnpYZ2tMZTkKdi9TMmxMMHNFNnB4ZDJKOEJpcHdzN0FCWXFyNGhwTW1YSlRwCi0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K"
}
# Cluster Primary Security Group ID
variable "cluster_primary_security_group_id" {
  description = "cluster primary security group id"
  type        = string
  default     = "sg-00000000000000000"
}
# Karpenter Version
variable "karpenter_version" {
  description = "karpenter version for install crd"
  type        = string
  default     = "0.37.7"
}
# Tags
variable "tags" {
  description = "tags"
  type        = map(string)
  default     = {}

}
# Karpenter AMI Family
variable "karpenter_ami_family" {
  description = "AMI Family (%s_%s) for Karpenter EC2 worker nodes"
  type        = string
  default = "AL2"
}
# Karpenter Node Capacity Type
variable "karpenter_node_capacity_type" {
  description = "Karpenter Node Capacity Type"
  type        = list(string)
  default     = ["on-demand"]
}

# Karpenter Instance Families
variable "karpenter_instance_families" {
  description = "Karpenter Instance Families"
  type        = list(string)
  default     = ["c", "m", "r", "t", "x"]
}

# Karpenter Instance Sizes
variable "karpenter_instance_sizes" {
  description = "Karpenter Instance Sizes"
  type        = list(string)
  default     = ["xlarge", "2xlarge", "3xlarge", "4xlarge", "5xlarge", "6xlarge", "7xlarge", "8xlarge", "9xlarge", "10xlarge"]
}

# Karpenter Environment
variable "karpenter_env" {
  description = "Karpenter Environment"
  type        = string
  default     = "dev"
}

variable coreDNS-version {
    description = "CoreDNS version"
    type        = string
    default     = "v1.11.4-eksbuild.2"
}

variable "vpc-cni-version" {
    description = "VPC CNI version"
    type        = string
    default     = "v1.19.3-eksbuild.1"
}

variable "kube-proxy-version" {
    description = "Kube Proxy version"
    type        = string
    default     = "v1.30.9-eksbuild.3"
}
