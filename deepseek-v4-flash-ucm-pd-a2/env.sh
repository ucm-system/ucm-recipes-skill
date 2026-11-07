#!/usr/bin/env bash
# env.sh - 所有可配置参数。被 10_prefill_node.sh / 11_decode_node.sh / 20_start_proxy.sh / 30_verify.sh 引用。
# 容器内脚本需与本文件同目录（如 /workspace）。
# 参数按"最常改 -> 最不常改"排序。

# ===================== 1. 公共：路径等（最常改） =====================
export MODEL_PATH="/models/DeepSeek-V4-Flash-w8a8-mtp"
export UCM_CONFIG_FILE="/etc/ucm/ucm_pd.yaml"
export UCM_LOG_DIR="/data/ucm/log"
export MOONCAKE_CONNECTOR="MooncakeHybridConnector"   # 可选 MooncakeConnectorV1；P/D 必须一致

# ===================== 2. 节点 IP / 网卡 =====================
export PREFILL_IP="192.168.10.1"
export PREFILL_NIC_NAME="eth0"
export DECODE_IP="192.168.10.2"
export DECODE_NIC_NAME="eth0"
export PROXY_IP="$PREFILL_IP"
export PROXY_PORT="8080"

# ===================== 3. 并行度 =====================
export PREFILL_TP_SIZE="8"
export PREFILL_DP_SIZE="1"
export DECODE_TP_SIZE="1"
export DECODE_DP_SIZE="8"

# ===================== 4. 其他 Prefill 参数 =====================
export PREFILL_PORT="7100"
export PREFILL_DEVICES="0,1,2,3,4,5,6,7"
export PREFILL_MAX_MODEL_LEN="133120"
export PREFILL_MAX_NUM_SEQS="16"
export PREFILL_MAX_NUM_BATCHED_TOKENS="4096"
export PREFILL_GPU_MEM_UTIL="0.9"
export PREFILL_BLOCK_SIZE="128"
export PREFILL_ENABLE_MTP="1"
export PREFILL_NUM_SPEC_TOKENS="1"
export PREFILL_KV_PORT="36000"
export PREFILL_ENGINE_ID="0"
export PREFILL_DP_RPC_PORT="12321"

# ===================== 5. 其他 Decode 参数 =====================
export DECODE_START_PORT="7100"
export DECODE_MAX_MODEL_LEN="133120"
export DECODE_MAX_NUM_SEQS="30"
export DECODE_MAX_NUM_BATCHED_TOKENS="60"
export DECODE_GPU_MEM_UTIL="0.9"
export DECODE_BLOCK_SIZE="128"
export DECODE_ENABLE_MTP="1"
export DECODE_NUM_SPEC_TOKENS="3"
export DECODE_KV_PORT_BASE="36100"
export DECODE_ENGINE_ID_BASE="1"
export DECODE_DP_RPC_PORT="12321"
export DECODE_DP_RANK_START="0"
