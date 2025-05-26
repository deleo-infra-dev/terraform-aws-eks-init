################################################################################
# VPC-CNI Custom Networking ENIConfig (VPC CNI 설치 시 필요)
################################################################################

resource "helm_release" "eni_config" {
  name       = "eni-config"
  namespace  = "kube-system"
  repository = "https://bedag.github.io/helm-charts/"
  chart      = "raw"
  version    = "2.0.0"
  values = [templatefile("${path.module}/eni_config.tftpl", {
    eni_configs = zipmap(var.azs, var.eks_pod_subnet_ids),
    securityGroups = [
      var.cluster_primary_security_group_id
    ]
  })]

  # define the dependencies (module.eks_init 자기참조 방지)
  depends_on = [module.eks_init]
} # eni_config (end)