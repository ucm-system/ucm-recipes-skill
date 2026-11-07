#!/usr/bin/env bash
# 验证脚本（在节点 0 或任意能访问节点 0 的主机执行）。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

BASE="http://${NODE0_IP}:${API_PORT}"

echo "[verify] health"
curl --fail "$BASE/health"
echo
echo "[verify] models"
curl --fail "$BASE/v1/models"
echo
echo "[verify] chat completion"
curl --fail-with-body "$BASE/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d "{
    \"model\": \"${SERVED_MODEL_NAME}\",
    \"messages\": [
      {\"role\": \"user\", \"content\": \"Explain the role of KV cache in large language model inference.\"}
    ],
    \"max_completion_tokens\": 256,
    \"temperature\": 0
  }"
echo
echo "[verify] ucm metrics"
curl --fail "$BASE/metrics" | grep '^ucm:' || true
