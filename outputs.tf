resource "local_file" "prevent_destroy_marker" {
  content     = "이 파일은 모듈 삭제 방지를 위한 마커입니다."
  filename    = "${path.module}/.prevent_destroy_marker"
  
  lifecycle {
    prevent_destroy = true
  }
}

output "prevent_destroy_marker" {
  description = "모듈 삭제 방지를 위한 마커"
  value       = local_file.prevent_destroy_marker.filename
}

output "karpenter" {
  description = "Map of attributes of the Helm release and IRSA created"
  value = module.eks_init.karpenter
}

output "karpenter_iam_role" {
  description = "IAM role name for Karpenter"
  value = aws_iam_role.karpenter_node.name
}

output "karpenter_iam_role_arn" {
  description = "IAM role ARN for Karpenter"
  value = aws_iam_role.karpenter_node.arn
}

