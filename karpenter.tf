################################################################################
# Karpenter
# This is used to install the Karpenter Helm chart
#-----------------------------------------------------------------------------
# Karpenter CRD
# This is used to install the Karpenter CRD
#-----------------------------------------------------------------------------
# Karpenter Default Node Pool
# This is used to create the default node pool for the Karpenter cluster
#-----------------------------------------------------------------------------
# Karpenter Default Node Resources
# This is used to create the default node resources for the Karpenter cluster
#-----------------------------------------------------------------------------
################################################################################
resource "helm_release" "karpenter_default_node_resources" {
  name       = "karpenter-default-node-resources"
  namespace  = "karpenter"
  repository = "https://bedag.github.io/helm-charts/"
  chart      = "raw"
  version    = "2.0.0"
  values = [
    <<-EOF
    resources:
    - apiVersion: karpenter.k8s.aws/v1beta1
      kind: EC2NodeClass
      metadata:
        name: default
      spec:
        amiFamily: AL2
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
              default: 'true'
              consolidation: 'true'
              critical: 'false'
              instance: m7i.xlarge
              capacity: on-demand
          spec:
            nodeClassRef:
              name: default
            requirements:
            - key: node.kubernetes.io/instance-type
              operator: In
              values: ["m7i.xlarge"]
            - key: karpenter.k8s.aws/instance-hypervisor
              operator: In
              values: ["nitro"]
            - key: topology.kubernetes.io/zone
              operator: In
              values: ${jsonencode(var.azs)}
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: "karpenter.sh/capacity-type" # If not included, the webhook for the AWS cloud provider will default to on-demand
              operator: In
              values: ["on-demand"]
            - key: kubernetes.io/os	
              operator: In	
              values:	["linux"]
        disruption:
          consolidationPolicy: WhenUnderutilized
          expireAfter: 4320h # 180 Days = 180 * 24 Hours
        # Karpenter provides the ability to specify a few additional Kubelet args.
        # These are all optional and provide support for additional customization and use cases.
        kubelet:
          maxPods: 672
    EOF
  ]
  depends_on = [
    null_resource.wait_for_addons # 기존 module.eks_init 대신 wait_for_addons를 사용하여 순환 참조 방지
  ]
}

################################################################################
# Karpenter Default Node Resources
# This is used to create the default node resources for the Karpenter cluster
################################################################################
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
              resources:
                requests:
                  cpu: "50m"
                  memory: "128Mi"
                limits:
                  cpu: "100m"
                  memory: "256Mi"

  YAML
  depends_on = [
    helm_release.karpenter_default_node_resources
  ]
}

################################################################################
# Karpenter CRD
# This is used to install the Karpenter CRD
################################################################################
resource "helm_release" "karpenter_crd" {
  name       = "karpenter-crd"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter-crd"
  version    = var.karpenter_version
  namespace  = "karpenter"
  wait       = true
}