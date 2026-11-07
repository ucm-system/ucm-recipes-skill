#!/usr/bin/env bash
# Prefill 节点引擎（容器内执行）。参数全部在 env.sh。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64:/usr/local/lib64/python3.12/site-packages/mooncake:$LD_LIBRARY_PATH
export HCCL_IF_IP="$PREFILL_IP"
export GLOO_SOCKET_IFNAME="$PREFILL_NIC_NAME"
export TP_SOCKET_IFNAME="$PREFILL_NIC_NAME"
export HCCL_SOCKET_IFNAME="$PREFILL_NIC_NAME"

export OMP_PROC_BIND=false
export OMP_NUM_THREADS=10
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True
export LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libjemalloc.so.2:$LD_PRELOAD
export HCCL_BUFFSIZE=1024
export TASK_QUEUE_ENABLE=1
export HCCL_OP_EXPANSION_MODE="AIV"
export ASCEND_RT_VISIBLE_DEVICES="$PREFILL_DEVICES"

export ENABLE_UCM_PATCH=1
export UCM_LOG_PATH="$UCM_LOG_DIR"
export UC_LOGGER_LEVEL=info
export VLLM_ENGINE_READY_TIMEOUT_S=6000

SPEC_ARGS=()
if [ "$PREFILL_ENABLE_MTP" = "1" ]; then
  SPEC_ARGS=(--speculative-config "{\"num_speculative_tokens\":$PREFILL_NUM_SPEC_TOKENS,\"method\":\"mtp\"}")
fi

KV_CFG=$(cat <<JSON
{
  "kv_connector": "MultiConnector",
  "kv_role": "kv_producer",
  "kv_connector_extra_config": {
    "connectors": [
      {
        "kv_connector": "$MOONCAKE_CONNECTOR",
        "kv_role": "kv_producer",
        "kv_port": "$PREFILL_KV_PORT",
        "engine_id": "$PREFILL_ENGINE_ID",
        "kv_connector_extra_config": {
          "prefill": {"dp_size": $PREFILL_DP_SIZE, "tp_size": $PREFILL_TP_SIZE},
          "decode": {"dp_size": $DECODE_DP_SIZE, "tp_size": $DECODE_TP_SIZE}
        }
      },
      {
        "kv_connector": "UCMConnector",
        "kv_role": "kv_both",
        "kv_connector_module_path": "ucm.integration.vllm.ucm_connector",
        "kv_connector_extra_config": {"UCM_CONFIG_FILE": "$UCM_CONFIG_FILE"}
      }
    ]
  }
}
JSON
)

vllm serve "$MODEL_PATH" \
  --host 0.0.0.0 \
  --port "$PREFILL_PORT" \
  --data-parallel-size "$PREFILL_DP_SIZE" \
  --data-parallel-rank 0 \
  --data-parallel-address "$PREFILL_IP" \
  --data-parallel-rpc-port "$PREFILL_DP_RPC_PORT" \
  --tensor-parallel-size "$PREFILL_TP_SIZE" \
  --enable-expert-parallel \
  --seed 1024 \
  --served-model-name dsv4 \
  --max-model-len "$PREFILL_MAX_MODEL_LEN" \
  --max-num-batched-tokens "$PREFILL_MAX_NUM_BATCHED_TOKENS" \
  --max-num-seqs "$PREFILL_MAX_NUM_SEQS" \
  --gpu-memory-utilization "$PREFILL_GPU_MEM_UTIL" \
  --tokenizer-mode deepseek_v4 \
  --tool-call-parser deepseek_v4 \
  --enable-auto-tool-choice \
  --reasoning-parser deepseek_v4 \
  --no-enable-prefix-caching \
  --no-disable-hybrid-kv-cache-manager \
  --model-loader-extra-config '{"enable_multithread_load": true, "num_threads": 128}' \
  --quantization ascend \
  --block-size "$PREFILL_BLOCK_SIZE" \
  --enforce-eager \
  --additional-config '{"enable_cpu_binding": true, "enable_dsa_cp": true, "enable_flashcomm1": true}' \
  "${SPEC_ARGS[@]}" \
  --kv-transfer-config "$KV_CFG"
