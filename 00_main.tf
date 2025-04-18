################################################################################
# EKS Init
################################################################################

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

################################################################################
# EKS Init
################################################################################
module "eks_init" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn

  # Fargate 프로필 의존성 (Fargate Profile) - 모든 Fargate 프로필이 생성된 후에 EKS 클러스터를 생성하도록 의존성을 설정합니다
  create_delay_dependencies = [for prof in var.fargate_profiles : prof.fargate_profile_arn]

  eks_addons = {

    # [CoreDNS]
    coredns = {
      configuration_values = jsonencode({
        computeType = "Fargate"
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
    }

    # [vpc-cni]
    vpc-cni = {
      before_compute = true
      most_recent    = true
      configuration_values = jsonencode({
        env = {
          AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true"
          ENI_CONFIG_LABEL_DEF               = "topology.kubernetes.io/zone"
          ENABLE_PREFIX_DELEGATION           = "true"
          WARM_PREFIX_TARGET                 = "1"
        }
      })
    }

    # [kube-proxy]
    kube-proxy = {
      before_compute = true
      most_recent    = true
      configuration_values = jsonencode({
        config = {
          max-ports-per-node   = "1000"
          max-sockets-per-node = "20"
        }
      })
    }
  }

  # [Karpenter](https://karpenter.sh/)
  enable_karpenter = true
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

  # [Metrics-Server]
  enable_metrics_server = true

  tags = var.tags
}
