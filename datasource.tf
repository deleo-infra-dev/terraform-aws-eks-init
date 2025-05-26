################################################################################
# EKS Cluster Auth Data (aws_eks_cluster_auth)
## - aws_eks_cluster_auth: EKS Cluster Auth 조회
################################################################################
data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

################################################################################
# AWS Account ID Data (aws_caller_identity)
## - aws_caller_identity: AWS Account ID 조회
################################################################################
data "aws_caller_identity" "current" {} # AWS Account ID


################################################################################
# AWS Region Data (aws_region)
## - aws_region: AWS Region 조회
################################################################################
data "aws_region" "current" {}

