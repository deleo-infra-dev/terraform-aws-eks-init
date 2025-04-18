output "karpenter_version" {
  value = var.karpenter_version
}

output "karpenter_env" {
  value = var.karpenter_env
}

output "karpenter_ami_family" {
  value = var.karpenter_ami_family
}

output "karpenter_instance_families" {
  value = var.karpenter_instance_families
}

output "karpenter_instance_sizes" {
  value = var.karpenter_instance_sizes
}

output "karpenter_node_capacity_type" {
  value = var.karpenter_node_capacity_type
}

output "karpenter_node_iam_role_arn" {
  value = aws_iam_role.karpenter_node_role.arn
}

output "karpenter_node_iam_role_name" {
  value = aws_iam_role.karpenter_node_role.name
}

output "karpenter_node_iam_role_id" {
  value = aws_iam_role.karpenter_node_role.id
}
