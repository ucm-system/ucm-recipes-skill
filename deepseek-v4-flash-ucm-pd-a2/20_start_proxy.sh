#!/usr/bin/env bash
# PD 代理：请求先到 Prefill（计算并缓存/传输 KV），再转发 Decode 生成。
# 在容器内执行：bash /workspace/20_start_proxy.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

PROXY_HOST="0.0.0.0"
PROXY_PY="$SCRIPT_DIR/load_balance_proxy_server_example.py"

if [ ! -f "$PROXY_PY" ]; then
  echo "[proxy] downloading from vllm-ascend examples ..."
  curl -fsSL -o "$PROXY_PY" \
    "https://raw.githubusercontent.com/vllm-project/vllm-ascend/main/examples/disaggregated_prefill_v1/load_balance_proxy_server_example.py"
fi

DECODER_HOSTS=()
DECODER_PORTS=()
for i in $(seq 0 $((DECODE_DP_SIZE - 1))); do
  DECODER_HOSTS+=("$DECODE_IP")
  DECODER_PORTS+=("$((DECODE_START_PORT + i))")
done

python3 "$PROXY_PY" \
  --host "$PROXY_HOST" \
  --port "$PROXY_PORT" \
  --prefiller-hosts "$PREFILL_IP" \
  --prefiller-ports "$PREFILL_PORT" \
  --decoder-hosts "${DECODER_HOSTS[@]}" \
  --decoder-ports "${DECODER_PORTS[@]}"
