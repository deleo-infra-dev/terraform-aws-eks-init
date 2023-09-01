output "karpenter" {
  description = "Map of attributes of the Helm release and IRSA created"
  value = module.eks_init.karpenter
}