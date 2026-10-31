# 阶段零：本机部署配置与操作步骤

本目录存放本机实验所需的可审阅配置与脚本，均不含真实密钥。2026-10-31 已完成本机基础部署，15 个长期服务 Running，管理员已初始化并登录；模型配置、真实调用及最小检索/Chatflow 验收仍待完成。实际版本、服务和 HTTP 证据见[本机部署执行记录](../docs/runs/2026-10-31-local-deployment.md)，后续成果按[复现记录模板](../docs/reproduction-template.md)记录。

下文保留首次部署步骤及文末云端静态校验历史。当前本机已有完整镜像和运行配置，后续启动使用本页“已有本机环境”说明，不重新生成现有 `.env`。

| 文件 | 用途 |
| --- | --- |
| `prepare-env.sh` | 由 1.18.0 官方 `.env.example` 生成本地 `.env`，写入本项目差异项并生成随机认证值 |
| `docker-compose.override.yaml` | 将 nginx、插件调试端口完全替换为仅绑定 `127.0.0.1` |
| `check-models.sh` | 用 curl 验证课题组模型平台的 LLM 与 Embedding 接口 |

## 固定版本

| 项目 | 值 |
| --- | --- |
| Dify | `1.18.0`，commit `50abea97062110044f15d0e03ccecadd9ccc87ca` |
| 主要镜像 tag | `langgenius/dify-api:1.18.0`、`dify-web:1.18.0`、`dify-agent-backend:1.18.0`、`dify-plugin-daemon:0.6.10-local`、`weaviate:1.39.13` |
| 浮动 tag（需记录 digest） | `nginx:latest`、`ubuntu/squid:latest` 等，以实际 `docker compose images` 为准 |

## 本项目 `.env` 差异项

| 配置项 | 值 | 原因 |
| --- | --- | --- |
| `EXPOSE_NGINX_PORT` | `8080` | 本机入口 `http://localhost:8080` |
| `TRIGGER_URL` / `ENDPOINT_URL_TEMPLATE` / `NEXT_PUBLIC_SOCKET_URL` | 带 `:8080` 的 localhost 地址 | 避免公开地址残留默认 80 端口 |
| `VECTOR_STORE` | `weaviate` | 与模板默认一致，显式记录 |
| `INDEXING_MAX_SEGMENTATION_TOKENS_LENGTH` | `4000` | 与模板默认一致，显式记录 |
| `UPLOAD_FILE_SIZE_LIMIT` | `50` | 根模板无此项，共享模板默认 15；根 `.env` 最后加载，可覆盖 |
| `WEAVIATE_ENABLE_TOKENIZER_GSE` / `WEAVIATE_TOKENIZATION` | `true` / `gse` | 见下方“中文分词” |
| `DIFY_AGENT_LOCAL_SANDBOX_AUTH_TOKEN` | 随机生成 | 启动必需的非空认证值 |
| `DIFY_AGENT_API_TOKEN` / `DIFY_AGENT_SERVER_SECRET_KEY` | 随机生成 | 替换模板中的开发默认值 |

数据库、Redis、插件守护进程等内部密码保留模板默认值：它们只在 Docker 内部网络使用，本机不对外发布。远程共享环境需全部重新生成。`SECRET_KEY` 保持留空，由 Dify 自动生成并持久化在 storage 目录；该目录丢失会导致已保存的模型凭据无法解密。

### 中文分词（必须在创建知识库前生效）

1.18.0 默认 `WEAVIATE_TOKENIZATION=word`：按非字母数字字符切分，中文字符也算“字母”，所以“镍基高温合金GH4169”会成为一个整词，全文检索搜 `GH4169` 时无法命中。这会直接破坏阶段二要演示的“代号精确匹配”。

本方案改用 Weaviate 内置的 GSE 中文分词。分词方式在每个知识库（Weaviate collection）首次创建时固定，事后修改 `.env` 只影响新建知识库。部署后先用第 8 步的最小知识库验证；若 GSE 不可用，退路是改回 `word`，并在清洗语料中让代号与中文之间保留空格或标点（可作为 BA 数据治理的一个教学点）。

## 操作步骤（WSL Ubuntu-22.04）

以下命令假定本仓库在 Windows 的 `E:\Dify_salong`，在 WSL 中即 `/mnt/e/Dify_salong`。

1. **准备资源与引擎**：关闭高占用应用，使空闲内存尽量接近 8 GiB；启动 Docker Desktop，并在“Settings → Resources → WSL integration”中启用 Ubuntu-22.04。在 Ubuntu 中确认：

   ```bash
   docker version && docker compose version && docker info --format '{{.NCPU}} CPU / {{.MemTotal}} bytes'
   ```

2. **拉取固定版本源码**（放在 Linux 文件系统内）：

   ```bash
   mkdir -p ~/dify-salong/runtime && cd ~/dify-salong/runtime
   git clone --depth 1 --branch 1.18.0 https://github.com/langgenius/dify.git dify
   git -C dify rev-parse HEAD   # 应为 50abea97062110044f15d0e03ccecadd9ccc87ca
   cd dify/docker
   ```

3. **生成 `.env` 并放置端口 override**：

   ```bash
   bash /mnt/e/Dify_salong/deploy/prepare-env.sh
   cp /mnt/e/Dify_salong/deploy/docker-compose.override.yaml .
   ```

4. **静态校验发布端口**（应只看到 `nginx 127.0.0.1:8080->80` 与 `plugin_daemon 127.0.0.1:5003->5003`）：

   ```bash
   docker compose config --format json | python3 -c 'import json,sys; d=json.load(sys.stdin); [print(n, "%s:%s->%s" % (p.get("host_ip","0.0.0.0"), p.get("published"), p.get("target"))) for n,s in d["services"].items() for p in s.get("ports",[])]'
   ```

5. **拉取镜像并启动**，记录实际镜像与 digest：

   ```bash
   docker compose pull
   docker compose up -d
   docker compose ps
   docker compose images
   docker image inspect --format '{{index .RepoTags 0}} {{index .RepoDigests 0}}' $(docker compose images -q) 2>/dev/null
   ```

   `init_permissions` 正常完成后退出属于预期。若服务未就绪，只查看相关服务日志，例如 `docker compose logs --tail 100 api`。

6. **核对配置实际生效**：

   ```bash
   docker compose exec api sh -c 'echo UPLOAD=$UPLOAD_FILE_SIZE_LIMIT TOKENIZATION=$WEAVIATE_TOKENIZATION'
   docker compose exec weaviate sh -c 'echo GSE=$ENABLE_TOKENIZER_GSE'
   ```

7. **初始化管理员并接入模型**：
   - 浏览器打开 `http://localhost:8080/install` 创建管理员。
   - 先在 WSL 中验证模型平台：

     ```bash
     export MODEL_BASE_URL="https://<平台域名>/v1"
     bash /mnt/e/Dify_salong/deploy/check-models.sh
     ```

   - Dify“设置 → 模型供应商”中安装 **OpenAI-API-compatible** 插件，API endpoint URL 填同一 `MODEL_BASE_URL`，分别添加：

     | 模型类型 | 模型名称 | 说明 |
     | --- | --- | --- |
     | LLM | `deepseek-flash` | 分类、改写、默认生成；上下文长度按平台说明填写 |
     | LLM | `deepseek-v4-pro` | 生成节点对照用 |
     | Text Embedding | `BAAI/bge-m3` | 上下文长度 8192 |

   - “系统模型设置”：系统推理模型 `deepseek-flash`，Embedding `BAAI/bge-m3`，Rerank 留空。
   - 记录插件版本号；Key 只保存在 Dify 中，不写入仓库。

8. **最小验收**：新建一个小知识库（高质量索引、`BAAI/bge-m3`），检索方式先选“全文检索”，导入一段含“镍基高温合金GH4169”与“HB/Z 20089-A”的短文本。在“召回测试”中分别检索 `GH4169` 和 `HB/Z 20089-A`，确认全文检索命中对应片段并保存结果。随后切换为“混合检索 · 权重模式”，再建一个最小 Chatflow 完成一次有依据的回答和一次无依据时的兜底回复。混合检索也会使用向量召回，其命中结果不能单独证明全文检索或 GSE 分词生效。

## 已有本机环境

当前运行目录为 Ubuntu 的 `/root/dify-salong/runtime/dify/docker`。已有完整镜像后，在该目录使用 `docker compose up -d --pull never` 启动，避免再次拉取并命中本机已有加速器。镜像下载错误与逐镜像显式官方引用的恢复经过见[实际运行记录](../docs/runs/2026-10-31-local-deployment.md)，没有修改全局代理或镜像源。

部分服务没有 Docker healthcheck，不能将整个 stack 的 `--wait` 结果直接当成应用可用性结论；本次另以容器状态、实际 HTTP 与浏览器登录确认基础服务。模型和 GSE 真实召回仍需按第 7–8 步验证。

## 停止与清理

- 停止：`docker compose down`（保留数据卷，可再次 `up -d`）。
- 不要随意执行 `docker compose down -v` 或删除 `volumes/`：会清空数据库、向量库、上传文件和自动生成的 `SECRET_KEY`。

## 静态校验记录（2026-10-31，云端环境，非本机）

- 使用 Dify 1.18.0 官方 `docker/` 目录，执行 `prepare-env.sh` 并合并 override 后，`docker compose config`（Compose v5.6.1）解析成功；发布端口仅为 `127.0.0.1:8080->80`（nginx）与 `127.0.0.1:5003->5003`（plugin_daemon）。
- `bash -n` 检查两个脚本语法通过；`check-models.sh` 尚未连接真实平台运行。
- 以上为当时的云端静态证据；本机实际执行另见运行记录。真实模型调用和 GSE 分词召回尚未验证。
