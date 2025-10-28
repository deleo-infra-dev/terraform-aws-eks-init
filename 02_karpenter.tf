################################################################################
# Karpenter
################################################################################

locals {
  karpenter_default_resources = var.karpenter.default_node.resources_version == "v1" ? <<-YAML : <<-YAML
    resources:
    - apiVersion: karpenter.k8s.aws/v1
      kind: EC2NodeClass
      metadata:
        name: default
      spec:
        kubelet:
          maxPods: 155
          systemReserved:
            cpu: "100m"
            memory: "128Mi"
            ephemeral-storage: "1Gi"
          kubeReserved:
            cpu: "70m"
            memory: "574Mi"
            ephemeral-storage: "1Gi"
          evictionHard:
            memory.available: "4%"
            nodefs.available: "10%"
            nodefs.inodesFree: "5%"
          evictionSoft:
            memory.available: "8%"
            nodefs.available: "15%"
            nodefs.inodesFree: "15%"
          evictionSoftGracePeriod:
            memory.available: "60s"
            nodefs.available: "90s"
            nodefs.inodesFree: "120s"
          imageGCHighThresholdPercent: 85
          imageGCLowThresholdPercent: 75
        amiSelectorTerms:
        - alias: ${try(var.karpenter.default_node.ami_alias, "al2023@latest")}
        role: ${module.eks_init.karpenter.node_iam_role_name}
        subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
        securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
        tags:
          karpenter.sh/discovery: ${var.cluster_name}
    - apiVersion: karpenter.sh/v1
      kind: NodePool
      metadata:
        name: default
      spec:
        template:
          metadata:
            labels:
              default: "true"
              node: default
              consolidation: "true"
              critical: "false"
              capacity: on-demand
              con: "true"
              cri: "false"
              cap: ond
          spec:
            nodeClassRef:
              group: karpenter.k8s.aws
              kind: EC2NodeClass
              name: default
            requirements:
            - key: karpenter.k8s.aws/instance-family
              operator: In
              values: ["m7i","m7i-flex"]
            - key: karpenter.k8s.aws/instance-hypervisor
              operator: In
              values: ["nitro"]
            - key: topology.kubernetes.io/zone
              operator: In
              values: ${jsonencode(var.karpenter.default_node.azs)}
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
            expireAfter: 4320h
        disruption:
          consolidationPolicy: WhenEmptyOrUnderutilized
          consolidateAfter: 0s
          budgets:
          - nodes: 10%
    YAML
    resources:
    - apiVersion: karpenter.k8s.aws/v1beta1
      kind: EC2NodeClass
      metadata:
        name: default
      spec:
        amiFamily: ${try(var.karpenter.default_node.ami_family, "AL2")}
        role: ${module.eks_init.karpenter.node_iam_role_name}
        subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
        securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
        tags:
          karpenter.sh/discovery: ${var.cluster_name}
    - apiVersion: karpenter.sh/v1beta1
      kind: NodePool
      metadata:
        name: default
      spec:
        template:
          metadata:
            labels:
              default: "true"
              node: default
              consolidation: "true"
              critical: "false"
              capacity: on-demand
              con: "true"
              cri: "false"
              cap: ond
          spec:
            nodeClassRef:
              name: default
            requirements:
            - key: karpenter.k8s.aws/instance-family
              operator: In
              values: ["m7i","m7i-flex"]
            - key: karpenter.k8s.aws/instance-hypervisor
              operator: In
              values: ["nitro"]
            - key: topology.kubernetes.io/zone
              operator: In
              values: ${jsonencode(var.karpenter.default_node.azs)}
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["on-demand"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
            kubelet:
              maxPods: 288
        disruption:
          consolidationPolicy: WhenUnderutilized
          expireAfter: 4320h
  YAML
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