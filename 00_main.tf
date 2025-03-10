locals {
  
  ## Fargate resource configurations ##
  fargate_memory = "512M"  
  fargate_cpu    = "0.25"   

  ## CoreDNS addon configuration ##
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
    tolerations = [{
      operator = "Exists" 
    }]
  }
  ## VPC-CNI addon configuration ##
  vpc_cni_addon_config = {
    env = {
      AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true" 
      ENI_CONFIG_LABEL_DEF               = "topology.kubernetes.io/zone" 
      ENABLE_PREFIX_DELEGATION           = "true" 
      WARM_PREFIX_TARGET                 = "1" 
      ENABLE_POD_ENI                     = "true" 
      WARM_ENI_TARGET                    = "1" 
      MINIMUM_IP_TARGET                  = "10" 
    }
    resources = {
      requests = {
        cpu    = "25m" # CPU request for the VPC-CNI addon
        memory = "64Mi" # Memory request for the VPC-CNI addon
      }
    }
  }
  ## Karpenter memory configuration ##
  karpenter_memory_request = "512Mi" # Minimum memory request for Karpenter to work
}
########################################################
# Data Sources 
## - Used to pull images from ECR Public (aws.virginia provider is used to pull images from ECR Public)
########################################################
data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

########################################################
# EKS Blueprints Addons
## - Used to configure the EKS addons
########################################################
module "eks_init" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"
  # Cluster basic configurations
  cluster_name      = var.cluster_name 
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version 
  oidc_provider_arn = var.oidc_provider_arn 
  
  # Fargate profile dependencies
  create_delay_dependencies = [for prof in var.fargate_profiles : prof.fargate_profile_arn]
  # EKS addons configurations
  eks_addons = {

    ## CoreDNS addon configuration (default addon)
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

    ## VPC-CNI addon configuration (default addon) ##
    vpc-cni = {
      before_compute = true
      most_recent    = true
      configuration_values = jsonencode(local.vpc_cni_addon_config)
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
      timeouts = {
        create = "15m"
        update = "15m"
      }
    }

    ## Kube-proxy addon configuration (default addon) ##
    kube-proxy = {}
  }

  # Karpenter configuration (default addon)
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

  # Metrics server configuration (default addon) ##
  enable_metrics_server = true

  # Resource tagging (default tag) ##
  tags = var.tags
}