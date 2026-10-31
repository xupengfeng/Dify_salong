# 阶段零：2026-10-31 本机部署执行记录

状态：**本机基础部署及管理员初始化完成；模型配置与最小验收待完成**。日期与时区：2026-10-31，Asia/Singapore。

依据[本机部署步骤](../../deploy/README.md)执行。本记录仅归档非敏感事实，不保存实际 `.env`、认证值、API Key、个人账号信息或全量 Compose 配置。基础服务运行不等于模型、检索和工作流已验收。

## 版本与运行位置

| 项目 | 实际记录 |
| --- | --- |
| 起始仓库状态 | `main`，commit `1ead6a3`；开始时工作区干净 |
| 仓库路径 | `E:\Dify_salong` |
| Dify 版本 / commit | `1.18.0` / `50abea97062110044f15d0e03ccecadd9ccc87ca`，源码已核实 |
| Ubuntu 用户 / 运行目录 | `root` / `/root/dify-salong/runtime/dify/docker` |
| Docker / Compose | Linux Engine `28.3.2` / 本机 Compose `2.38.2` |
| 引擎资源 | 16 CPU，`7984054272` MemoryBytes，约 7.44 GiB；Root Dir `/var/lib/docker` |
| 运行配置 | 已运行 `prepare-env.sh` 并合并项目 override；实际 `.env` 权限 `600`，随机密钥仅保存在运行目录 |
| 镜像清单 | 所需 12 个镜像齐备；tag、digest 等见[完整本机镜像清单](2026-10-31-local-images.json) |
| 本机入口 | `http://localhost:8080` |

启动前宿主机空闲内存约 4.4 GiB，C 盘可用约 47.6 GiB、E 盘约 386.6 GiB；Ubuntu 当时可用内存约 6.6 GiB、swap 2 GiB。Linux `df` 的约 236 GiB 虚拟可用空间不替代宿主机物理余量，Ubuntu 绑定数据路径仍受 C 盘空间约束。

## 实际基础验收结果

| 项目 | 结果与证据 |
| --- | --- |
| Compose 静态解析 | 官方配置与项目 override 在本机解析通过，选中 16 个服务 |
| 长期服务 | 完整 stack 已启动，15 个长期服务 Running |
| 初始化任务 | `init_permissions` 为 Exited `0`，属于正常完成 |
| Docker healthcheck | API、PostgreSQL、Redis、sandbox、local_sandbox 为 healthy；其余长期服务仅记录 Running，不声称具备 healthcheck |
| Weaviate HTTP ready | 容器内 `wget --spider http://127.0.0.1:8080/v1/.well-known/ready` 退出 `0`；其配置无 Docker healthcheck |
| Windows 实际监听 | 仅 `127.0.0.1:8080`、`127.0.0.1:5003`，未发布额外入口 |
| `GET /install` | HTTP `200`，响应 47072 bytes |
| `GET /console/api/ping` | 返回 `result: pong` |
| `GET /console/api/setup` | 管理员初始化前为 `not_started`；该值是当时状态 |
| 管理员初始化与登录 | 用户亲自完成；后续在真实浏览器模型供应商页确认已登录，不归档个人账号信息 |
| API 实际环境 | `UPLOAD_FILE_SIZE_LIMIT=50`、`WEAVIATE_TOKENIZATION=gse` |
| Weaviate 实际环境 | `ENABLE_TOKENIZER_GSE=true`；真实分词与全文召回仍未验证 |

完整 stack 启动时，带 `--wait` 的等待命令曾因默认禁用的 worker healthcheck 报 `container docker-worker-1 has no healthcheck configured` 并退出 `1`；实际 worker 为 Running。未修改 healthcheck 配置，未为此重复 `up`，而是完成容器状态、实际 HTTP 和浏览器登录验收。

已有镜像和配置后，在上述运行目录使用 `docker compose up -d --pull never` 启动，避免重新拉取并命中预置镜像加速器。该命令是后续启动方式，不替代本表的实际验收证据。

## 镜像下载受阻与恢复概要

初次默认并发 pull 推进缓慢，日志出现共享 layer 内容锁等待，未据此认定网络失败或死锁。仅中断本任务持有的 pull 进程并保留缓存，随后改为顺序拉取。

顺序 pull 出现 `httpReadSeeker unexpectedstatus GET`；原始 HTTP 状态未保留，其他日志中的 403 无法归因该请求。API 镜像仅重试一次后仍报 `failed to copy: invalid input: magic number mismatch`。

尝试过 Google 官方 crane `v0.22.1` 便携工具，来源为[官方发布](https://github.com/google/go-containerregistry/releases/tag/v0.22.1)，仅放在项目 `.local/tools/`。工具包 SHA-256 已核对发布元数据；官方与 DaoCloud 两路 legacy 归档均以 `unexpected EOF` 失败，均未导入 Docker。crane 不是最终部署必需工具，API 最终成功路径为下面的 Docker 拉取。

用户确认“已切换，继续部署”后，以显式官方 registry 引用绕开本机预置 registry-mirrors：

```bash
docker pull --platform linux/amd64 registry-1.docker.io/langgenius/dify-api@sha256:0a7409b80eb9d587ff99d8ed3e791c915a82f75345c09fef7271860c0ddafc2e
```

该拉取完整完成并退出 `0`，随后标记为 `langgenius/dify-api:1.18.0`。已核对 descriptor、RepoDigests 和 Linux/amd64 平台。

| API 镜像元数据 | 已核实值 |
| --- | --- |
| Manifest / descriptor digest | `sha256:0a7409b80eb9d587ff99d8ed3e791c915a82f75345c09fef7271860c0ddafc2e` |
| Config digest | `sha256:1bd3e079fd83a9721b1c387d4d13ae28da5642669be3c5700e980d4e3a3156cc` |
| 本机 containerd image store 的 Docker image ID | 与上面的 manifest digest 相同，不要求等于 config digest |
| 压缩层 | 15 层均为 gzip，不能将此前错误归因为该镜像使用 zstd 层 |

最后 3 类依赖也按原版本 tag 使用显式 `registry-1.docker.io` 拉取，均成功并标记回 Compose 所需名称。新代理节点初次认证出现 EOF，之后仅一次宿主机匿名认证端点探测返回 HTTP `200` 且 token 结构有效；未保存或打印 token。

全过程未修改 Docker/Windows 全局代理或已有 3 个 registry-mirrors，未重启或清理 Docker；使用已有 `7892` 代理的恢复操作只作用于相应工具进程或逐镜像官方引用。

## 模型配置的当前边界

平台 Base URL 为 `https://t.segsage.cn:8443/v1`。宿主机不带认证 `GET /models` 返回 HTTP `401`，仅证明 HTTPS 到达且接口要求认证，不是模型调用成功。API Key 由用户亲自输入，未读取或记录；`deepseek-flash` 已保存并在界面启用，真实生成问答尚未验证。

在已登录的模型供应商页，Dify 认证插件 `langgenius/openai_api_compatible` `0.0.73` 已安装成功，界面显示“1 个集成安装成功”及 `0.0.73` 版本卡。用户输入 Key 并保存后，界面显示 `DeepSeek Flash（课题组平台） LLM CHAT 4K`，启用开关为开启；4K 是当前 Dify 配置，不代表已核实平台的上下文上限。随后用户要求剩余配置改由手动完成，已停止界面操作，Embedding、可选对照 LLM、默认模型及最小验收交由用户继续。

| 角色 | 计划模型 | 当前结果 |
| --- | --- | --- |
| LLM：分类、改写及默认生成 | `deepseek-flash` | 已保存并启用；真实生成问答待手动验收 |
| LLM：生成对照 | `deepseek-v4-pro` | 待凭据配置与真实调用 |
| Embedding | `BAAI/bge-m3` | 待凭据配置与真实调用 |
| Rerank | 本轮不配置 | 平台无该类模型，知识库计划采用混合检索权重模式 |

## 尚未完成的最小验收

| 用例 / 成果 | 预期与当前状态 |
| --- | --- |
| 全文检索 `GH4169` | 对含“镍基高温合金GH4169”的短文本命中对应片段；未执行 |
| 全文检索 `HB/Z 20089-A` | 命中包含该代号的片段；未执行 |
| 混合检索权重模式有依据问答 | 最小 Chatflow 基于测试文本回答并定位引用；未执行 |
| 无依据问题 | 按配置进入兜底，不补造参数；未执行 |
| 语料、知识库参数及 DSL | 尚未生成/创建/导出，待实际验收后归档 |

混合检索含向量召回，单凭其命中不能证明 GSE 或全文检索生效。后续最小测试文本仅用于部署验收，不构成受控工业依据。

当前证据支持本机基础服务运行、入口可用及管理员初始化完成；阶段零的模型接入与最小问答验收仍待完成，尚无 A/B 调优、完整工作流、多人容量或远程共享环境的运行结论。
