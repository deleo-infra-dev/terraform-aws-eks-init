################################################################################
# Karpenter 서비스 계정용 IAM 역할 (IRSA)
################################################################################
module "karpenter_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  # IAM 역할 이름 (EKS 클러스터 이름으로 프리픽스)
  role_name = "${local.cluster_name}-karpenter-service-role"

  # Karpenter 권한 정책 연결
  role_policy_arns = {
    karpenter = aws_iam_policy.karpenter_policy.arn
  }

  # OIDC 공급자 설정
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["karpenter:karpenter"]
    }
  }
}

################################################################################
# Karpenter 노드 IAM 역할
################################################################################
resource "aws_iam_role" "karpenter_node_role" {
  name = "${local.cluster_name}-karpenter-node-role"

  # EC2 서비스가 이 역할을 수임할 수 있도록 설정
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

#################################################################################
# 데이터소스를 통해 기존 EKS 클러스터의 정보 취득
#################################################################################
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

resource "aws_iam_role_policy" "eks_ecr_auth" {
  name   = "eks-ecr-public-auth"
  role   = split("/", data.aws_eks_cluster.cluster.role_arn)[1]
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["sts:GetServiceBearerToken"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["ecr-public:GetAuthorizationToken"],
        Resource = "*"
      }
    ]
  })
}

################################################################################
# Karpenter
################################################################################


################################################################################
# Karpenter NodeClass 생성
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
        amiFamily: ${var.karpenter_ami_family}
        role: ${module.eks_init.karpenter.node_iam_role_name}
        subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_name}
        securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${local.cluster_name}
        tags:
          karpenter.sh/discovery: ${local.cluster_name}


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
              instance-category: 'm'
              capacity: on-demand
          spec:
            nodeClassRef:
              name: default
            requirements:
            - key: karpenter.k8s.aws/instance-family
              operator: In
              values: ["m7i", "m7i-flex"]
            - key: karpenter.k8s.aws/instance-size
              operator: In
              values: ${jsonencode(var.karpenter_instance_sizes)}
            - key: karpenter.k8s.aws/instance-hypervisor
              operator: In
              values: ["nitro"]
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: kubernetes.io/os
              operator: In
              values:	["linux"]
            - key: "karpenter.sh/capacity-type" # If not included, the webhook for the AWS cloud provider will default to on-demand
              operator: In
              values: ${jsonencode(var.karpenter_node_capacity_type)}
            - key: topology.kubernetes.io/zone
              operator: In
              values: ${jsonencode(local.azs)}
            
        disruption:
          consolidationPolicy: WhenUnderutilized
          expireAfter: 4320h # 180 Days = 180 * 24 Hours

        kubelet:
          maxPods: 672
    EOF
  ]
  depends_on = [
    module.eks_init
  ]
}

################################################################################
# Karpenter NodePool 생성
################################################################################
resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
apiVersion: karpenter.sh/v1beta1
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
        instance-category: 'm'
        capacity: on-demand
    spec:
      nodeClassRef:
        name: default
      requirements:
      - key: kubernetes.io/arch
        operator: In
        values: ["amd64"]  # ARM64 대신 amd64만 사용
      - key: kubernetes.io/os
        operator: In
        values:	["linux"] # 현재 클러스터에서 사용하는 운영체제
      - key: karpenter.k8s.aws/instance-hypervisor
        operator: In
        values: ["nitro"] # 현재 클러스터에서 사용하는 인스턴스 타입 (nitro, hvm)
      - key: topology.kubernetes.io/zone
        operator: In
        values: ${jsonencode(local.azs)} # 현재 클러스터에서 사용하는 가용 영역 
      - key: karpenter.sh/capacity-type
        operator: In
        values: ${jsonencode(var.karpenter_node_capacity_type)} # 현재 클러스터에서 사용하는 노드 용량 유형 (on-demand, spot)
      - key: karpenter.k8s.aws/instance-generation
        operator: Gt
        values: ["2"]
    
      - key: karpenter.k8s.aws/instance-category
        operator: In
        values: ${jsonencode(var.karpenter_instance_families)}  # 현재 클러스터에서 사용하는 인스턴스 카테고리 (c, m, r, t)
      - key: karpenter.k8s.aws/instance-family
        operator: In
        values: ["m7i-flex", "m7i"]        # m7i-flex와 m7i 인스턴스 허용

      - key: karpenter.k8s.aws/instance-size
        operator: In
        values: ${jsonencode(var.karpenter_instance_sizes)} # 현재 클러스터에서 사용하는 인스턴스 크기 (xlarge, 2xlarge, 3xlarge, 4xlarge, 5xlarge, 6xlarge, 7xlarge, 8xlarge, 9xlarge, 10xlarge) 
      kubelet:
        maxPods: 672
        
  limits:
    cpu: "2000"
    memory: "8000Gi" 

  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 4320h # 180 Days = 180 * 24 Hours (180일, 4320시간, 6개월), 노드 종료 전 최대 6개월 동안 대기 (안정성 중시)
YAML

  depends_on = [
    helm_release.karpenter_default_node_resources
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
          tolerations:
          - key: "node-role.kubernetes.io/worker"
            operator: "Exists"
            effect: "NoSchedule"
          nodeSelector:
            default: "true"
            consolidation: "true"
            critical: "false"
            instance-category: "m"
            capacity: "on-demand"
            kubernetes.io/os: "linux"
            kubernetes.io/arch: "amd64"
            eks.amazonaws.com/compute-type: "ec2"
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
                      - key: eks.amazonaws.com/compute-type
                        operator: NotIn
                        values:
                          - fargate
          containers:
            - name: inflate
              image: public.ecr.aws/eks-distro/kubernetes/pause:3.7
              resources: {}
  YAML
  depends_on = [
    helm_release.karpenter_default_node_resources,
    kubectl_manifest.karpenter_node_pool
  ]
}

################################################################################
# ECR 레지스트리 로그인 (OCI 저장소 접근용)
################################################################################
resource "null_resource" "ecr_login" {
  provisioner "local-exec" {
    command = "aws ecr-public get-login-password --region us-east-1 | helm registry login --username AWS --password-stdin public.ecr.aws"
  }


}
############################################################################
# Karpenter CRD
############################################################################
resource "helm_release" "karpenter" {
  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter"
  version    = local.karpenter_version
  namespace  = "karpenter"

  wait       = true

  atomic           = false  # 차트 설치 중 오류 발생 시 롤백 옵션
  cleanup_on_fail  = true   # 차트 설치 실패 시 롤백 옵션
  wait_for_jobs    = true   # 차트 설치 완료 후 작업 대기 옵션
  max_history      = 3      # 차트 설치 이력 최대 이력

  set {
    name  = "settings.clusterName"
    value = local.cluster_name
  }
  # 클러스터 엔드포인트 설정 (필수)
  set {
    name  = "settings.clusterEndpoint"
    value = local.cluster_endpoint
  }


  set {
    name  = "settings.aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.karpenter_instance_profile.name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter_irsa.iam_role_arn
  }

  # 컨트롤러 설정
  set {
    name  = "controller.resources.requests.cpu"
    value = "500m"
  }

  set {
    name  = "controller.resources.requests.memory"
    value = "512Mi"
  }

  set {
    name  = "controller.resources.limits.cpu"
    value = "1000m"
  }

  set {
    name  = "controller.resources.limits.memory"
    value = "1Gi"
  }

  # 로깅 설정
  set {
    name  = "settings.featureGates.driftEnabled"
    value = "true"
  }

  # # PDB
  # set {
  #   name  = "podDisruptionBudget.minAvailable"
  #   value = "1"
  # }
    set {
    name  = "podDisruptionBudget.enabled"
    value = "false"
  }

  # CRD 자동 설치
  set {
    name  = "installCRDs"
    value = "true"
  }

  # 타임아웃 설정 증가
  set {
    name  = "controller.healthProbe.timeoutSeconds"
    value = "30"
  }

  # Webhook 타임아웃 설정
  set {
    name  = "webhook.timeoutSeconds"
    value = "30"
  }



  set {
    name  = "crds.enabled"
    value = "true"
  }


  depends_on = [
    helm_release.karpenter,
    module.eks_init
  ]
}

################################################################################
# AWS 인증 ConfigMap 관리 - Karpenter 노드 역할 추가
################################################################################
resource "kubernetes_config_map_v1_data" "aws_auth_karpenter" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = <<YAML
- groups:
  - system:bootstrappers
  - system:nodes
  rolearn: ${aws_iam_role.karpenter_node_role.arn}
  username: system:node:{{EC2PrivateDNSName}}
YAML
  }

  force = true

  depends_on = [
    helm_release.karpenter,
    module.eks_init,
    kubernetes_config_map.aws_auth
  ]
}

################################################################################
# 노드 IAM 역할에 정책 연결
################################################################################
resource "aws_iam_role_policy_attachment" "karpenter_node_policy" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",  # 프라이빗 ECR 접근용
    "arn:aws:iam::aws:policy/AmazonElasticContainerRegistryPublicReadOnly" # 퍼블릭 ECR 접근에 필요
  ])

  role       = aws_iam_role.karpenter_node_role.name
  policy_arn = each.value
}

################################################################################
# Karpenter 노드용 인스턴스 프로필
################################################################################
resource "aws_iam_instance_profile" "karpenter_instance_profile" {
  name = "${local.cluster_name}-karpenter-node"
  role = aws_iam_role.karpenter_node_role.name
}

################################################################################
# Karpenter 컨트롤러 권한 정책
################################################################################
resource "aws_iam_policy" "karpenter_policy" {
  name        = "${local.cluster_name}-karpenter-policy"
  description = "Karpenter controller policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "iam:PassRole",
          "ec2:TerminateInstances",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeSpotPriceHistory",
          "pricing:GetProducts",
          "ssm:GetParameter",
          "ec2:DescribeImages",
          "ec2:DeleteLaunchTemplate",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeSnapshots",
          "iam:CreateServiceLinkedRole",
          "iam:ListInstanceProfiles",
          "iam:GetInstanceProfile",
          "iam:ListRoles",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
          "eks:DescribeCluster"
        ],
        Resource = "*"
      }
    ]
  })
}

################################################################################
# Karpenter RBAC 권한 설정
################################################################################
resource "kubectl_manifest" "karpenter_rbac" {
  yaml_body = <<-YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: karpenter-node-proxy
rules:
- apiGroups: [""]
  resources: ["nodes/proxy"]
  verbs: ["get", "create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: karpenter-node-proxy
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: karpenter-node-proxy
subjects:
- kind: User
  name: kube-apiserver-kubelet-client
  apiGroup: rbac.authorization.k8s.io
YAML

  depends_on = [
    helm_release.karpenter
  ]
}

################################################################################
# Fargate 프로필용 IAM 역할
################################################################################
resource "aws_iam_role" "fargate_pod_execution_role" {
  name = "${local.cluster_name}-fargate-pod-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fargate_pod_execution_role_policy" {
  role       = aws_iam_role.fargate_pod_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

################################################################################
# AWS 인증 ConfigMap 관리 - Fargate 역할 추가
################################################################################
resource "kubernetes_config_map_v1_data" "aws_auth_fargate" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = <<YAML
- groups:
  - system:bootstrappers
  - system:nodes
  rolearn: ${aws_iam_role.fargate_pod_execution_role.arn}
  username: system:node:{{EC2PrivateDNSName}}
YAML
  }

  force = true

  depends_on = [
    helm_release.karpenter,
    module.eks_init,
    kubernetes_config_map.aws_auth
  ]
}

################################################################################
# 시스템 컴포넌트 RBAC 권한 설정
################################################################################
resource "kubectl_manifest" "system_components_rbac" {
  yaml_body = <<-YAML
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: system-node-proxy
rules:
- apiGroups: [""]
  resources: ["nodes", "nodes/proxy", "nodes/status", "nodes/spec"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system-node-proxy
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system-node-proxy
subjects:
- kind: User
  name: kube-apiserver-kubelet-client
  apiGroup: rbac.authorization.k8s.io
- kind: ServiceAccount
  name: coredns
  namespace: kube-system
- kind: ServiceAccount
  name: aws-node
  namespace: kube-system
- kind: ServiceAccount
  name: karpenter
  namespace: karpenter
- kind: ServiceAccount
  name: kube-proxy
  namespace: kube-system
- kind: ServiceAccount
  name: ebs-csi-controller-sa
  namespace: kube-system
YAML

  depends_on = [
    helm_release.karpenter
  ]
}

################################################################################
# AWS 인증 ConfigMap 생성
################################################################################
resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = <<YAML
- groups:
  - system:bootstrappers
  - system:nodes
  rolearn: ${aws_iam_role.karpenter_node_role.arn}
  username: system:node:{{EC2PrivateDNSName}}
YAML
  }

  depends_on = [
    module.eks_init
  ]
}
