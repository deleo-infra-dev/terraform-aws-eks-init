################################################################################
# EKS Init
################################################################################

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

module "eks_init" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = var.cluster_name
  cluster_endpoint  = var.cluster_endpoint
  cluster_version   = var.cluster_version
  oidc_provider_arn = var.oidc_provider_arn

  # We want to wait for the Fargate profiles to be deployed first
  create_delay_dependencies = [for prof in var.fargate_profiles : prof.fargate_profile_arn]

  for_each = var.eks_addons
  eks_addons = merge(var.eks_addons,
    vpc-cni = {
        # Specify the VPC CNI addon should be deployed before compute to ensure
        # the addon is configured before data plane compute resources are created
        # See README for further details
        before_compute = true
        most_recent    = true # To ensure access to the latest settings provided
        configuration_values = jsonencode({
          env = {
            # Reference https://aws.github.io/aws-eks-best-practices/reliability/docs/networkmanagement/#cni-custom-networking
            AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true"
            ENI_CONFIG_LABEL_DEF               = "topology.kubernetes.io/zone"

            # # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
            ENABLE_PREFIX_DELEGATION = "true"
            WARM_PREFIX_TARGET       = "1"
          }
        })
      },
      kube-proxy = {}
  )

  enable_karpenter = true
  karpenter = {
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password
  }
  enable_metrics_server = true

  tags = var.tags
}