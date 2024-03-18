################################################################################
# Karpenter
################################################################################

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2
      role: ${var.karpenter_node_iam_role_name}
      subnetSelectorTerms:
      - tags:
          karpenter.sh/discovery: ${var.cluster_name}
      securityGroupSelectorTerms:
      - tags:
          karpenter.sh/discovery: ${var.cluster_name}
      tags:
        karpenter.sh/discovery: ${var.cluster_name}
  YAML

  depends_on = [
    module.eks_init
  ]
}

resource "kubectl_manifest" "karpenter_node_pool_default" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          nodeClassRef:
            name: default
          requirements:
          - key: node.kubernetes.io/instance-type
            operator: In
            values: ["m6i.large"]
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
      # Resource limits constrain the total size of the cluster.
      # Limits prevent Karpenter from creating new instances once the limit is exceeded.
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenUnderutilized
        expireAfter: 4320h # 180 Days = 180 * 24 Hours
      # Karpenter provides the ability to specify a few additional Kubelet args.
      # These are all optional and provide support for additional customization and use cases.
      kubelet:
        maxPods: 288
  YAML

  depends_on = [
    module.eks_init
  ]
}

# Example deployment using the [pause image](https://www.ianlewis.org/en/almighty-pause-container)
resource "kubectl_manifest" "karpenter_node_init_deploy" {
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
    kubectl_manifest.karpenter_node_template,
    kubectl_manifest.karpenter_provisioner_default
  ]
}