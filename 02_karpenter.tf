################################################################################
# Karpenter
################################################################################

locals {
  karpenter_default_resources = var.karpenter.default_node.resources_version == "v1"
    ? templatefile(".terraform/modules/eks_init/karpenter_v1.yaml.tftpl", {
        ami_alias    = try(var.karpenter.default_node.ami_alias, "al2023@latest")
        role_name    = module.eks_init.karpenter.node_iam_role_name
        cluster_name = var.cluster_name
        azs          = jsonencode(var.karpenter.default_node.azs)
      })
    : templatefile(".terraform/modules/eks_init/karpenter_v1beta1.yaml.tftpl", {
        ami_family   = try(var.karpenter.default_node.ami_family, "AL2")
        role_name    = module.eks_init.karpenter.node_iam_role_name
        cluster_name = var.cluster_name
        azs          = jsonencode(var.karpenter.default_node.azs)
      })
}

resource "helm_release" "karpenter_default_node_resources" {
  name       = "karpenter-default-node-resources"
  namespace  = "karpenter"
  repository = "https://bedag.github.io/helm-charts/"
  chart      = "raw"
  version    = "2.0.0"
  values = [local.karpenter_default_resources]
  depends_on = [
    module.eks_init
  ]
}

# Example deployment using the [pause image](https://www.ianlewis.org/en/almighty-pause-container)
resource "kubectl_manifest" "default_inflate_deploy" {
  yaml_body = <<-YAML
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: inflate
    spec:
      replicas: 2
      selector:
        matchLabels:
          app: inflate
      template:
        metadata:
          labels:
            app: inflate
        spec:
          terminationGracePeriodSeconds: 0
          affinity:
            podAntiAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
              - labelSelector:
                  matchExpressions:
                  - key: app
                    operator: In
                    values:
                    - inflate
                topologyKey: kubernetes.io/hostname
          containers:
            - name: inflate
              image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
              resources: {}
  YAML
  depends_on = [
    helm_release.karpenter_default_node_resources
  ]
}

resource "helm_release" "karpenter_crd" {
  name       = "karpenter-crd"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter-crd"
  version    = try(var.karpenter_crd.chart_version, "0.37.0")
  namespace  = "karpenter"
  wait       = true

  dynamic "set" {
    for_each = try(var.karpenter_crd.set, [])
    content {
      name  = set.value.name
      value = set.value.value
    }
  }
}