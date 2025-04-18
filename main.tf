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
    "log-level" = "info"  # 로그 레벨 설정: debug, info, warn, error 중 선택
    # 추가 로깅 설정이 필요한 경우 여기에 추가
  }
}

locals {
  region = var.region
  profile = var.profile
  shared_credentials_files = var.shared_credentials_files
  eks_pod_subnet_ids = var.eks_pod_subnet_ids
  azs = var.azs
  
  cluster_name = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn
  cluster_ca_certificate = var.cluster_ca_certificate
  cluster_primary_security_group_id = var.cluster_primary_security_group_id

  karpenter_version = var.karpenter_version
  
  karpenter_env = var.karpenter_env
  karpenter_ami_family = var.karpenter_ami_family
  karpenter_instance_families = var.karpenter_instance_families
  karpenter_instance_sizes = var.karpenter_instance_sizes
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
      preserve    = true
      configuration_values = jsonencode({
        computeType = "Fargate"
        replicaCount = 2
        resources = {
          limits = {
            cpu = "0.25"
            memory = "512M"
          }
          requests = {
            cpu = "0.25"
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
      addon_version = "v1.19.3-eksbuild.1"  # This can be overridden per addon if required
      preserve      = true
      resolve_conflicts        = "OVERWRITE"  # This is required when we want to overwrite the CNI configmap
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn

      # VPC-CNI 가 필요한 리소스(IRSA) 가 준비된 후 설치!
      depends_on = [
        module.vpc_cni_irsa
      ]

      configuration_values = jsonencode({
        env = {
          AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true"
          ENI_CONFIG_LABEL_DEF               = "topology.kubernetes.io/zone"
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
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

  # enable_karpenter = true
  # karpenter = {
  #   repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  #   repository_password = data.aws_ecrpublic_authorization_token.token.password
  #   set = [
  #     {
  #       name = "controller.resources.requests.memory"
  #       value = "512Mi"
  #     }
  #   ]
  # }
  
  enable_metrics_server = true  # 메트릭스 서버 활성화 (Karpenter 설치 전에 활성화)

  tags = var.tags
}

################################################################################
# EKS 애드온 상태 확인 리소스
################################################################################
resource "null_resource" "verify_addons" {
  provisioner "local-exec" {
    command = <<-EOT
      # kubectl 구성 업데이트
      aws eks update-kubeconfig --name ${local.cluster_name} --region ${var.region} --alias ${var.cluster_name}

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
