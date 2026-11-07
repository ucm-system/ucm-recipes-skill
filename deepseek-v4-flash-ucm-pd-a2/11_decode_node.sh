#!/usr/bin/env bash
# Decode 节点引擎（容器内执行）。参数全部在 env.sh。
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64:/usr/local/lib64/python3.12/site-packages/mooncake:$LD_LIBRARY_PATH
export HCCL_IF_IP="$DECODE_IP"
export GLOO_SOCKET_IFNAME="$DECODE_NIC_NAME"
export TP_SOCKET_IFNAME="$DECODE_NIC_NAME"
export HCCL_SOCKET_IFNAME="$DECODE_NIC_NAME"

export OMP_PROC_BIND=false
export OMP_NUM_THREADS=10
export PYTORCH_NPU_ALLOC_CONF=expandable_segments:True
export LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libjemalloc.so.2:$LD_PRELOAD
export HCCL_BUFFSIZE=1024
export TASK_QUEUE_ENABLE=1
export HCCL_OP_EXPANSION_MODE="AIV"

export ENABLE_UCM_PATCH=1
export UCM_LOG_PATH="$UCM_LOG_DIR"
export UC_LOGGER_LEVEL=info
export VLLM_ENGINE_READY_TIMEOUT_S=6000

SPEC_ARGS=()
if [ "$DECODE_ENABLE_MTP" = "1" ]; then
  SPEC_ARGS=(--speculative-config "{\"num_speculative_tokens\":$DECODE_NUM_SPEC_TOKENS,\"method\":\"mtp\"}")
fi

mkdir -p "$UCM_LOG_DIR"

pids=()
for i in $(seq 0 $((DECODE_DP_SIZE - 1))); do
  rank=$((DECODE_DP_RANK_START + i))
  port=$((DECODE_START_PORT + i))
  kv_port=$((DECODE_KV_PORT_BASE + rank))
  engine_id=$((DECODE_ENGINE_ID_BASE + rank))
  start_card=$((i * DECODE_TP_SIZE))
  device_list=$(seq -s, "$start_card" $((start_card + DECODE_TP_SIZE - 1)))

  KV_CFG=$(cat <<JSON
{
  "kv_connector": "$MOONCAKE_CONNECTOR",
  "kv_role": "kv_consumer",
  "kv_port": "$kv_port",
  "engine_id": "$engine_id",
  "kv_connector_extra_config": {
    "prefill": {"dp_size": $PREFILL_DP_SIZE, "tp_size": $PREFILL_TP_SIZE},
    "decode": {"dp_size": $DECODE_DP_SIZE, "tp_size": $DECODE_TP_SIZE}
  }
}
JSON
)

  echo "[decode] rank=$rank devices=$device_list port=$port kv_port=$kv_port engine_id=$engine_id"
  ASCEND_RT_VISIBLE_DEVICES="$device_list" \
  nohup vllm serve "$MODEL_PATH" \
    --host 0.0.0.0 \
    --port "$port" \
    --data-parallel-size "$DECODE_DP_SIZE" \
    --data-parallel-rank "$rank" \
    --data-parallel-address "$DECODE_IP" \
    --data-parallel-rpc-port "$DECODE_DP_RPC_PORT" \
    --tensor-parallel-size "$DECODE_TP_SIZE" \
    --enable-expert-parallel \
    --seed 1024 \
    --served-model-name dsv4 \
    --max-model-len "$DECODE_MAX_MODEL_LEN" \
    --max-num-batched-tokens "$DECODE_MAX_NUM_BATCHED_TOKENS" \
    --max-num-seqs "$DECODE_MAX_NUM_SEQS" \
    --gpu-memory-utilization "$DECODE_GPU_MEM_UTIL" \
    --tokenizer-mode deepseek_v4 \
    --tool-call-parser deepseek_v4 \
    --enable-auto-tool-choice \
    --reasoning-parser deepseek_v4 \
    --no-enable-prefix-caching \
    --no-disable-hybrid-kv-cache-manager \
    --model-loader-extra-config '{"enable_multithread_load": true, "num_threads": 128}' \
    --quantization ascend \
    --block-size "$DECODE_BLOCK_SIZE" \
    --compilation-config '{"cudagraph_mode": "FULL_DECODE_ONLY"}' \
    --additional-config '{"enable_cpu_binding": true, "multistream_overlap_shared_expert": true, "recompute_scheduler_enable": true}' \
    "${SPEC_ARGS[@]}" \
    --kv-transfer-config "$KV_CFG" \
    > "$UCM_LOG_DIR/decode_rank${rank}.log" 2>&1 &
  pids+=($!)
done

echo "[decode] launched ${#pids[@]} engines. logs: $UCM_LOG_DIR/decode_rank*.log"
trap 'kill ${pids[*]:-} 2>/dev/null' INT TERM
wait
