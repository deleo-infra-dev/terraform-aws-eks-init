################################################################################
# VPC CNI IRSA
################################################################################
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name             = "vpc-cni-irsa-${var.cluster_name}"
  attach_vpc_cni_policy = true # vpc-cni policy 추가
  vpc_cni_enable_ipv4   = true # vpc-cni ipv4 활성화

  # oidc provider 설정 # - kube-system:aws-node namespace service account 설정 #
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn    # OIDC Provider ARN 설정
      namespace_service_accounts = ["kube-system:aws-node"] # kube-system:aws-node namespace service account 설정
    }
  }

  tags = var.tags
}