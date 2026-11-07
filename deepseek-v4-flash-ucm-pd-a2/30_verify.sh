#!/usr/bin/env bash
# 验证脚本：请求经代理走 P -> UCM/Mooncake -> D；再查 P 节点 UCM 指标。
# 在容器内执行：bash /workspace/30_verify.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

echo "== chat completion via PD proxy (P -> Mooncake/UCM -> D) =="
curl -sS --fail-with-body "http://${PROXY_IP}:${PROXY_PORT}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "dsv4",
    "messages": [
      {
        "role": "user",
        "content": "Explain the role of KV cache in large language model inference."
      }
    ],
    "max_completion_tokens": 256,
    "temperature": 0
  }'
echo

echo "== Prefill 节点 UCM 指标（外部命中/加载） =="
curl -sS "http://${PREFILL_IP}:${PREFILL_PORT}/metrics" 2>/dev/null | grep -i '^ucm' | head -20 || echo "(未获取到 ucm 指标，确认 PREFILL_IP/PREFILL_PORT 后重试)"

echo
echo "== 重复同前缀以触发 UCM 复用（二次请求应出现 external hit） =="
curl -sS --fail-with-body "http://${PROXY_IP}:${PROXY_PORT}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "dsv4",
    "messages": [
      {
        "role": "user",
        "content": "Explain the role of KV cache in large language model inference."
      }
    ],
    "max_completion_tokens": 256,
    "temperature": 0
  }'
echo
