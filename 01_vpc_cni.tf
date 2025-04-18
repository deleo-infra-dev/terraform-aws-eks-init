################################################################################
# VPC-CNI Custom Networking ENIConfig
################################################################################

resource "helm_release" "eni_config" {
  name       = "eni-config"
  namespace  = "kube-system"
  repository = "https://bedag.github.io/helm-charts/"
  chart      = "raw"
  version    = "2.0.0"
  values = [ templatefile("${path.module}/templates/eni_config.tftpl", {
    eni_configs = zipmap(var.azs, var.eks_pod_subnet_ids),
    securityGroups = [
      var.cluster_primary_security_group_id
    ]
  })]
}

################################################################################
# ENIConfig 상태 확인
################################################################################
resource "null_resource" "verify_eni_config" {
  provisioner "local-exec" {
    command = <<-EOT
      # kubeconfig 설정
      aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.region} --alias ${var.cluster_name}

      # ENIConfig 리소스 확인
      echo "ENIConfig 리소스 확인:"
      kubectl get eniconfigs

      # VPC CNI 환경 변수 설정 확인 (패턴 수정)
      echo "aws-node DaemonSet 환경 변수 확인:"
      kubectl describe daemonset aws-node -n kube-system | grep -A 10 "Environment:"

      # 또는 전체 환경 변수 출력
      echo "모든 환경 변수 출력:"
      kubectl describe daemonset aws-node -n kube-system
    EOT
  }

  depends_on = [
    helm_release.eni_config
  ]
}
