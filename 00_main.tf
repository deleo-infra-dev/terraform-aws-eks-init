locals {
  ## Fargate 리소스 구성 ##
  fargate_memory = "512M"
  fargate_cpu    = "0.25"

  ## CoreDNS 애드온 구성 ##
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

  ## VPC-CNI 애드온 구성 ##
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
        cpu    = "25m"  # VPC-CNI 애드온의 CPU 요청
        memory = "64Mi" # VPC-CNI 애드온의 메모리 요청
      }
    }
  }

  ## Karpenter 메모리 구성 ##
  karpenter_memory_request = "512Mi" # Karpenter 작동을 위한 최소 메모리 요청
}

########################################################
# 데이터 소스
## - ECR Public에서 이미지를 가져오는 데 사용 (aws.virginia 프로바이더를 사용하여 ECR Public에서 이미지 가져오기)
########################################################
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

########################################################
# EKS Blueprints Addons
## - EKS 애드온 구성에 사용
########################################################
module "eks_init" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  ## 모듈간 직접 참조 불가
  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn

  # Fargate 프로필 의존성 - kube-system만 해당
  create_delay_dependencies = var.create_delay_dependencies

  # EKS 애드온 구성
  eks_addons = {
    ## CoreDNS 애드온 구성 (기본 애드온)
    coredns = {
      most_recent                 = true
      configuration_values        = jsonencode(local.coredns_addon_config)
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
      timeouts = {
        create = "15m"
        update = "15m"
      }
    }

    ## VPC-CNI 애드온 구성 (기본 애드온) ##
    vpc-cni = {
      before_compute              = true
      most_recent                 = true
      configuration_values        = jsonencode(local.vpc_cni_addon_config)
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
      timeouts = {
        create = "15m"
        update = "15m"
      }
    }

    ## Kube-proxy 애드온 구성 (기본 애드온) ##
    kube-proxy = {
      most_recent = true
    }
  }

  # Karpenter 구성 (기본 애드온)
  enable_karpenter = true
  # Karpenter EC2 인스턴스 프로필 생성
  karpenter_enable_instance_profile_creation = true
  karpenter = {
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
    # 필요한 경우 명시적 버전 지정
    # chart_version = var.karpenter_version
    set = [
      {
        name  = "controller.resources.requests.memory"
        value = local.karpenter_memory_request
      }
    ]
    force_update = true # 최신 버전의 Karpenter가 있는지 확인하기 위해 강제 업데이트
  }

  # Metrics server 구성 (기본 애드온) ##
  enable_metrics_server = true
  metrics_server = {
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

  # 리소스 태깅 (기본 태그) ##
  tags = var.tags
}