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
│       ├── main.tf             # 기본 리소스 정의
│       ├── locals.tf           # 로컬 변수 정의
│       ├── vpc_cni.tf          # VPC CNI 설정
│       ├── vpc_cni_irsa.tftpl  # VPC CNI IRSA
│       ├── karpenter.tf        # Karpenter 설정
│       ├── karpenter_irsa.tf   # Karpenter IRSA 템플릿
│       ├── eni_config.tftpl    # ENI 설정 템플릿
│       ├── outputs.tf          # 출력 변수
│       ├── providers.tf        # 프로바이더 설정
│       ├── ecr_public.tf       # ECR 퍼블릭 설정
│       ├── datasource.tf       # 데이터 소스 정의
│       ├── versions.tf         # Version 설정
│       └── variables.tf        # 모듈 변수

```

## Example
