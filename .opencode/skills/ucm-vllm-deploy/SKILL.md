---
name: ucm-vllm-deploy
description: >
  Generate deployment scripts, configs and a README for running a model on
  vLLM / vLLM-Ascend with UCM (unified-cache-management) via --kv-transfer-config.
  Use when the user asks to deploy a model (DeepSeek / Qwen / GLM / MiniMax / Kimi ...)
  with UCM, wants `vllm serve` launch scripts, P/D disaggregation (PD 分离),
  single-node or multi-node deployment, MooncakeTransport, Shared-store, or a
  kv-transfer-config. 触发词：部署脚本、拉起服务、PD 分离、单机/多机部署、kv-transfer-config、UCM、vllm-ascend。
---

# UCM × vLLM-Ascend 模型部署

为模型生成「带 UCM 的 vLLM/vLLM-Ascend 推理服务」部署产物：脚本 + 配置 + README。
流程：先问清需求 → 上网查官方文档 → 核对兼容性 → 判断拓扑 → 选 PD 方案 → **落盘生成产物**。

> **铁律（最高优先级）**：无论用户说「给命令」「怎么部署」还是「给个示例」，最终都必须
> **用 write 工具创建一个目录并写入文件**（env.sh + 引擎脚本 + UCM yaml + 验证脚本 + README.md），
> 不能只在回复里贴命令。回复正文只做摘要（兼容性结论、拓扑、要改的参数、拉起顺序、目录路径）。

## 第 1 步：先问清需求（用 question 工具，不要凭空假设）

当用户只给了「模型」时，必须先确认：

1. **模型**：完整名称/变体（如 `DeepSeek-V4-Flash-w8a8-mtp`）、权重路径。
2. **硬件**：厂商（NPU/GPU）、型号（Atlas 800 A2/A3/A5、910B/910C、H100...）、**每节点卡数**、**单卡显存**、**节点数**。
3. **环境/版本**：已装 vllm-ascend 版本、CANN 版本、UCM 版本/whl、是否已有预装镜像（有镜像就别打镜像）。
4. **部署方式**：单机 / 多机混合 / 多节点 PD 分离（1P1D、xPyD...）。
5. **网络**：节点 IP、HCCL 网卡名（两节点可不同）、端口；Shared-store 还需共享文件系统。

用户明确说"只用某版本"时，据此反查兼容的 UCM/镜像，不要强行换版本。

## 第 2 步：查官方文档（webfetch）

- vllm-ascend 文档索引（按版本）：`https://docs.vllm.ai/projects/ascend/zh-cn/`
- 模型教程：`https://docs.vllm.ai/projects/ascend/zh-cn/<ver>/tutorials/models/<Model>.html`
  （给出最小硬件配置、单机 serve 全参数、单机/多节点 PD 脚本、关键参数说明）
- Mooncake PD 多机：`.../tutorials/features/pd_disaggregation_mooncake_multi_node.html`
- UCM 文档：`https://ucm.readthedocs.io/en/<ver>/`
  - `user-guide/support-matrix/`（模型 × 引擎 支持矩阵）
  - `user-guide/model-tour/`（各模型 UCM 拉起示例）
  - `user-guide/quick_start/`（镜像 / wheel 安装）
  - `user-guide/capabilities/pd-disaggregation/`：`/centralized/`=Shared-store，`/distributed/`=Transport with UCM
- UCM Releases（版本 ↔ vllm-ascend 适配 + 镜像 tag）：`https://github.com/ModelEngine-Group/unified-cache-management/releases`

抓取重点：模型最小配置、单机 serve 命令与全部关键参数、P/D 脚本、`kv_connector` 名称、`kv_port` 规则。
Releases 页面可能很大被截断；被截断时用 explore/grep 读保存的 `tool-output` 文件，不要重复整页抓取。

## 第 3 步：核对兼容性（给脚本前必做）

1. 在 UCM release 说明里按 **CANN / 平台(A2/A3/A5)** 找它验证过的 vllm-ascend tag 和镜像 tag，用用户版本去匹配。
2. 无精确匹配时，选"验证了该版本线"的最近 UCM（例：vllm-ascend `v0.26.0rc1/rc2` → UCM `v0.8.1`；UCM `v0.9.0` 只验证 `v0.27.1rc1`/`v0.30.0`）。
3. 用 `support-matrix` 确认"模型 @ 目标引擎 = Supported / Unverified"。
4. 明确告知 rc 差异与未验证组合风险；给出确切镜像 tag，例如：
   `ghcr.io/modelengine-group/vllm-ascend:v0.26.0rc2-ucm-0.8.1`（Docker Hub 镜像名同理）。

## 第 4 步：判断拓扑可行性

- **单机**：对照官方最小配置（如 w8a8 需 A2 64GB×8 或 A3 128GB×8）。
- **多机混部（非 PD）**：如 A2 单机放不下 → 2 节点 DP2/TP8；主节点提供 API，其他节点 `--headless`。
  无需代理、无需 Mooncake；UCM 用单个 `UCMConnector(kv_both)`，两节点各放一份 yaml。
- **PD 1P1D**：2 节点够用；P/D 的 TP/DP 按显存与官方建议定（例：P DP1TP8 / D DP8TP1）。
- 官方"最佳性能"拓扑可能要 4P1D 等多节点；节点不足就降级为 1P1D 并说明取舍。
- Shared-store 要求 **P/D 相同 TP + 共享文件系统**；Transport 允许非对称布局、**无需共享存储**。

## 第 5 步：选 PD 方案

- **默认 Transport with UCM**（用户要 PD + UCM 时首选）：
  - P：`--kv-transfer-config MultiConnector`，`kv_role=kv_producer`，内嵌 `[Mooncake producer, UCMConnector(kv_both)]`。
  - D：Mooncake `kv_consumer`（每个引擎一个）。
  - `metadata_server: P2PHANDSHAKE` 时**不要**启动 `mooncake_master`，也**不需要** `mooncake.json` / `MOONCAKE_CONFIG_PATH`。
- **Shared-store PD**（仅当用户明确"不用 Mooncake"且能提供共享存储）：P/D 都 `UCMConnector(kv_both)` 共用存储，代理用 `toy_proxy_server.py`。
- **单机**：用 model-tour 单节点命令 + `UCMConnector(kv_both, kv_connector_module_path=ucm.integration.vllm.ucm_connector)`。

## 第 6 步：生成产物（必须创建目录并落盘）

**先建目录再写文件**（用 bash `New-Item`/`mkdir` + write 工具），目录名：
`<模型小写>-<方案>-<平台>`，例如 `glm-5.3-flash-ucm-dp2-a2`、`deepseek-v4-flash-ucm-pd-a2`。
目录放在工作区根目录（或用户指定位置），**不要在回复里只贴命令了事**。

每个目录至少包含：

| 文件 | 内容 |
| --- | --- |
| `env.sh` | 所有可配置参数，**唯一**的改动入口 |
| `10_*.sh` / `11_*.sh` | 各节点/各角色引擎脚本（单机则一个 `10_serve.sh`） |
| `ucm_config_example.yaml` | UCM 配置（`UcmPipelineStore` + `storage_backends`） |
| `30_verify.sh` | health / models / chat / `ucm:` metrics 验证 |
| `README.md` | 参数清单、文件放置、拉起顺序、关键注意事项、兼容性 |

命名约定：
- **PD 分离**：`10_prefill_node.sh`、`11_decode_node.sh`、`20_start_proxy.sh`。
- **多机混部**：`10_node0.sh`、`11_node1.sh`（节点 0 提供 API，节点 1 `--headless`）。
- **单机**：`10_serve.sh`。
- 统一 `source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"`，不硬编码。
- `--kv-transfer-config` 用 heredoc 组装；MTP 用 `*_ENABLE_MTP` / `*_NUM_SPEC_TOKENS` 控制。
- 空数组展开用 `${SPEC_ARGS[@]+"${SPEC_ARGS[@]}"}`，避免 `set -u` 下旧 bash 报错。
- **不要**构建镜像 / 不要写 docker run，除非用户明确要求；默认用户已有镜像与 UCM whl。
- 文件写完后用 bash 列目录确认存在；没有 bash 时用 Read 复核关键脚本。

## 第 7 步：关键参数经验

- 通用：`--enable-expert-parallel`、`--quantization ascend`、`--trust-remote-code`；GLM 用
  `--tool-call-parser glm47`、`--reasoning-parser glm47`、`--enable-auto-tool-choice`。
- DeepSeek-V4：`--tokenizer-mode/tool-call-parser/reasoning-parser deepseek_v4`、`--block-size 128`；
  PD 需 `--no-disable-hybrid-kv-cache-manager`（否则启动 OOM）；UCM 侧通常 `--no-enable-prefix-caching`。
- GLM-5.3-Flash：MTP 用 `{"method":"deepseek_mtp"}`；A2 混部不设 `--kv-cache-dtype`，A3 单机用
  `--kv-cache-dtype int8 --attention-config.indexer_kv_dtype int8`；多模态加 `--limit-mm-per-prompt`。
- MTP：先 `ENABLE_MTP=0` 验证 UCM 命中，再开；P 常用 1，D 用实际值（如 3/5）。
- `kv_port` 避开 AscendDirectTransport 预留端口：8 卡节点 >= 28000，16 卡或保守用 **>= 36000**；每个引擎端口唯一。
- `engine_id` 全局唯一：P=0，D=1..N。
- DSV4 用 `MooncakeHybridConnector`（UCM 通用示例是 `MooncakeConnectorV1`），P/D 必须一致。
- UCM `posix_data_trans_concurrency: 1` 可规避并发 layerwise 读写降精度（issue #1544）。

## 常见坑

- **只回复不落盘** → 必须创建目录并写 `env.sh` / 脚本 / `ucm_config_example.yaml` / `README.md`。
- 多机混部误用 PD 代理 → 混部由主节点 DP 内置负载均衡，不需要代理/Mooncake。
- `--data-parallel-start-rank` / `--headless`：节点 0 不设 rank，节点 1 显式 rank=1 且 `--headless`。
- UCM 版本不匹配（如 UCM v0.9.0 不含 v0.26 系列）→ 降到验证过该版本线的 UCM。
- "路径相同"不等于"共享存储"。
- `UCMConnector` 需要 `ENABLE_UCM_PATCH=1` 且 `kv_connector_module_path` 正确。
- 请求入口是代理端口（PD）或主节点 API（混部），不是各 DP rank 内部端口。
- 大文档抓取被截断时，用 explore/grep 读已保存的 tool-output，不要重复整页抓。

## 最终交付（检查清单）

必须完成以下全部项，缺一不可：

1. [ ] 已创建目录 `<模型>-<方案>-<平台>/`（用 bash 建目录，write 写文件）。
2. [ ] `env.sh` 集中全部可配置参数（模型路径、镜像、IP/NIC、并行度、MTP…）。
3. [ ] 各角色脚本可 `source env.sh` 直接跑，不硬编码。
4. [ ] `ucm_config_example.yaml` 已生成，并在脚本里通过 `UCM_CONFIG_FILE` 引用。
5. [ ] `30_verify.sh` 含 health / models / chat / `ucm:` metrics。
6. [ ] `README.md` 含兼容性、参数、**文件放置**、拉起顺序、注意事项。
7. [ ] 回复正文给出目录路径 + 兼容性结论 + 拓扑取舍 + 需改参数 + 拉起顺序（简短即可）。
