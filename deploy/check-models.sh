#!/usr/bin/env bash
# Dify_salong：课题组模型平台（OpenAI 兼容接口）连通性验证
#
# 用法：
#   export MODEL_BASE_URL="https://<平台域名>/v1"   # 以 /v1 结尾的 OpenAI 兼容地址
#   bash deploy/check-models.sh                      # 未设置 MODEL_API_KEY 时会提示输入（不回显）
#
# 可选覆盖：
#   LLM_MODELS="deepseek-flash deepseek-v4-pro"   要测试的对话模型（空格分隔）
#   EMBEDDING_MODEL="BAAI/bge-m3"                 向量模型
#
# 验证范围：仅证明“运行本脚本的机器”能用该 Key 调通接口。
# Dify 容器内的调用以在 Dify 中添加模型时的凭据校验和实际召回/对话为准。
# 本脚本不打印 API Key，也不保存任何响应到磁盘。

set -euo pipefail

: "${MODEL_BASE_URL:?请先 export MODEL_BASE_URL，例如 https://<平台域名>/v1}"
LLM_MODELS="${LLM_MODELS:-deepseek-flash deepseek-v4-pro}"
EMBEDDING_MODEL="${EMBEDDING_MODEL:-BAAI/bge-m3}"
BASE="${MODEL_BASE_URL%/}"

if [[ -z "${MODEL_API_KEY:-}" ]]; then
  read -r -s -p "请输入模型平台 API Key（不回显）：" MODEL_API_KEY
  echo
fi

for cmd in curl python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "缺少命令：$cmd" >&2; exit 1; }
done

# 发送请求；输出 HTTP 状态码、耗时和响应体到临时文件
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

post_json() {
  local path="$1" body="$2"
  curl -sS -o "$TMP" -w '%{http_code} %{time_total}' \
    --max-time 120 \
    -H "Authorization: Bearer ${MODEL_API_KEY}" \
    -H "Content-Type: application/json" \
    -X POST "${BASE}${path}" -d "$body"
}

fail=0

echo "== 模型平台：${BASE}"

for model in $LLM_MODELS; do
  echo
  echo "== [LLM] ${model}：/chat/completions"
  body=$(python3 -c 'import json,sys; print(json.dumps({"model":sys.argv[1],"messages":[{"role":"user","content":"只回复两个字：连通"}],"max_tokens":16,"temperature":0}))' "$model")
  out=$(post_json "/chat/completions" "$body") || out="000 0"
  read -r code secs <<< "$out"
  if [[ "$code" == "200" ]]; then
    python3 - "$TMP" "$secs" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
msg = d["choices"][0]["message"].get("content", "")
usage = d.get("usage", {})
print(f"   通过  耗时 {float(sys.argv[2]):.2f}s  返回模型 {d.get('model')}  回复 {msg.strip()[:40]!r}  usage {usage}")
PY
  else
    echo "   失败  HTTP ${code}"; head -c 500 "$TMP"; echo; fail=1
  fi
done

echo
echo "== [Embedding] ${EMBEDDING_MODEL}：/embeddings"
body=$(python3 -c 'import json,sys; print(json.dumps({"model":sys.argv[1],"input":["镍基高温合金GH4169（Inconel 718）精铣切削参数","TC4 钛合金粗加工每齿进给量"]}))' "$EMBEDDING_MODEL")
out=$(post_json "/embeddings" "$body") || out="000 0"
read -r code secs <<< "$out"
if [[ "$code" == "200" ]]; then
  python3 - "$TMP" "$secs" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
vecs = [x["embedding"] for x in d["data"]]
print(f"   通过  耗时 {float(sys.argv[2]):.2f}s  条数 {len(vecs)}  维度 {len(vecs[0])}  usage {d.get('usage', {})}")
PY
else
  echo "   失败  HTTP ${code}"; head -c 500 "$TMP"; echo; fail=1
fi

echo
echo "== [Rerank] 平台未提供 Rerank 模型，本项目改用 Dify 混合检索“权重”模式，不测试 /rerank。"

echo
if [[ $fail -eq 0 ]]; then
  echo "结果：全部通过。请把模型 ID、耗时与维度填入复现记录（不要记录 Key）。"
else
  echo "结果：存在失败项，请根据上面的 HTTP 状态与报错排查。" >&2
  exit 1
fi
