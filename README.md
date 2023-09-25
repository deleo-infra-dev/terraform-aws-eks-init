# terraform aws eks init
To install karpenter addons with daemonsets kind addons. Install this before install [rayshoo/eks-addons/aws](github.com/rayshoo/terraform-aws-eks-addons) module. To use this module, it is recommended to separate node subnets and pod subnets.

## Example
```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "18.31.2"
  ...
}

module "eks_init" {
  source  = "rayshoo/eks-init/aws"
  version = "1.0.1"

  profile =  local.profile
  shared_credentials_files = var.shared_credentials_files

  azs = local.azs
  eks_pod_subnet_ids = slice(module.vpc.*_subnets, 0, 3)

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn
  fargate_profiles  = module.eks.fargate_profiles

  cluster_ca_certificate = module.eks.cluster_certificate_authority_data
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id

  tags = local.tags
}
```