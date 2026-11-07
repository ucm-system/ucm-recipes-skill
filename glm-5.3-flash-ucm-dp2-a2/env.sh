#!/usr/bin/env bash
# env.sh - 所有可配置参数，被 10_node0.sh / 11_node1.sh / 30_verify.sh 引用
# 脚本需与本文件同目录；参数大致按“最常改 -> 最不常改”排序。

# ===================== 1. 公共：路径 / 版本 =====================
export MODEL_PATH="/root/.cache/modelscope/hub/models/vllm-ascend/GLM-5.3-Flash-w8a8"
export UCM_CONFIG_FILE="/workspace/ucm_config_example.yaml"
export UCM_LOG_DIR="/data/ucm/log"
export UCM_CACHE_DIR="/data/ucm/cache"
export SERVED_MODEL_NAME="glm"

# UCM 镜像（已在 vLLM-Ascend v0.30.0rc2 上验证 GLM-5.3-Flash）
# Docker Hub: docker.io/unifiedcachemanager/vllm-ascend:v0.30.0rc2-ucm-0.9.0rc3
export UCM_IMAGE="ghcr.io/modelengine-group/vllm-ascend:v0.30.0rc2-ucm-0.9.0rc3"

# ===================== 2. 节点 IP / 网卡 =====================
export NODE0_IP="192.168.10.1"
export NODE0_NIC_NAME="eth0"
export NODE1_IP="192.168.10.2"
export NODE1_NIC_NAME="eth0"

# ===================== 3. 并行 & DP 配置 =====================
export DP_SIZE="2"
export DP_SIZE_LOCAL="1"
export TP_SIZE="8"
export DP_RPC_PORT="12321"
export DEVICES="0,1,2,3,4,5,6,7"

# ===================== 4. 引擎公共参数 =====================
export API_PORT="8000"
export MAX_MODEL_LEN="133120"
export MAX_NUM_SEQS="32"
export MAX_NUM_BATCHED_TOKENS="8192"
export GPU_MEM_UTIL="0.85"
export ENABLE_MTP="1"
export NUM_SPEC_TOKENS="3"
