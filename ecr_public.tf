################################################################################
# AWS Provider - ECR Public Region (us-east-1)
# This is used to authenticate to the AWS account
# We need to use the us-east-1 provider to access the ECR Public repository
# because it is only available in us-east-1
################################################################################
provider "aws" {
  shared_credentials_files = var.shared_credentials_files
  profile                  = var.profile
  region                   = "us-east-1" # ECR Public is only available in us-east-1 (virginia)
  alias                    = "virginia"  # ECR Public is only available in us-east-1 (virginia)
}

################################################################################
# ECR Public 인증 Token Data (aws_ecrpublic_authorization_token)
## - aws.ecr_public Provider 사용해 ECR Public Authorization Token 조회
## - ECR Public Authorization Token은 US East (N. Virginia) Region에서만 사용 가능 
### - us-east-1 / Virginia (N. Virginia)
################################################################################
data "aws_ecrpublic_authorization_token" "ecr_public_authorization_token" {
  provider = aws.virginia
}

