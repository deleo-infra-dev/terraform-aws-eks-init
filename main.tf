################################################################################
# 로컬 변수 정의
################################################################################
locals {
  # 외부 리소스 사용 여부 확인
  use_external_resources = var.external_karpenter_node_role_name != "" && var.external_karpenter_node_role_arn != ""
  
  # Karpenter 노드 역할 이름 - 외부 제공 또는 생성
  karpenter_node_role_name = local.use_external_resources ? var.external_karpenter_node_role_name : aws_iam_role.karpenter_node[0].name
  
  # Karpenter 노드 역할 ARN - 외부 제공 또는 생성
  karpenter_node_role_arn = local.use_external_resources ? var.external_karpenter_node_role_arn : aws_iam_role.karpenter_node[0].arn
  
  # 인스턴스 프로파일 이름 - 외부 제공 또는 생성
  karpenter_instance_profile_name = local.use_external_resources ? var.external_karpenter_instance_profile_name : aws_iam_instance_profile.karpenter[0].name
}

################################################################################
# Karpenter 노드 IAM 역할 생성
################################################################################
resource "aws_iam_role" "karpenter_node" {
  count = local.use_external_resources ? 0 : 1
  
  name = "${var.cluster_name}-karpenter-node"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

################################################################################
# Karpenter 노드 IAM 역할 정책 추가
################################################################################
resource "aws_iam_role_policy_attachment" "karpenter_eks_worker" {
  count = local.use_external_resources ? 0 : 1
  role       = aws_iam_role.karpenter_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "karpenter_eks_cni" {
  count = local.use_external_resources ? 0 : 1
  role       = aws_iam_role.karpenter_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "karpenter_ecr_read" {
  count = local.use_external_resources ? 0 : 1
  role       = aws_iam_role.karpenter_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "karpenter_ssm_core" {
  count = local.use_external_resources ? 0 : 1
  role       = aws_iam_role.karpenter_node[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

################################################################################
# Karpenter 인스턴스 프로파일 생성
################################################################################
resource "aws_iam_instance_profile" "karpenter" {
  count = local.use_external_resources ? 0 : 1
  
  name = "${var.cluster_name}-karpenter-instance-profile"
  role = local.karpenter_node_role_name
}

################################################################################
# Karpenter 컨트롤러 IAM 역할 생성
################################################################################
module "karpenter_controller_irsa" {
  count = var.create_karpenter_controller_irsa ? 1 : 0
  
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30.0"

  role_name                          = "${var.cluster_name}-karpenter-controller"
  attach_karpenter_controller_policy = true

  karpenter_controller_cluster_name       = var.cluster_name
  karpenter_controller_node_iam_role_arns = [local.karpenter_node_role_arn]

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["karpenter:karpenter"]
    }
  }

  tags = var.tags
}