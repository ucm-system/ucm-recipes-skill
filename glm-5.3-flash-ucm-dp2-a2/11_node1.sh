#!/usr/bin/env bash
# 节点 1（DP rank 1，headless）引擎脚本（容器内执行）。参数全部来自 env.sh。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

export HCCL_IF_IP="$NODE1_IP"
export GLOO_SOCKET_IFNAME="$NODE1_NIC_NAME"
export TP_SOCKET_IFNAME="$NODE1_NIC_NAME"
export HCCL_SOCKET_IFNAME="$NODE1_NIC_NAME"

export VLLM_USE_V2_MODEL_RUNNER=1
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True
export HCCL_OP_EXPANSION_MODE="AIV"
export HCCL_BUFFSIZE=1024
export VLLM_RPC_TIMEOUT=3600000
export VLLM_EXECUTE_MODEL_TIMEOUT_SECONDS=3000
export HCCL_EXEC_TIMEOUT=3600
export HCCL_CONNECT_TIMEOUT=1200
export ASCEND_RT_VISIBLE_DEVICES="$DEVICES"

export ENABLE_UCM_PATCH=1
export UCM_LOG_PATH="$UCM_LOG_DIR"

mkdir -p "$UCM_LOG_DIR" "$UCM_CACHE_DIR"

SPEC_ARGS=()
if [ "$ENABLE_MTP" = "1" ]; then
  SPEC_ARGS=(--speculative-config "{\"num_speculative_tokens\":$NUM_SPEC_TOKENS,\"method\":\"deepseek_mtp\",\"enforce_eager\":true}")
fi

KV_CFG=$(cat <<JSON
{
  "kv_connector": "UCMConnector",
  "kv_connector_module_path": "ucm.integration.vllm.ucm_connector",
  "kv_role": "kv_both",
  "kv_connector_extra_config": {
    "UCM_CONFIG_FILE": "$UCM_CONFIG_FILE"
  }
}
JSON
)

vllm serve "$MODEL_PATH" \
  --host 0.0.0.0 \
  --port "$API_PORT" \
  --headless \
  --data-parallel-start-rank 1 \
  --max-model-len "$MAX_MODEL_LEN" \
  --data-parallel-size "$DP_SIZE" \
  --data-parallel-size-local "$DP_SIZE_LOCAL" \
  --data-parallel-address "$NODE0_IP" \
  --data-parallel-rpc-port "$DP_RPC_PORT" \
  --tensor-parallel-size "$TP_SIZE" \
  --enable-expert-parallel \
  --seed 1024 \
  --served-model-name "$SERVED_MODEL_NAME" \
  --safetensors-load-strategy prefetch \
  --max-num-seqs "$MAX_NUM_SEQS" \
  --max-num-batched-tokens "$MAX_NUM_BATCHED_TOKENS" \
  --trust-remote-code \
  --quantization ascend \
  --limit-mm-per-prompt '{"image":1,"video":0}' \
  --gpu-memory-utilization "$GPU_MEM_UTIL" \
  ${SPEC_ARGS[@]+"${SPEC_ARGS[@]}"} \
  --compilation-config '{"cudagraph_mode":"FULL_DECODE_ONLY","cudagraph_capture_sizes":[4,8,16,32,64,96,128]}' \
  --kv-transfer-config "$KV_CFG"
