<!-- trunk-ignore-all(prettier) -->
# TERRAFORM-AWS-EKS-INIT

## terraform aws eks init

To install karpenter addons with daemonsets kind addons. Install this before install [rayshoo/eks-addons/aws](https://github.com/rayshoo/terraform-aws-eks-addons) 
module. To use this module, it is recommended to separate node subnets and pod subnets.



## 디렉토리 구조

```yaml

project/
├── modules/
│   └── eks-init/
│       ├── main.tf           # 기본 리소스 정의
│       ├── vpc_cni.tf        # VPC CNI 설정
│       ├── karpenter.tf      # Karpenter 설정
│       ├── eni_config.tftpl  # ENI 설정 템플릿
│       ├── outputs.tf        # 출력 변수
│       ├── providers.tf      # 프로바이더 설정
│       └── variables.tf      # 모듈 변수

```

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


