################################################################################
# 웹훅 설정 수정을 위한 리소스
################################################################################
resource "null_resource" "setup_karpenter_webhooks" {
  depends_on = [
    helm_release.karpenter  # 또는 실제 사용 중인 Karpenter 리소스 이름
  ]

  # 변경 사항이 있을 때만 실행되도록 트리거 추가
  triggers = {
    always_run = timestamp()  # 항상 실행되도록 설정
  }

  provisioner "local-exec" {
    command = <<-EOT
      # Karpenter 파드가 준비될 때까지 대기
      echo "Waiting for Karpenter pods to be ready..."
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=karpenter -n karpenter --timeout=300s || true

      # 현재 웹훅 설정 확인 (디버깅용)
      echo "Checking current webhook configuration..."
      kubectl get crd nodepools.karpenter.sh -o=jsonpath='{.spec.conversion.webhook.clientConfig.service.namespace}' || true

      # CRD의 웹훅 네임스페이스 수정
      echo "Patching CRD webhook settings..."
      kubectl patch crd nodepools.karpenter.sh --type=json -p '[{"op":"replace","path":"/spec/conversion/webhook/clientConfig/service/namespace","value":"karpenter"}]' || true
      kubectl patch crd ec2nodeclasses.karpenter.k8s.aws --type=json -p '[{"op":"replace","path":"/spec/conversion/webhook/clientConfig/service/namespace","value":"karpenter"}]' || true
      kubectl patch crd nodeclaims.karpenter.sh --type=json -p '[{"op":"replace","path":"/spec/conversion/webhook/clientConfig/service/namespace","value":"karpenter"}]' || true

      # 패치 적용 후 Karpenter 파드 재시작 (필요한 경우)
      echo "Restarting Karpenter pods to apply changes..."
      kubectl rollout restart deployment -n karpenter karpenter || true

      # 변경 사항이 적용될 때까지 대기
      echo "Waiting for Karpenter to stabilize after changes..."
      sleep 30
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=karpenter -n karpenter --timeout=300s || true
    EOT
  }
}