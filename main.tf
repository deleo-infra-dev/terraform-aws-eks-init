#############################################################################################
# EKS Init Module
# This is used to install the EKS Addons
# - CoreNDS
# - VPC CNI
# - Kube Proxy
# - Metrics Server
# - Karpenter
##############################################################################################

module "eks_init" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = local.cluster_name      # EKS Cluster Name 
  cluster_endpoint  = local.cluster_endpoint  # EKS Cluster Endpoint
  cluster_version   = local.cluster_version   # EKS Cluster Version
  oidc_provider_arn = local.oidc_provider_arn # OIDC Provider ARN

  # Fargate 프로필 배포 후 진행
  create_delay_dependencies = [for prof in var.fargate_profiles : prof.fargate_profile_arn]

  eks_addons = {

    coredns = {
      before_compute = true
      addon_version  = var.coredns_version
      preserve       = true
      configuration_values = jsonencode({
        computeType  = "Fargate"
        replicaCount = 2
        resources = {
          limits = {
            # 메모리 설정 - Fargate 오버헤드 고려 (256MB 추가 예약)
            cpu    = "0.25" # 0.25 vCPU 예약 (Fargate 오버헤드 고려)
            memory = "256M" # 총 Fargate 메모리: 256M + 256M(오버헤드) = 512M
          }
          requests = {
            cpu    = "0.25"
            memory = "256M"
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
      before_compute           = true                  # This will make sure the VPC CNI is rolled out first before deploying the addons
      addon_version            = local.vpc_cni_version # This can be overridden per addon if required
      preserve                 = true
      resolve_conflicts        = "OVERWRITE"                      # This is required when we want to overwrite the CNI configmap
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn # VPC CNI IRSA 역할 ARN (VPC CNI 설치 시 필요, 별도 IRSA 모듈 사용)

      configuration_values = jsonencode({
        env = {
          AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true"                        # 사용자 정의 네트워크 구성 활성화 (VPC CNI 설치 시 필요)
          ENI_CONFIG_LABEL_DEF               = "topology.kubernetes.io/zone" # 네트워크 인터페이스 라벨 정의 (VPC CNI 설치 시 필요)
          ENABLE_PREFIX_DELEGATION           = "true"                        # 네트워크 인터페이스 전용 접두사 위임 활성화 (VPC CNI 설치 시 필요)
          WARM_PREFIX_TARGET                 = "1"                           # 1개의 네트워크 인터페이스를 준비 + 단일 NAT 게이트웨이 사용 = 비용효율성 최적화

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
      addon_version = local.kube_proxy_version
      preserve      = true
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

  ## Karpenter ## 
  enable_karpenter = true
  karpenter = {
    before_compute = true

    # define the dependencies (자기참조가 될 수 있어 삭제)

    # ECR Public Authorization Token 설정 (Karpenter 설치 시 필요)
    repository_username = data.aws_ecrpublic_authorization_token.ecr_public_authorization_token.user_name # ECR Public Authorization Token USERNAME
    repository_password = data.aws_ecrpublic_authorization_token.ecr_public_authorization_token.password  # ECR Public Authorization Token PASSWORD

    # Karpenter 버전 설정
    addon_version = local.karpenter_version # Karpenter 버전 설정
    preserve      = true                    # Karpenter 설치 시, 기존 설정 덮어쓰기 방지

    ## Karpenter 설정 ## 
    # Karpenter 설정 참고: https://karpenter.sh/docs/latest/getting-started/getting-started-with-eks/

    # Karpenter 설정 예시 - 메모리 설정 (Controller, Node) - Fargate 프로필 사용 시, 메모리 설정 필요
    set = [
      {
        name  = "controller.resources.requests.memory"
        value = "512Mi"
      }
    ]

  } ## karpenter (end)

  ## Metrics Server ## 
  enable_metrics_server = true # Metrics Server 설치 여부

  # define the dependencies (자기참조가 될 수 있어 삭제)

  metrics_server = {
    addon_version = local.metrics_server_version # Metrics Server 버전 설정
    preserve      = true                         # Metrics Server 설치 시, 기존 설정 덮어쓰기 방지

    # Metrics Server 설정 예시 - 메모리 설정 (Controller, Node) - Fargate 프로필 사용 시, 메모리 설정 필요
    set = [
      {
        name  = "controller.resources.requests.memory"
        value = "128Mi"
      },
      {
        name  = "controller.resources.requests.cpu"
        value = "100m"
      },
      {
        name  = "controller.resources.limits.memory"
        value = "1Gi"
      },
      {
        name  = "controller.resources.limits.cpu"
        value = "500m"
      }
    ]
  } ## metrics-server (end)

  tags = var.tags
}



################################################################################
# EKS Addons 종속성 관리
# 종속성 관리를 위한 null 리소스 추가
################################################################################
resource "null_resource" "wait_for_addons" {
  depends_on = [
    module.eks_init
  ]

  # 단순히 모듈에 의존하도록 수정
  triggers = {
    cluster_name = var.cluster_name # 간단한 트리거로 변경
  }
}
