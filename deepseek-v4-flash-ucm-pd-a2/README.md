# DeepSeek-V4-Flash-w8a8-mtp + UCM PD 分离（Transport / MultiConnector）

## 参数配置
所有可配置参数都在 **`env.sh`** 中，按 `PREFILL_*` / `DECODE_*` / 公共 / 代理分组：

- 公共：`MODEL_PATH`、`MOONCAKE_CONNECTOR`、`UCM_CONFIG_FILE`、`UCM_LOG_DIR`
- Prefill：`PREFILL_IP`、`PREFILL_NIC_NAME`、`PREFILL_PORT`、`PREFILL_DEVICES`、`PREFILL_DP_SIZE`、`PREFILL_TP_SIZE`、`PREFILL_MAX_MODEL_LEN`、`PREFILL_MAX_NUM_SEQS`、`PREFILL_MAX_NUM_BATCHED_TOKENS`、`PREFILL_GPU_MEM_UTIL`、`PREFILL_BLOCK_SIZE`、`PREFILL_ENABLE_MTP`、`PREFILL_NUM_SPEC_TOKENS`、`PREFILL_KV_PORT`、`PREFILL_ENGINE_ID`、`PREFILL_DP_RPC_PORT`
- Decode：`DECODE_IP`、`DECODE_NIC_NAME`、`DECODE_START_PORT`、`DECODE_DP_SIZE`、`DECODE_TP_SIZE`、`DECODE_MAX_MODEL_LEN`、`DECODE_MAX_NUM_SEQS`、`DECODE_MAX_NUM_BATCHED_TOKENS`、`DECODE_GPU_MEM_UTIL`、`DECODE_BLOCK_SIZE`、`DECODE_ENABLE_MTP`、`DECODE_NUM_SPEC_TOKENS`、`DECODE_KV_PORT_BASE`、`DECODE_ENGINE_ID_BASE`、`DECODE_DP_RPC_PORT`、`DECODE_DP_RANK_START`
- 代理：`PROXY_IP`、`PROXY_PORT`

注意：`PREFILL_NIC_NAME` / `DECODE_NIC_NAME` 两节点网卡可不同；P/D 的 `MOONCAKE_CONNECTOR` 与 dp/tp 布局（`PREFILL_DP/TP_SIZE`、`DECODE_DP/TP_SIZE`）必须匹配。kv_port 建议 >= 36000。

## 文件放置

所有脚本必须与 `env.sh` 放在容器内同一目录（以下称 `/workspace`）；`env.sh` 中的 `UCM_CONFIG_FILE` 指向 `/etc/ucm/`。

**Prefill 节点（192.168.10.1）容器**
```
/workspace/   env.sh  10_prefill_node.sh  20_start_proxy.sh  30_verify.sh
/etc/ucm/     ucm_pd.yaml
```

**Decode 节点（192.168.10.2）容器**
```
/workspace/   env.sh  11_decode_node.sh  30_verify.sh
```
（Decode 不读 UCM，无需配置文件。）

## 拉起服务（容器内执行）

1. Prefill 节点：
```
bash /workspace/10_prefill_node.sh
```
2. Decode 节点：
```
bash /workspace/11_decode_node.sh
```
3. 代理（任一节点）：
```
bash /workspace/20_start_proxy.sh
```
4. 验证：
```
bash /workspace/30_verify.sh
```

服务入口：`http://<PREFILL_IP>:8080`，model 名 `dsv4`。
