################################################################################
# EKS Init
################################################################################

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

resource "kubernetes_config_map" "aws_logging" {
  metadata {
    name      = "aws-logging"
    namespace = "kube-system"
  }

  data = {
    "log-level" = "info" # 로그 레벨 설정: debug, info, warn, error 중 선택
    # 추가 로깅 설정이 필요한 경우 여기에 추가
  }
}

locals {
  region                   = var.region
  profile                  = var.profile
  shared_credentials_files = var.shared_credentials_files
  eks_pod_subnet_ids       = var.eks_pod_subnet_ids
  azs                      = var.azs

  cluster_name                      = var.cluster_name
  cluster_endpoint                  = var.cluster_endpoint
  cluster_version                   = var.cluster_version
  oidc_provider_arn                 = var.oidc_provider_arn
  cluster_ca_certificate            = var.cluster_ca_certificate
  cluster_primary_security_group_id = var.cluster_primary_security_group_id

  karpenter_version = var.karpenter_version

  karpenter_env                = var.karpenter_env
  karpenter_ami_family         = var.karpenter_ami_family
  karpenter_instance_families  = var.karpenter_instance_families
  karpenter_instance_sizes     = var.karpenter_instance_sizes
  karpenter_node_capacity_type = var.karpenter_node_capacity_type

}

module "eks_init" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = local.cluster_name
  cluster_endpoint  = local.cluster_endpoint
  cluster_version   = local.cluster_version
  oidc_provider_arn = local.oidc_provider_arn

  # We want to wait for the Fargate profiles to be deployed first
  create_delay_dependencies = [for prof in var.fargate_profiles : prof.fargate_profile_arn]

  eks_addons = {

    coredns = {
      before_compute = true
      #most_recent = true
      addon_version = "v1.11.4-eksbuild.2"
      preserve      = true
      configuration_values = jsonencode({
        computeType  = "Fargate"
        replicaCount = 2
        resources = {
          limits = {
            cpu    = "0.25"
            memory = "512M"
          }
          requests = {
            cpu    = "0.25"
            memory = "512M"
          }
        }
      })
      timeouts = {
        create = "25m"
        update = "25m"
        delete = "10m"
      }
    } # coredns (end)

    vpc-cni = {
      before_compute = true # This will make sure the VPC CNI is rolled out first before deploying the addons
      #most_recent    = true
      addon_version            = "v1.19.3-eksbuild.1" # This can be overridden per addon if required
      preserve                 = true
      resolve_conflicts        = "OVERWRITE" # This is required when we want to overwrite the CNI configmap
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn

      # VPC-CNI 가 필요한 리소스(IRSA) 가 준비된 후 설치!
      depends_on = [
        module.vpc_cni_irsa
      ]

      configuration_values = jsonencode({
        env = {
          AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true"
          ENI_CONFIG_LABEL_DEF               = "topology.kubernetes.io/zone"
          ENABLE_PREFIX_DELEGATION           = "true"
          WARM_PREFIX_TARGET                 = "1"
        }

        resources = {
          limits = {
            cpu    = "100m"
            memory = "300Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "100Mi"
          }
        }
      })
      timeouts = {
        create = "25m"
        update = "25m"
      }
    } ## vpc-cni (end)

    kube-proxy = {
      most_recent = true
      preserve    = true
      configuration_values = jsonencode({
        # kube-proxy 리소스 설정
        resources = {
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      })
    } ## kube-proxy (end)
  }

  enable_karpenter = false
  karpenter = {
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
    set = [
      {
        name  = "controller.resources.requests.memory"
        value = "512Mi"
      }
    ]
  }

  enable_metrics_server = true # 메트릭스 서버 활성화 (Karpenter 설치 전에 활성화)

  tags = var.tags
}

################################################################################
# EKS 애드온 상태 확인 리소스
################################################################################
resource "null_resource" "verify_addons" {
  provisioner "local-exec" {
    command = <<-EOT
      # kubectl 구성 업데이트
      aws eks update-kubeconfig --name ${local.cluster_name} --region ${local.region} --alias ${local.cluster_name}

      # CoreDNS 상태 확인
      echo "CoreDNS 상태 확인 중..."
      kubectl get pods -n kube-system -l k8s-app=kube-dns || echo "CoreDNS 리소스를 찾을 수 없습니다."

      # VPC CNI 상태 확인
      echo "VPC CNI 상태 확인 중..."
      kubectl get daemonset -n kube-system -l k8s-app=aws-node || echo "VPC CNI 리소스를 찾을 수 없습니다."

      # kube-proxy 상태 확인
      echo "kube-proxy 상태 확인 중..."
      kubectl get daemonset -n kube-system -l k8s-app=kube-proxy || echo "kube-proxy 리소스를 찾을 수 없습니다."

      # 애드온 버전 정보 확인
      echo "애드온 버전 정보:"
      kubectl get pods -n kube-system -o=jsonpath="{range .items[*]}{.metadata.name}{'\t'}{.spec.containers[0].image}{'\n'}{end}" | grep -E 'coredns|aws-node|kube-proxy' || echo "애드온 버전 정보를 찾을 수 없습니다."
    EOT
  }

  # 클러스터와 의존성 설정 추가
  depends_on = [
    module.eks_init
  ]
}

################################################################################
# VPC_CNI_IRSA
################################################################################
module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name = "${local.cluster_name}-vpc-cni-irsa"

  attach_vpc_cni_policy = true # VPC-CNI 정책을 역할에 연결
  vpc_cni_enable_ipv4   = true # VPC-CNI 에서 IPv4 활성화

  oidc_providers = {
    main = {
      provider_arn               = local.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

resource "null_resource" "verify_cni_initialization" {
  provisioner "local-exec" {
    command = <<-EOT
      # kubectl 구성 업데이트/Users/jinyoungha/Deleo/deleo-infra/terraform-aws-eks-init/etc/karpenter.tf
      aws eks update-kubeconfig --name ${local.cluster_name} --region ${local.region} --alias ${local.cluster_name}

      echo "CNI 초기화 확인 중..."
      kubectl wait --for=condition=ready pods -l k8s-app=aws-node -n kube-system --timeout=300s

      echo "CNI 구성 확인 중..."
      kubectl get daemonset -n kube-system aws-node -o yaml
    EOT
  }

  depends_on = [
    module.eks_init
  ]
}
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
  name = local.cluster_name
}

resource "aws_iam_role_policy" "eks_ecr_auth" {
  name = "eks-ecr-public-auth"
  role = split("/", data.aws_eks_cluster.cluster.role_arn)[1]
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
        amiFamily: var.karpenter_ami_family
        role: ${aws_iam_role.karpenter_node_role.arn}
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
            - key: eks.amazonaws.com/compute-type # [ADD] 2025/03/18
              operator: NotIn
              values:
                - fargate
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
  version    = var.karpenter_version
  namespace  = "karpenter"

  wait = true

  atomic          = false # 차트 설치 중 오류 발생 시 롤백 옵션
  cleanup_on_fail = true  # 차트 설치 실패 시 롤백 옵션
  wait_for_jobs   = true  # 차트 설치 완료 후 작업 대기 옵션
  max_history     = 3     # 차트 설치 이력 최대 이력

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }
  # 클러스터 엔드포인트 설정 (필수)
  set {
    name  = "settings.clusterEndpoint"
    value = var.cluster_endpoint
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
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",          # 프라이빗 ECR 접근용
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
  name = "${var.cluster_name}-fargate-pod-execution-role"

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

################################################################################
# 웹훅 설정 수정을 위한 리소스
################################################################################
resource "null_resource" "setup_karpenter_webhooks" {
  depends_on = [
    helm_release.karpenter # 또는 실제 사용 중인 Karpenter 리소스 이름
  ]

  # 변경 사항이 있을 때만 실행되도록 트리거 추가
  triggers = {
    always_run = timestamp() # 항상 실행되도록 설정
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Karpenter 파드가 준비될 때까지 대기
      echo "Waiting for Karpenter pods to be ready..."
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=karpenter -n karpenter --timeout=300s || true

      # 현재 웹훅 설정 확인 (디버깅용)
      echo "Checking current webhook configuration..."
      kubectl get crd nodepools.karpenter.sh -o=jsonpath='{.spec.conversion.webhook.clientConfig.service.namespace}' || true

      # CRD의 웹훅 네임스페이스 수정
      echo "Patching CRD webhook settings..."
      kubectl patch crd nodepools.karpenter.sh --type=json -p '[{"op":"replace","path":"/spec/conversion/webhook/clientConfig/service/namespace","value":"karpenter"}]' || true
      kubectl patch crd ec2nodeclasses.karpenter.k8s.aws --type=json -p '[{"op":"replace","path":"/spec/conversion/webhook/clientConfig/service/namespace","value":"karpenter"}]' || true
      kubectl patch crd nodeclaims.karpenter.sh --type=json -p '[{"op":"replace","path":"/spec/conversion/webhook/clientConfig/service/namespace","value":"karpenter"}]' || true

      # 패치 적용 후 Karpenter 파드 재시작 (필요한 경우)
      echo "Restarting Karpenter pods to apply changes..."
      kubectl rollout restart deployment -n karpenter karpenter || true

      # 변경 사항이 적용될 때까지 대기
      echo "Waiting for Karpenter to stabilize after changes..."
      sleep 30
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=karpenter -n karpenter --timeout=300s || true
    EOT
  }
}
