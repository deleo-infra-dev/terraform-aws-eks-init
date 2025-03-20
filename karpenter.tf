################################################################################
# Karpenter 관련 로컬 변수 정의
################################################################################
locals {
  # Fargate 리소스 구성
  fargate_memory = "512M"
  fargate_cpu    = "0.25"

  # CoreDNS 애드온 구성
  coredns_addon_config = {
    computeType = "Fargate"
    resources = {
      limits = {
        cpu    = local.fargate_cpu
        memory = local.fargate_memory
      }
      requests = {
        cpu    = local.fargate_cpu
        memory = local.fargate_memory
      }
    }
    replicaCount = 2
    tolerations = [
      {
        key      = "eks.amazonaws.com/compute-type"
        operator = "Equal"
        value    = "fargate"
        effect   = "NoSchedule"
      }
    ]
  }

  # VPC-CNI 애드온 구성
  vpc_cni_addon_config = {
    env = {
      # 커스텀 네트워크 구성 활성화
      AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true"
      ENI_CONFIG_LABEL_DEF               = "topology.kubernetes.io/zone"

      # 프리픽스 위임 활성화
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"

      # Pod ENI 활성화
      ENABLE_POD_ENI    = "true"
      WARM_ENI_TARGET   = "1"
      MINIMUM_IP_TARGET = "10"
    }
    resources = {
      requests = {
        cpu    = "25m"
        memory = "64Mi"
      }
    }
  }

  # Karpenter 구성
  karpenter_config = {
    computeType = "Fargate"
    tolerations = [
      {
        key      = "eks.amazonaws.com/compute-type"
        operator = "Equal"
        value    = "fargate"
        effect   = "NoSchedule"
      }
    ]
  }

  # Karpenter 메모리 요청
  karpenter_memory_request = "512Mi"
}

################################################################################
# Amazon ECR Public 인증 토큰 가져오기
################################################################################
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

################################################################################
# EKS Blueprints Addons 모듈
################################################################################
module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  # 클러스터 정보
  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn

  # Fargate 프로필 의존성
  create_delay_dependencies = var.create_delay_dependencies

  # EKS 애드온 설정
  eks_addons = {
    # CoreDNS 애드온 설정
    coredns = {
      most_recent = true
      configuration_values = jsonencode(local.coredns_addon_config)
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
      timeouts = {
        create = "15m"
        update = "15m"
      }
    }

    # VPC-CNI 애드온 설정
    vpc-cni = {
      before_compute = true
      most_recent = true
      configuration_values = jsonencode(local.vpc_cni_addon_config)
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
      timeouts = {
        create = "15m"
        update = "15m"
      }
    }

    # Kube-proxy 애드온 설정
    kube-proxy = {
      most_recent = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
      timeouts = {
        create = "15m"
        update = "15m"
      }
    }
  }

  # Karpenter 설정
  enable_karpenter = true
  karpenter = {
    # ECR 인증 정보
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
    
    # IAM 역할 생성 설정 - 외부 역할 사용 여부에 따라 조건부 설정
    create_irsa = false  # IRSA 생성 비활성화 (별도 생성 또는 외부 제공)
    create_node_iam_role = false  # 노드 IAM 역할 생성 비활성화 (별도 생성 또는 외부 제공)
    
    # 역할 및 프로필 설정
    node_iam_role_name = local.karpenter_node_role_name
    node_iam_role_arn = local.karpenter_node_role_arn
    
    # Helm 차트 추가 설정
    set = concat(
      [
        {
          name  = "settings.aws.defaultInstanceProfile"
          value = local.karpenter_instance_profile_name
        },
        {
          name  = "controller.resources.requests.memory"
          value = local.karpenter_memory_request
        },
        {
          name  = "controller.resources.limits.memory"
          value = "1Gi"
        },
        {
          name  = "controller.resources.requests.cpu"
          value = "0.25"
        },
        {
          name  = "controller.resources.limits.cpu"
          value = "0.5"
        }
      ],
      var.create_karpenter_controller_irsa ? [
        {
          name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
          value = module.karpenter_controller_irsa[0].iam_role_arn
        }
      ] : []
    )
    
    # Fargate 호환성 설정
    configuration_values = jsonencode(local.karpenter_config)
  }

  # Metrics Server 설정
  enable_metrics_server = true
  metrics_server = {
    configuration_values = jsonencode({
      tolerations = [
        {
          key      = "eks.amazonaws.com/compute-type"
          operator = "Equal"
          value    = "fargate"
          effect   = "NoSchedule"
        }
      ]
      computeType = "Fargate"
    })
    set = [
      {
        name  = "resources.requests.memory"
        value = "64Mi"
      },
      {
        name  = "resources.limits.memory"
        value = "128Mi"
      }
    ]
  }

  # 태그
  tags = var.tags
}

################################################################################
# Karpenter CRD 설치
################################################################################
resource "helm_release" "karpenter_crd" {
  name       = "karpenter-crd"
  namespace  = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  chart      = "karpenter-crd"
  version    = var.karpenter_version

  create_namespace = true

  depends_on = [
    module.eks_blueprints_addons
  ]
}