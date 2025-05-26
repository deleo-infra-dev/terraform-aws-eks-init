################################################################################
# EKS Addons
################################################################################
output "eks_addons" {
  description = "EKS Addons"
  value       = try(module.eks_init.eks_addons, {})
}

################################################################################
# Karpenter
################################################################################
# output "karpenter" {
#   description = "Map of attributes of the Helm release and IRSA created"
#   value       = module.eks_init.karpenter
# }


output "karpenter" {
  description = "Map of attributes of the Helm release and IRSA created"
  value       = try(module.eks_init.karpenter, null)
}


################################################################################
# Fake Output
# This is used to prevent the module from being destroyed
# when the module is imported
################################################################################
output "fake_output" {
  description = "fake output for prevent destroy module"
  value       = fake.fake_resource.value
}

################################################################################
# Karpenter Version
################################################################################
output "karpenter_version" {
  description = "Karpenter version"
  value       = try(var.karpenter_version, null)
}

################################################################################
# Metrics Server
################################################################################
output "metrics_server" {
  description = "EKS Addon Metrics Server - Created"
  value       = try(module.eks_init.metrics_server, null)
}


################################################################################
# CoreDNS
################################################################################
output "coredns" {
  description = "EKS Addon CoreDNS - Created"
  value       = try(module.eks_init.coredns, null)
}

################################################################################
# VPC CNI
################################################################################
output "vpc_cni" {
  description = "EKS Addon VPC CNI - Created"
  value       = try(module.eks_init.vpc_cni, null)
}

################################################################################
# Kube Proxy
################################################################################
output "kube_proxy" {
  description = "EKS Addon Kube Proxy - Created"
  value       = try(module.eks_init.kube_proxy, null)
}

################################################################################
# Fargate Profiles
################################################################################
output "fargate_profiles" {
  description = "Fargate profiles"
  value       = try(module.eks_init.fargate_profiles, null)
}

################################################################################
# Metrics Server Version
################################################################################
output "metrics_server_version" {
  description = "EKS Addon Metrics Server - Version"
  value       = try(module.eks_init.metrics_server_version, null)
}

################################################################################
# CoreDNS Version
################################################################################
output "coredns_version" {
  description = "EKS Addon CoreDNS - Version"
  value       = try(module.eks_init.coredns_version, null)
}

################################################################################
# VPC CNI Version
################################################################################
output "vpc_cni_version" {
  description = "EKS Addon VPC CNI - Version"
  value       = try(module.eks_init.vpc_cni_version, null)
}

################################################################################
# Kube Proxy Version
################################################################################
output "kube_proxy_version" {
  description = "EKS Addon Kube Proxy - Version"
  value       = try(module.eks_init.kube_proxy_version, null)
}
################################################################################
# Fake Resource
# This is used to prevent the module from being destroyed (terraform destroy)
# when the module is imported (terraform import)
################################################################################
resource "fake" "fake_resource" {
  value = "fake resource for prevent destroy module"
}


# output "region" {
#   description = "AWS region"
#   value       = var.region
# }

# output "profile" {
#   description = "AWS profile"
#   value       = var.profile
# }

# output "shared_credentials_files" {
#   description = "AWS shared credentials files"
#   value       = var.shared_credentials_files
# }