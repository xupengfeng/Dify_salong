# 本机环境审核与部署方案

审核日期：2026-10-31，时区 Asia/Singapore。

本轮范围为本机只读审核和部署规划。没有安装软件、启动服务、拉取镜像、创建运行环境或修改 Docker/WSL 配置；后文步骤均为待执行方案。

## 1. 结论与执行顺序

本机已具备 Windows、WSL2 和 Docker Desktop 基础，有条件适合单人、小语料的 Dify 实验。当前 Docker 引擎未运行，尚不能认定部署或模型连通性已经通过。

建议先在本机完成环境、三类云模型及最小知识库问答验证，继而完成语料治理、检索对照、工作流编排与边界实验；待本机实验顺利结束并整理可复现成果后，再根据参与人数和并发需求规划、搭建远程共享环境。

本机阶段采用 Docker Desktop + WSL2、固定 Dify 1.18.0 官方 Compose、PostgreSQL 和 Weaviate。LLM 与 Embedding 接入课题组模型平台（OpenAI 兼容公网接口）；平台不提供 Rerank 模型，知识库调优组改用混合检索权重模式（见第 4.1 节）。保留官方服务拓扑，不启用可选的 Agent KnowledgeFS。

选择 1.18.0 的依据是截至本次审核所查到的官方发布版本，发布日期为 2026-10-23；实施时固定 tag 对应的完整 commit，并记录镜像 digest。[官方发布](https://github.com/langgenius/dify/releases/tag/1.18.0)

## 2. 本机审核结果

下表为本轮宿主机只读检查结果，内存和磁盘以 GiB 表示，不代表容器当前可分配资源。

| 项目 | 实测结果 | 对部署的含义 |
| --- | --- | --- |
| 操作系统 | Windows 10 Enterprise，10.0.19045.6456 | 需确认操作系统支持与维护状态 |
| CPU | AMD Ryzen 7 5800H，16 个逻辑处理器 | 具备小规模实验的计算基础 |
| 物理内存 | 总计约 15.4 GiB，空闲约 4.5 GiB | 当前余量偏紧，启动前先释放内存 |
| 磁盘可用空间 | C: 48.0 GiB；D: 61.2 GiB；E: 386.0 GiB | 不能因 E 盘空间充足就推定 WSL 运行数据在 E 盘 |
| Docker Desktop | 4.43.2.199162 | 已安装，运行能力尚待启动后核实 |
| Docker CLI / Compose | 28.3.2 / 2.38.2-desktop.1 | 版本符合本轮所查官方 Compose 最低要求 |
| WSL / 内核 | 2.5.9.0 / 6.6.87.2-1 | 已安装 WSL2 基础 |
| WSL 发行版 | Ubuntu-22.04、docker-desktop 均为 WSL2，均 Stopped | 当前未启动 Linux 运行环境 |
| Docker context | desktop-linux；对应引擎 pipe 不存在 | 当前没有可用的该 context 引擎连接 |
| Docker Windows 服务 | com.docker.service 为 Stopped / Manual | 仅此状态不能独立判定 Docker Desktop 故障 |
| 文件共享服务 | LanmanServer 为 Running / Automatic | 已记录当前状态 |
| 虚拟化 | 固件虚拟化为 true，HypervisorPresent 为 true | 仍需启动引擎确认实际运行 |
| 资源配置 | 无用户 `.wslconfig`；Docker 仅明确 AutoStart=false | 其他资源值未显式设置，未核实引擎可见总内存 |

CIM 的 SLAT 字段返回 false，与现有 WSL2/Hypervisor 状态一起看，不能单凭该字段归因为硬件缺失。本轮不为此修改固件、系统组件或安全设置。

Docker 的 Windows 安装要求仍列出 Windows 10 22H2、build 19045 和 WSL 2.1.5 及以上，同时要求系统处于 Microsoft servicing 范围。Windows 10 常规支持已于 2025-10-14 结束，本机 ESU/适用维护状态尚未核实；这属于支持范围待确认，不能直接等同于软件无法运行。[Docker 要求](https://docs.docker.com/desktop/setup/install/windows-install/)、[Windows 状态](https://learn.microsoft.com/en-us/windows/release-health/status-windows-10-22h2)

### 2.1 端口与网络

| 检查对象 | 实测结果 | 证据边界 |
| --- | --- | --- |
| TCP 80、443、8080、8081 | 当前无监听 | 仅代表检查时刻未占用 |
| TCP 3000、5001、11434 | 当前无监听 | 不意味着后续需要发布这些端口 |
| TCP 5003 | 当前无监听 | 插件调试端口实施时仍需限制绑定 |
| GitHub API | 一次宿主机 HEAD，HTTP 200 | 宿主机该端点当时可达 |
| Docker Registry `/v2/` | 一次宿主机 HEAD，HTTP 401 | 预期鉴权挑战，说明 HTTPS 端点可达，不证明镜像层能拉取 |
| Dify Marketplace | 一次宿主机 HEAD，HTTP 200 | 不证明容器网络、插件安装或模型调用已成功 |
| 云模型 API | 未验证 | 2026-10-31 已选定课题组模型平台（公网可直连），尚未实际调用 |

后续如实际拉取或插件安装失败，再围绕具体失败检查引擎 DNS、代理或目标连接；本轮不调整全局网络配置。

### 2.2 当前路径边界

Ubuntu 注册的 BasePath 位于 `C:\Users\Xu\AppData\Local\Packages\CanonicalGroupLimited.Ubuntu22.04LTS_79rhkp1fndgsc\LocalState`。

docker-desktop 注册的 BasePath 位于 `E:\Program Files\DockerDesktopWSL\DockerDesktopWSL\DockerDesktopWSL\main`。

另已确认 Docker 真实数据虚拟磁盘位于 `E:\Program Files\DockerDesktopWSL\DockerDesktopWSL\DockerDesktopWSL\disk\docker_data.vhdx`，文件逻辑长度约 10.77 GiB；同根 `main\ext4.vhdx` 约 0.14 GiB。Ubuntu 在 C 盘的 `ext4.vhdx` 文件逻辑长度约 4.12 GiB。

文件逻辑长度不代表磁盘可用容量或容器实际已用空间。现已区分 Docker 镜像/容器数据在 E 盘、Ubuntu Linux 绑定数据按建议路径落在 C 盘；本轮不迁移任何数据。

## 3. 本机资源与目录方案

官方快速开始的最低资源为 2 核 CPU、4 GiB 内存；这是最低启动条件，不能用于承诺本场景的交互体验或多人并发容量。[Dify 快速开始](https://docs.dify.ai/en/self-host/deploy/quick-start/docker-compose)

本机建议以以下预算起步，再根据一次小样本运行的实际内存和磁盘占用判断是否调整。

| 项目 | 工程建议 | 说明 |
| --- | --- | --- |
| 启动前宿主机空闲内存 | 尽量释放到约 8 GiB | 当前约 4.5 GiB，先关闭不需要的高占用应用 |
| WSL 内存预算 | 8 GiB | 工程起点，非官方硬门槛或已生效值 |
| WSL CPU 预算 | 4 vCPU | 保留 Windows 交互余量 |
| WSL swap 预算 | 4 GiB | 缓冲峰值，不替代物理内存 |
| C 盘可用空间观察线 | 建议保持至少 20 GiB | 非官方门槛；先用小语料，关注实际增长 |

如后续需要配置 `.wslconfig`，应先重新读取现状并确认影响范围。该文件对 WSL2 全局生效，会影响其他发行版；不能为本项目直接覆盖用户已有设置。[Microsoft WSL 配置](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)

不建议同时在本机额外运行 14B/32B 本地模型：15.4 GiB 总内存还需承载 Windows、Docker 和 Dify 多服务。先使用云 API，将本轮实验资源集中于文档、检索和流程编排。

| 路径 | 计划用途 | 本轮状态 |
| --- | --- | --- |
| Ubuntu：`~/dify-salong/runtime/dify` | 固定版本 Dify 源码、Compose 及 Linux 绑定数据 | 未创建 |
| `E:\Dify_salong` | 可审阅脚本、脱敏配置样例、文档、DSL 与实验成果 | 已有仓库，不作为运行数据目录 |
| Docker 镜像与容器内部数据 | 已确认位于 E 盘 `disk\docker_data.vhdx` | 保持现状，未迁移 |

优先将源码和 Linux 绑定数据置于 Ubuntu Linux 文件系统，符合官方针对 Windows/WSL2 的路径建议。[Dify 快速开始](https://docs.dify.ai/en/self-host/deploy/quick-start/docker-compose)

由于当前 Ubuntu 注册在 C 盘，该 Linux 路径仍受 C 盘空间约束。如希望运行数据也存放 E 盘，应单独规划迁移或新运行环境，不能在本轮顺带迁移现有 WSL 发行版。

## 4. 固定版本与配置原则

采用 Dify 1.18.0 官方 Compose，保留该版本所需核心服务、依赖服务和初始化任务；不按旧方案的简化容器清单删除组件。官方快速开始描述 7 个核心服务、8 个依赖服务及一次性任务，`init_permissions` 正常完成后退出不等于服务故障。[Dify 快速开始](https://docs.dify.ai/en/self-host/deploy/quick-start/docker-compose)

1.18.0 的 API/worker 等存在 agent_backend 依赖，不能因为本次主要做 RAG 就随意裁剪。暂不使用 Agent KnowledgeFS 等可选特性，也不代表可删除依赖组件。[1.18.0 Compose](https://github.com/langgenius/dify/blob/1.18.0/docker/docker-compose.yaml)

| 配置项 | 方案处理 |
| --- | --- |
| Dify tag / commit | 固定 `1.18.0`，实施时记录完整 commit |
| 镜像版本 | 保存实际镜像清单及 digest，含使用浮动 tag 的组件 |
| 浮动依赖 | 特别记录 `ubuntu/squid:latest` 等浮动镜像的实际拉取 digest |
| 数据库 / 向量库 | 使用官方 PostgreSQL 与 Weaviate 配置路径 |
| `VECTOR_STORE` | 计划采用 `weaviate`；该项存在于该版本模板 |
| `INDEXING_MAX_SEGMENTATION_TOKENS_LENGTH` | 计划沿用原方案 `4000`，该项存在于该版本模板 |
| `UPLOAD_FILE_SIZE_LIMIT` | 原方案建议 `50`；1.18.0 可选共享环境模板第 58 行提供该项，默认 `15`；实施时设置并核对根 `.env` 优先关系 |
| `DIFY_AGENT_LOCAL_SANDBOX_AUTH_TOKEN` | 启动所需非空认证值，实施时安全生成和保存，真实值不入库 |

配置名称与生效位置以固定版本文件为准，不能仅把旧方案参数追加到配置就视为已生效。上传限制可通过该版本可选共享环境模板设置为 `50`，但根 `.env` 具有优先关系，实际生效需部署后验证。[根环境模板](https://github.com/langgenius/dify/blob/1.18.0/docker/.env.example)、[共享环境模板](https://github.com/langgenius/dify/blob/1.18.0/docker/envs/core-services/shared.env.example)

2026-10-31 补充：1.18.0 的 tag 对应 commit `50abea97062110044f15d0e03ccecadd9ccc87ca`。api/worker 的 `env_file` 列表最后加载根 `.env`，因此 `UPLOAD_FILE_SIZE_LIMIT=50` 直接写入根 `.env` 即可覆盖共享模板默认值。另需在根 `.env` 设置 `WEAVIATE_ENABLE_TOKENIZER_GSE=true` 与 `WEAVIATE_TOKENIZATION=gse`：默认 `word` 分词会把“高温合金GH4169”切成一个整词，使全文检索无法命中代号；分词方式在知识库首次创建时固定，必须在创建任何知识库前生效。具体配置与生成脚本见 [deploy/](../deploy/README.md)，已完成静态解析校验，尚未在本机部署验证。

### 4.1 模型选型（2026-10-31 确认）

模型统一由课题组模型平台提供：OpenAI 兼容接口，公网地址可直接访问，本项目不考虑调用频率与额度限制。Dify 中通过“OpenAI-API-compatible”供应商插件接入，Base URL 与 Key 只保存在 Dify 和本地环境中，不入库。

| 角色 | 模型 | 用途与理由 |
| --- | --- | --- |
| LLM（系统默认） | `deepseek-flash` | 问题分类、术语改写和默认答案生成；价格低、吞吐高 |
| LLM（对照） | `deepseek-v4-pro` | 答案生成节点的质量对照；平台页面显示延迟约 17 s，串联后可能影响 35 分钟实操体验，需实测后决定是否用于课程 |
| Embedding | `BAAI/bge-m3` | 中英混合，单段 8192 token，可容纳 600 token 分段；与原方案 `bge-large-zh-v1.5` 不同，需在记录中注明 |
| Rerank | 无 | 平台不提供；见下方调整 |

平台页面上的延迟、吞吐和可用率仅为平台展示值，以 `deploy/check-models.sh` 和 Dify 运行追踪的实测值为准。`intern-s2` 页面可用率约 90%，不纳入实验链路；`deepseek-search`、`deepseek-fetch` 为联网工具，与受控知识库问答无关，不使用。

**无 Rerank 的方案调整：**

- 知识库 B 检索设置改为“混合检索 · 权重模式”（语义权重与关键词权重加权），不配置 Rerank 模型。起始权重沿用 Dify 默认值，必要时以实测召回结果调整并记录。
- 权重模式下的分值是向量相似度与关键词 TF-IDF 的加权和，量纲不同于 Rerank 分值。原方案的 Score 阈值 `0.55` 只作为初始值，需以黄金题的实际召回分值重新校准，工作流兜底话术中的阈值同步更新。
- A/B 对照不再包含 Rerank 因素。为回应[方案分析](plan-review.md)中“多因素同时变化”的问题，可增设知识库 A′：清洗语料 + 自定义分段 + 纯向量检索，分别观察“数据治理”和“检索方式”的贡献。
- 课程材料中的 Rerank 部分只讲原理及在本实验中缺席的影响，不提供 Rerank 实测数据。如后续需要实测，可另行评估本机 CPU 部署重排模型的资源占用，本轮不纳入。

### 4.2 本机入口与端口绑定

计划以 `http://localhost:8080/install` 作为本机初始化入口。所有实际发布的入口应显式绑定 `127.0.0.1`，包括 nginx HTTP/HTTPS 和插件调试端口 5003。

配置时一并核对公开地址中的端口，例如 `TRIGGER_URL=http://localhost:8080`、`NEXT_PUBLIC_SOCKET_URL=ws://localhost:8080`，以及 `ENDPOINT_URL_TEMPLATE` 等回调/公开地址，避免残留默认的 80 端口。内部服务地址继续使用该版本的 Docker 网络配置。[根环境模板](https://github.com/langgenius/dify/blob/1.18.0/docker/.env.example)

官方 Compose 默认的 80/443/5003 发布方式会面向所有接口，单改 HTTP 端口号不能完成本机限制。需要在后续实施中用 Compose override 重置并替换相应 `ports` 列表。[1.18.0 Compose](https://github.com/langgenius/dify/blob/1.18.0/docker/docker-compose.yaml)

普通 `ports` 合并可能保留原映射，需要完全替换而非追加。可采用 `!reset` / `!override` 机制，其中 `!override` 要求 Compose 2.24.4 及以上，本机 2.38.2 满足版本要求；具体写法与合并结果仍须在实施时用 `docker compose config` 静态解析确认。本轮没有生成 override 或验证有效映射。[Compose 合并规则](https://docs.docker.com/reference/compose-file/merge/)

不直接修改上游生成的 `docker-compose.yaml`；将项目差异保存在可审阅 override 与配置样例中，敏感值由本地实际环境提供。

## 5. 后续本机实施步骤

下面是待执行顺序，不是本轮完成记录。每一步采用能直接确认本步骤的最小验证；出现具体失败再定位，不默认扩展为全套测试。

| 顺序 | 待执行动作 | 最小通过依据 | 应保存记录 |
| --- | --- | --- | --- |
| 1 | 释放内存，复核 C/E 盘余量及已确认的数据路径 | 资源满足本次小样本预算，路径归属清楚 | 前后资源快照、实际数据路径 |
| 2 | 启动 Docker Desktop 与所需 Ubuntu 环境 | 目标引擎可连接，能读取服务端版本及可用资源 | client/server 版本、context、引擎资源 |
| 3 | 在计划 Linux 路径准备固定版本源码 | tag 与完整 commit 一致，未混入其他运行环境 | 路径、tag、commit |
| 4 | 依据固定模板生成本地配置和端口 override | 静态解析成功，入口仅发布到 loopback，必需认证值非空 | 脱敏配置、解析后的服务与端口清单 |
| 5 | 拉取所需镜像并启动官方服务拓扑 | 镜像拉取完成，必需服务就绪，一次性初始化正常完成 | 镜像 digest、服务状态、必要失败日志 |
| 6 | 浏览器完成管理员初始化 | 本机 8080 页面可访问，能进入工作区 | 脱敏页面与访问说明 |
| 7 | 接入课题组平台的 LLM 与 Embedding（无 Rerank） | 各角色实际调用成功，记录准确模型与插件版本 | 脱敏模型配置和连通结果 |
| 8 | 导入一份小文档并建立最小 Chatflow | 能检索并基于来源回答；无匹配依据时按配置兜底 | 语料、最小 DSL、输入输出与引用证据 |

模型供应商与具体模型见第 4.1 节；仓库不保存 API Key。不能将宿主机调用成功替代容器内调用成功，容器内以 Dify 添加模型时的凭据校验和实际召回/对话为准。第 8 步的最小知识库需同时验证代号（如 `GH4169`、`HB/Z 20089-A`）能被全文检索命中，以确认 GSE 分词生效。

本机首次验收聚焦一份小文档和一个最小问答流程。阶段二的 8 道黄金题、完整 7 核心节点编排和边界压测仍按后续计划推进，本轮不提前执行。

工作流优先以 Chatflow 作为本机问答验证的实现选择，仍需在固定版本中实际核对输入、上下文、结束回复及引用配置；不照抄旧方案变量就宣称可运行。

### 5.1 停止条件与受阻处理

一次直接相关检查成功后不重复执行；后续修改影响该结果时，才重新检查受影响部分。

若引擎无法启动、镜像层无法拉取、模型鉴权失败或资源不足，保存明确错误及当时状态，暂停依赖步骤。只排查该失败的最小范围，不通过升级全套测试、迁盘或改造无关组件获取“全部通过”。

启动后的最小环境验收完成即可交付阶段零本机结果；不把课程预演、多人容量或生产可用性并入该验收。

## 6. 后续远程共享环境

远程部署待本机完整实验顺利结束、可复现成果整理完成后另行实施，本轮未执行。初步可按 Linux、4 vCPU、16 GiB 内存、100 GB 磁盘规划起点，最终容量取决于参与人数、并发、语料规模、日志保留与模型调用方式。

上述配置是工程预算，不是官方最低要求，也不构成容量承诺。选定服务器后需重新审核资源、磁盘、端口、网络、访问方式和备份边界。

远程首先复用本机验证过的 Dify 版本、模型与插件版本及关键检索参数，减少环境变量；地址、身份、凭据和数据关联在服务器重新配置。

### 6.1 优先采用可复现重建

建议先在服务器新建同版本环境，通过下列成果重建实验内容：

- 导出的 DSL，以及 1.18.0 默认导出包 `.ifpkg`；实际导出文件需记录格式和版本。
- 原始与清洗语料、生成/清洗过程、文件哈希与教学合成标识。
- 分段、检索、Rerank、Top-K、阈值等实际参数。
- 节点提示词、变量绑定、模型与供应商插件清单。
- 小样本文档问答、召回和兜底行为的实际结果。

重建后需替换并核对 dataset、model、plugin 等关联，不能假设导入文件包含原环境的所有知识库和凭据。再进行一次直接相关的小样本复现比较。

### 6.2 如需全状态迁移，单独规划

全状态迁移需要一致性备份 PostgreSQL、Weaviate、上传文件 storage、插件数据及其版本，并保留匹配的加密密钥和配置；`SECRET_KEY` 等实际值不得遗失或入库。

仅复制 DSL 不能称为完整迁移；仅复制某个 `volumes` 目录也不能证明全部状态、数据库一致性和加密依赖已覆盖。全状态方案需另行明确停写窗口、备份范围、恢复顺序与最小恢复验收。

远程多人共享的账号、访问入口与权限在该阶段按实际服务器条件配置，不沿用本机 loopback 地址作为对外方案，也不在本轮开放本机端口。

## 7. 归档与当前未验证项

后续按[复现记录模板](reproduction-template.md)记录环境版本、完整 commit、镜像 digest、模型及插件版本、脱敏配置、语料哈希、DSL、真实输入输出与验证范围。

当前证据可支持“具备基础、需要释放资源并启动引擎后开展单人小语料实验”，尚不能支持部署完成、镜像可拉取、模型可调用、引用可用、拒答有效或多人容量达标。

实施前仍待明确：引擎可见资源、Windows 维护适用范围；模型供应商已于 2026-10-31 确定（第 4.1 节）。部署后再验证端口实际绑定、上传限制与 GSE 分词生效，以及最小问答行为。

原始 [dify.md](../dify.md) 保持原样；该方案对阶段零顺序、版本和路径作出当前建议，后续以真实执行记录更新结论。
