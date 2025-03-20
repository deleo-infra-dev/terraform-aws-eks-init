
################################################################################
# Karpenter 관련 정보
################################################################################
output "karpenter" {
  description = "Karpenter 관련 정보"
  value = {
    node_iam_role_name = local.karpenter_node_role_name
    node_iam_role_arn  = local.karpenter_node_role_arn
    instance_profile_name = local.karpenter_instance_profile_name
    helm_release = module.eks_blueprints_addons.karpenter
  }
}

################################################################################
# EKS 애드온 상태 정보
################################################################################
output "addon_status" {
  description = "EKS 애드온 상태 정보"
  value = {
    coredns    = module.eks_blueprints_addons.eks_addons["coredns"]
    vpc_cni    = module.eks_blueprints_addons.eks_addons["vpc-cni"]
    kube_proxy = module.eks_blueprints_addons.eks_addons["kube-proxy"]
  }
}


################################################################################
# ENI 구성 헬름 릴리스 상태
################################################################################
output "eni_config_status" {
  description = "ENI 구성 헬름 릴리스 상태"
  value = {
    name      = helm_release.eni_config.name
    namespace = helm_release.eni_config.namespace
    status    = helm_release.eni_config.status
  }
}