resource "fake" "fake_resource" {
  value = "fake resource for prevent destroy module"
}

output "fake_output" {
  description = "fake output for prevent destroy module"
  value       = "${fake.fake_resource.value}"
}

output "karpenter" {
  description = "Map of attributes of the Helm release and IRSA created"
  value = module.aws_eks_init.karpenter
}