################################################################################
# IRSA for Karpenter
## - Karpenter 설치 시 필요한 IRSA 역할 생성 (Karpenter 설치 시 필요)
################################################################################

module "karpenter_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name                          = "karpenter-irsa-${var.cluster_name}"
  attach_karpenter_controller_policy = true # karpenter-controller policy 추가

  karpenter_controller_cluster_name = var.cluster_name # karpenter-controller cluster name 설정

  # karpenter-controller node iam role arn 설정
  karpenter_controller_node_iam_role_arns = [module.eks_init.karpenter.node_iam_role_arn]

  # oidc provider 설정 # - karpenter namespace service account 설정
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn   # OIDC Provider ARN 설정
      namespace_service_accounts = ["karpenter:karpenter"] # karpenter namespace service account 설정
    }
  }

  tags = var.tags
}