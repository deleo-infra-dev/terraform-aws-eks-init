locals {

  region                   = var.region                   # AWS 리전
  profile                  = var.profile                  # AWS 프로파일
  shared_credentials_files = var.shared_credentials_files # AWS 자격 증명 파일
  eks_pod_subnet_ids       = var.eks_pod_subnet_ids       # EKS Pod 서브넷 ID
  azs                      = var.azs                      # 가용 영역

  # EKS 클러스터 정보 #
  cluster_name                      = var.cluster_name                      # EKS 클러스터 이름
  cluster_endpoint                  = var.cluster_endpoint                  # EKS 클러스터 엔드포인트
  cluster_version                   = var.cluster_version                   # EKS 클러스터 버전
  oidc_provider_arn                 = var.oidc_provider_arn                 # OIDC 프로바이더 ARN
  cluster_ca_certificate            = var.cluster_ca_certificate            # EKS 클러스터 CA 인증서
  cluster_primary_security_group_id = var.cluster_primary_security_group_id # 클러스터 기본 보안 그룹 ID

  karpenter_version = var.karpenter_version # Karpenter 버전

  karpenter_env                = var.karpenter_env                # Karpenter 환경
  karpenter_ami_family         = var.karpenter_ami_family         # Karpenter AMI 패밀리
  karpenter_instance_families  = var.karpenter_instance_families  # Karpenter 인스턴스 패밀리 (FAMILY)
  karpenter_instance_sizes     = var.karpenter_instance_sizes     # Karpenter 인스턴스 크기 (SIZE)
  karpenter_node_capacity_type = var.karpenter_node_capacity_type # Karpenter 노드 용량 유형 (온디맨드 또는 스팟)

  ###### addon values ######
  coreDNS-version = var.coreDNS-version # CoreDNS 버전
  vpc-cni-version      = var.vpc-cni-version     # CNI 버전
  kube-proxy-version = var.kube-proxy-version # Kube Proxy 버전

}
