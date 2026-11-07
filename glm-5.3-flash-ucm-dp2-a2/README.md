# GLM-5.3-Flash-w8a8 + UCM 多节点混部（Atlas A2，2 节点 DP2/TP8）

## 版本与兼容性

- 模型：`GLM-5.3-Flash-w8a8`（Atlas A2/A3 通用权重，非 `w8a8-mxfp8`）
- 拓扑：2 × Atlas A2（64GB × 8），跨节点 **DP2**，每节点内 **TP8**
- 推荐镜像：`ghcr.io/modelengine-group/vllm-ascend:v0.30.0rc2-ucm-0.9.0rc3`
  - Docker Hub：`docker.io/unifiedcachemanager/vllm-ascend:v0.30.0rc2-ucm-0.9.0rc3`
  - UCM `v0.9.0rc3` 明确验证了 vLLM-Ascend `v0.30.0rc2` 上的 GLM-5.3-Flash
- **vLLM-Ascend `v0.32.0rc` 暂无 UCM 验证通过版本**。若坚持使用：
  标准镜像 `quay.io/ascend/vllm-ascend:nightly-releases-v0.32.0rc` +
  容器内 `pip install "uc-manager[cann921-a2]==0.9.0"`，但属未验证组合。

## 参数配置

所有可配置参数集中在 **`env.sh`**：

- 公共：`MODEL_PATH`、`UCM_CONFIG_FILE`、`UCM_LOG_DIR`、`UCM_CACHE_DIR`、`SERVED_MODEL_NAME`、`UCM_IMAGE`
- 节点：`NODE0_IP`、`NODE0_NIC_NAME`、`NODE1_IP`、`NODE1_NIC_NAME`
- 并行：`DP_SIZE`、`DP_SIZE_LOCAL`、`TP_SIZE`、`DP_RPC_PORT`、`DEVICES`
- 引擎：`API_PORT`、`MAX_MODEL_LEN`、`MAX_NUM_SEQS`、`MAX_NUM_BATCHED_TOKENS`、`GPU_MEM_UTIL`、`ENABLE_MTP`、`NUM_SPEC_TOKENS`

两节点网卡可不同（`NODE0_NIC_NAME` / `NODE1_NIC_NAME`）；`MODEL_PATH` 建议放共享目录，
如 `/root/.cache/`，否则两节点各自保存一份。

## 文件放置

脚本必须与 `env.sh` 放在容器内同一目录（下称 `/workspace`）。

**节点 0（192.168.10.1）容器：**
```
/workspace/  env.sh  10_node0.sh  30_verify.sh  ucm_config_example.yaml
/data/ucm/    cache/  log/
```

**节点 1（192.168.10.2）容器：**
```
/workspace/  env.sh  11_node1.sh  ucm_config_example.yaml
/data/ucm/    cache/  log/
```

两节点都需要 `ucm_config_example.yaml`（`kv_role=kv_both`，各自本地缓存；
想跨节点复用就把它挂到共享文件系统）。

## 拉起服务（容器内执行）

1. 节点 1（headless，先起）：
```
bash /workspace/11_node1.sh
```
2. 节点 0（提供 API）：
```
bash /workspace/10_node0.sh
```
3. 验证（节点 0 或任意可访问节点）：
```
bash /workspace/30_verify.sh
```

服务入口：`http://<NODE0_IP>:8000`，`model` 为 `glm`。混部模式由节点 0 的 DP
内置负载均衡，**不需要额外代理**。

## 关键注意事项

- **UCM 生效判断**：启动日志应出现 `create UcmPipelineStore with config:`，并包含
  `/data/ucm/cache`；仅 health 通过不代表缓存命中。
- **精度**：`ucm_config_example.yaml` 中 `posix_data_trans_concurrency: 1` 用于规避
  UCM v0.9.0rc3 并发 layerwise 读写降精度问题（issue #1544），不建议随意调高。
- **端口放行**：两节点间需通 DP RPC `12321`、API `8000` 及 HCCL socket 端口。
- **`--data-parallel-start-rank`**：节点 0 不设置（自动 rank 0），节点 1 显式设为 1；
  节点 1 必须带 `--headless`。
- **权重格式**：A2 用 `GLM-5.3-Flash-w8a8`；不要和 950DT 的 `w8a8-mxfp8` 混用。
- **首次验证建议**：先把 `ENABLE_MTP=0` 跑通、确认 UCM 命中，再开 MTP。
- 请求入口是节点 0 的 API 端口，不是各 DP rank 的内部端口。
