################################################################################
# [LOCAL VARIABLES]
#####################################################################################
locals {
  # Fargate resource configurations
  fargate_memory = "512M" # 512M is the minimum memory for Fargate to work  
  fargate_cpu    = "0.25" # 0.25 is the minimum CPU for Fargate to work 

  # CNI configurations
  cni_env_configs = {
    AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true"
    ENI_CONFIG_LABEL_DEF               = "topology.kubernetes.io/zone"
    ENABLE_PREFIX_DELEGATION           = "true"
    WARM_PREFIX_TARGET                 = "1"
  }

  # Karpenter configurations
  karpenter_memory_request = "512Mi" # 512Mi is the minimum memory request for Karpenter to work 
}

################################################################################
# [DATA]
## - Used to pull images from ECR Public
################################################################################
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

################################################################################
# [MODULE] - eks_init
## - Used to initialize the EKS cluster
################################################################################
module "eks_init" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn

  create_delay_dependencies = [for prof in var.fargate_profiles : prof.fargate_profile_arn]
  eks_addons = {

    ## coreDNS ##
    coredns = {
      replicaCount = 2
      configuration_values = jsonencode({
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
      })
    }

    ## vpc-cni ##
    vpc-cni = {
      before_compute = true
      most_recent    = true
      configuration_values = jsonencode({
        env = {
          env = local.cni_env_configs
        }
      })
    }

    ## kube-proxy ##
    kube-proxy = {}
  }



  enable_karpenter = true
  karpenter = {
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
    set = [
      {
        name  = "controller.resources.requests.memory"
        value = local.karpenter_memory_request
      }
    ]
  }
  enable_metrics_server = true

  tags = var.tags
}