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
