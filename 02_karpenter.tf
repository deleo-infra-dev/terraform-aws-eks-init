################################################################################
# Karpenter 노드 리소스 설정
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
    # EC2 노드 클래스 정의
    - apiVersion: karpenter.k8s.aws/v1beta1
      kind: EC2NodeClass
      metadata:
        name: default
      spec:
        amiFamily: AL2023
        role: ${module.eks_init.karpenter.node_iam_role_name}
        subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
        securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${var.cluster_name}
        tags:
          karpenter.sh/discovery: ${var.cluster_name}
          eks.amazonaws.com/compute-type: "ec2"
          Name: "${var.cluster_name}-karpenter-node"

    # 노드 풀 정의
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
              eks.amazonaws.com/compute-type: "ec2"
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
            - key: "karpenter.sh/capacity-type" # 포함되지 않으면 AWS 클라우드 공급자의 웹훅이 기본적으로 온디맨드로 설정
              operator: In
              values: ["on-demand"]
            - key: kubernetes.io/os
              operator: In
              values:	["linux"]
            # 명시적으로 Fargate가 아니어야 함
            - key: eks.amazonaws.com/compute-type
              operator: NotIn
              values: ["fargate"]
        disruption:
          consolidationPolicy: WhenUnderutilized
          expireAfter: 4320h # 180일 = 180 * 24시간
        # Karpenter는 몇 가지 추가 Kubelet 인수를 지정할 수 있는 기능을 제공
        # 이들은 모두 선택 사항이며 추가 사용자 지정 및 사용 사례를 지원
        kubelet:
          maxPods: 672
    EOF
  ]
  depends_on = [
    module.eks_init
  ]
}

################################################################################
# Karpenter 테스트용 배포
## - [pause 이미지](https://www.ianlewis.org/en/almighty-pause-container)를 사용한 예제 배포
################################################################################
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
            nodeAffinity:
              requiredDuringSchedulingIgnoredDuringExecution:
                nodeSelectorTerms:
                  - matchExpressions:
                      - { key: "eks.amazonaws.com/compute-type", operator: "NotIn", values: [ "fargate" ] }
                      - { key: "default", operator: "In", values: [ "true" ] }
          nodeSelector:
            default: "true"
            instance: m7i.xlarge
            eks.amazonaws.com/compute-type: "ec2"
          containers:
            - name: inflate
              image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
              resources:
                requests:
                  cpu: "100m"
                  memory: "128Mi"
                limits:
                  cpu: "500m"
                  memory: "512Mi"
          tolerations:
          - key: "karpenter.sh/provisioned"
            operator: "Exists"
            effect: "NoSchedule"
  YAML
  depends_on = [
    helm_release.karpenter_default_node_resources
  ]
}