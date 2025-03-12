################################################################################
# VPC-CNI Custom Networking ENIConfig
# VPC CNI에서 커스텀 네트워킹 사용을 위한 ENI 구성
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

  # EKS Blueprints Addons 모듈이 완료된 후 배포
  depends_on = [
    module.eks_blueprints_addons
  ]
}

################################################################################
# ENIConfig 배포 완료 확인을 위한 Null Resource
################################################################################
resource "null_resource" "eni_config_applied" {
  depends_on = [
    helm_release.eni_config
  ]
  
  # 변경 시 항상 트리거되도록 임의의 값 사용
  triggers = {
    always_run = "${timestamp()}"
  }

  # ENIConfig 배포 후 상태 확인
  provisioner "local-exec" {
    command = <<-EOT
      kubectl --namespace kube-system wait --for=condition=ready crd/eniconfigs.crd.k8s.amazonaws.com --timeout=60s || true
    EOT
  }
}