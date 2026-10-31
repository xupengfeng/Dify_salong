#!/usr/bin/env bash
# Dify_salong 本机实验：由 Dify 1.18.0 官方 .env.example 生成本地 .env
#
# 用法（在 WSL Ubuntu 中，于 Dify 源码的 docker/ 目录执行）：
#   bash /path/to/Dify_salong/deploy/prepare-env.sh
#
# 行为：
#   1. 若 .env 已存在则直接退出，不覆盖已有配置；
#   2. 复制 .env.example 为 .env，并写入本项目的差异项（说明见 deploy/README.md）；
#   3. 为启动必需的认证值和 Agent 开发默认密钥生成随机值，只写入 .env，不在终端输出；
#   4. 将 .env 权限设为 600。
# 本脚本不启动任何容器，也不拉取镜像。

set -euo pipefail

ENV_EXAMPLE=".env.example"
ENV_FILE=".env"

if [[ ! -f "$ENV_EXAMPLE" || ! -f "docker-compose.yaml" ]]; then
  echo "错误：请在 Dify 源码的 docker/ 目录下执行（未找到 $ENV_EXAMPLE 或 docker-compose.yaml）。" >&2
  exit 1
fi

if [[ -f "$ENV_FILE" ]]; then
  echo "提示：$ENV_FILE 已存在，未做任何修改。如需重新生成，请先自行备份并移走该文件。" >&2
  exit 1
fi

gen_token() {
  # 生成 URL 安全的随机串；优先 python3，退回 openssl
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import secrets; print(secrets.token_urlsafe(32))'
  else
    openssl rand -base64 32 | tr '+/' '-_' | tr -d '=\n'
  fi
}

# 设置 KEY=VALUE：已有该键则整行替换，没有则追加到文件末尾
set_kv() {
  local key="$1" value="$2"
  if grep -qE "^${key}=" "$ENV_FILE"; then
    # 使用 | 作为分隔符，值中不含 |
    sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
  else
    printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
  fi
}

cp "$ENV_EXAMPLE" "$ENV_FILE"
chmod 600 "$ENV_FILE"

{
  echo
  echo "# ------------------------------------------------------------------"
  echo "# Dify_salong 本机实验差异项（由 deploy/prepare-env.sh 写入）"
  echo "# ------------------------------------------------------------------"
} >> "$ENV_FILE"

# 1) 本机入口：http://localhost:8080（端口仅绑定 127.0.0.1 由 override 文件负责）
set_kv EXPOSE_NGINX_PORT 8080
set_kv TRIGGER_URL "http://localhost:8080"
set_kv ENDPOINT_URL_TEMPLATE "http://localhost:8080/e/{hook_id}"
set_kv NEXT_PUBLIC_SOCKET_URL "ws://localhost:8080"

# 2) 知识库实验参数
set_kv VECTOR_STORE weaviate
set_kv INDEXING_MAX_SEGMENTATION_TOKENS_LENGTH 4000
#    UPLOAD_FILE_SIZE_LIMIT 在 1.18.0 根模板中不存在（共享模板默认 15）；
#    根 .env 在 env_file 列表最后加载，写在这里即可覆盖。
set_kv UPLOAD_FILE_SIZE_LIMIT 50

# 3) 中文全文检索分词：默认 word 分词会把“高温合金GH4169”切成一个整词，
#    导致 BM25 搜不到 GH4169。改用 Weaviate 内置 GSE 中文分词。
#    注意：分词方式在知识库（Weaviate collection）首次创建时固定，
#    必须在创建任何知识库之前生效；之后修改只影响新建知识库。
set_kv WEAVIATE_ENABLE_TOKENIZER_GSE true
set_kv WEAVIATE_TOKENIZATION gse

# 4) 启动必需的非空认证值，以及替换 Agent 相关开发默认密钥
set_kv DIFY_AGENT_LOCAL_SANDBOX_AUTH_TOKEN "$(gen_token)"
set_kv DIFY_AGENT_API_TOKEN "$(gen_token)"
set_kv DIFY_AGENT_SERVER_SECRET_KEY "$(gen_token)"

echo "已生成 $ENV_FILE（权限 600）。已写入的差异项："
grep -nE '^(EXPOSE_NGINX_PORT|TRIGGER_URL|ENDPOINT_URL_TEMPLATE|NEXT_PUBLIC_SOCKET_URL|VECTOR_STORE|INDEXING_MAX_SEGMENTATION_TOKENS_LENGTH|UPLOAD_FILE_SIZE_LIMIT|WEAVIATE_ENABLE_TOKENIZER_GSE|WEAVIATE_TOKENIZATION)=' "$ENV_FILE"
echo "随机认证值已写入但未显示：DIFY_AGENT_LOCAL_SANDBOX_AUTH_TOKEN、DIFY_AGENT_API_TOKEN、DIFY_AGENT_SERVER_SECRET_KEY"
echo "下一步：复制 docker-compose.override.yaml 到当前目录，执行 docker compose config 静态校验。"
