locals {
  
  ## Fargate resource configurations ##
  fargate_memory = "512M"  
  fargate_cpu    = "0.25"   

  env = {
    AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true"  
    ENI_CONFIG_LABEL_DEF               = "topology.kubernetes.io/zone" 
    ENABLE_PREFIX_DELEGATION           = "true"  
    WARM_PREFIX_TARGET                 = "1"    
    ENABLE_POD_ENI                     = "true" 
  }
  resolve_conflicts = {
    create = "OVERWRITE"
    update = "PRESERVE"
  }

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
      operator = "Exists"   # This toleration allows the CoreDNS pod to be scheduled on any node, regardless of the node's taint
    }]
  }
  ## VPC-CNI addon configuration ##
  vpc_cni_addon_config = {
    env = local.env
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

  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint # 클러스터 엔드포인트
  cluster_version   = var.cluster_version  # 클러스터 버전
  oidc_provider_arn = var.oidc_provider_arn    # OIDC 공급자 ARN
  
  # Fargate profile dependencies
  create_delay_dependencies = [for prof in var.fargate_profiles : prof.fargate_profile_arn] # Fargate 프로필 종속성 추가
  # EKS addons configurations
  eks_addons = {
    ########################################################
    # CoreDNS addon configuration (default addon) ##
    ########################################################
    coredns = {
      most_recent = true # 최신 버전 사용
      configuration_values = jsonencode(local.coredns_addon_config)

      resolve_conflicts = local.resolve_conflicts
      timeouts = {
        create = "15m" # 15분 대기
        update = "15m" # 15분 대기
      }
    }


    ########################################################
    # VPC-CNI addon configuration (default addon) ##
    ########################################################
    vpc-cni = {
      before_compute = true # 컴퓨트 이전에 배포
      most_recent    = true # 최신 버전 사용
      configuration_values = jsonencode(local.vpc_cni_addon_config)
      
      resolve_conflicts = local.resolve_conflicts
      timeouts = {
        create = "15m" # 15분 대기
        update = "15m" # 15분 대기
      }
    }

    ########################################################
    # Kube-proxy addon configuration (default addon) ##
    ########################################################
    kube-proxy = {
      before_compute = true # 컴퓨트 이전에 배포
      most_recent    = true # 최신 버전 사용
      # configuration_values = jsonencode(local.kube_proxy_addon_config)

      resolve_conflicts = local.resolve_conflicts
      timeouts = {
        create = "15m" # 15분 대기
        update = "15m" # 15분 대기
    }
  }

    ########################################################
    # Metrics server configuration (default addon) ##
    ########################################################
    enable_metrics_server = true # Metrics server 활성화

    ########################################################
    # Karpenter configuration (default addon)
    ########################################################
    enable_karpenter = true # Karpenter 활성화
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

  # Resource tagging (default tag) ##
  tags = var.tags
  }
}

########################################################
# Karpenter 강제 재시작 (Terraform 실행 시 자동 트리거)
########################################################
resource "null_resource" "karpenter_restart" {
  provisioner "local-exec" {
    command = <<EOT
      kubectl scale deployment karpenter --replicas=0 -n karpenter # 중지
      sleep 5 # 5초 대기
      kubectl scale deployment karpenter --replicas=1 -n karpenter # 재시작
    EOT
  }

  depends_on = [
    module.eks_init  # Karpenter가 배포된 후 실행
  ]
}



########################################################