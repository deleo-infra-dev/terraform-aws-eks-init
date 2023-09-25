################################################################################
# Karpenter
################################################################################

resource "kubectl_manifest" "karpenter_node_template" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1alpha1
    kind: AWSNodeTemplate
    metadata:
      name: default
    spec:
      subnetSelector:
        karpenter.sh/discovery: ${var.cluster_name}
      securityGroupSelector:
        karpenter.sh/discovery: ${var.cluster_name}
      instanceProfile: ${module.eks_init.karpenter.node_instance_profile_name}
      tags:
        karpenter.sh/discovery: ${var.cluster_name}
  YAML

  depends_on = [
    module.eks_init
  ]
}

resource "kubectl_manifest" "karpenter_provisioner_default" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1alpha5
    kind: Provisioner
    metadata:
      name: default
    spec:
      requirements:
        - key: "node.kubernetes.io/instance-type"
          operator: In
          values: ["t3a.small"]
        - key: "karpenter.k8s.aws/instance-hypervisor"
          operator: In
          values: ["nitro"]
        - key: "topology.kubernetes.io/zone"
          operator: In
          values: ${jsonencode(var.azs)}
        - key: "kubernetes.io/arch"
          operator: In
          values: ["amd64"]
        - key: "karpenter.sh/capacity-type" # If not included, the webhook for the AWS cloud provider will default to on-demand
          operator: In
          values: ["spot"]
        - key: kubernetes.io/os	
          operator: In	
          values: ["linux"]
      kubeletConfiguration:
        containerRuntime: containerd
        maxPods: 48 # https://docs.aws.amazon.com/ko_kr/AWSEC2/latest/UserGuide/using-eni.html
      limits:
        resources:
          cpu: 1k
      providerRef:
        name: default
      consolidation:
        enabled: true
      # ttlSecondsAfterEmpty: 30
      ttlSecondsUntilExpired: 604800 # 7 Days = 7 * 24 * 60 * 60 Seconds
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