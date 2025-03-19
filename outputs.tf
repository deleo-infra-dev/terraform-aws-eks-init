# 모듈이 생성하는 리소스에 대한 출력 변수 정의
output "karpenter" {
  description = "Karpenter 헬름 릴리스 및 IRSA 속성 맵"
  value       = module.eks_init.karpenter
}

output "addon_status" {
  description = "EKS 애드온 상태 정보"
  value = {
    coredns    = module.eks_init.eks_addons["coredns"]
    vpc_cni    = module.eks_init.eks_addons["vpc-cni"]
    kube_proxy = module.eks_init.eks_addons["kube-proxy"]
  }
}

output "eni_config_status" {
  description = "ENI 구성 헬름 릴리스 상태"
  value = {
    name      = helm_release.eni_config.name
    namespace = helm_release.eni_config.namespace
    status    = helm_release.eni_config.status
  }
}