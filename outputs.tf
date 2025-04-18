resource "fake" "fake_resource" {
  value = "fake resource for prevent destroy module"
}

output "fake_output" {
  description = "fake output for prevent destroy module"
  value       = fake.fake_resource.value
}

output "karpenter_version" {
  value = var.karpenter_version
}

output "karpenter_node_role_arn" {
  value = aws_iam_role.karpenter_node_role.arn
}

output "karpenter_arn" {
  value = aws_iam_role.karpenter_node_role.arn
}

output "karpenter_ami_family" {
  value = var.karpenter_ami_family
}
