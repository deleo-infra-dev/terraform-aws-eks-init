################################################################################
# VPC-CNI Custom Networking ENIConfig
################################################################################

resource "helm_release" "eni_config" {
  name       = "eni-config"
  namespace  = "kube-system"
  repository = "https://bedag.github.io/helm-charts/"
  chart      = "raw"
  version    = "2.0.0"

  # ENI 구성 템플릿 적용
  values = [templatefile("${path.module}/eni_config.tftpl", {
    # 가용 영역별 ENI 구성 매핑
    eni_configs = zipmap(var.azs, var.eks_pod_subnet_ids),
    # 보안 그룹 구성
    securityGroups = [
      var.cluster_primary_security_group_id
    ]
  })]
}
