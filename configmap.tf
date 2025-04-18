resource "kubernetes_config_map" "aws_logging" {
  metadata {
    name      = "aws-logging"
    namespace = "kube-system"
  }

  data = {
    "log-level" = "info" # 로그 레벨 설정: debug, info, warn, error 중 선택
    # 추가 로깅 설정이 필요한 경우 여기에 추가
  }
}
