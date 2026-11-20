#!/bin/sh
# Single-target TCP connect scan for an authorized test. Compatible with iSH.
set -eu
if ! command -v nmap >/dev/null 2>&1; then
  echo '请先在有网时执行：apk update && apk add nmap' >&2
  exit 1
fi
target=${1:-}
if [ -z "$target" ]; then
  printf '请输入获准测试的单个 IPv4 地址：'
  read -r target
fi
# Accept exactly one IPv4 literal, never a subnet, range or option.
if ! printf '%s\n' "$target" | awk -F. 'NF!=4 {exit 1} {for(i=1;i<=4;i++) if($i !~ /^[0-9]+$/ || length($i)>3 || $i+0>255) exit 1}'; then
  echo '请输入单个 IPv4 地址，例如 192.168.1.1。' >&2
  exit 1
fi
outdir="$HOME/wifi-scan-results"
mkdir -p "$outdir"
prefix="$outdir/${target}-$(date +%Y%m%d-%H%M%S)-$$"
printf '目标：%s\n范围：TCP 1–65535\n最高发送速率：30 次探测/秒（实际可能更慢）\n结果：%s.nmap\n按 Ctrl+C 可中止。\n' "$target" "$prefix"
echo '完整扫描可能需要几十分钟至数小时，请保持 iSH 在前台。'
nmap -sT -Pn -n -p 1-65535 --max-rate 30 --max-parallelism 8 --max-retries 1 --stats-every 30s -oA "$prefix" "$target"
printf '\n完成。文本报告：%s.nmap\n' "$prefix"
echo 'open 表示目标接受 TCP 连接；closed 表示连接被拒绝；filtered 表示未收到足够响应，原因不能仅凭扫描确定。'
echo '此扫描不会判断 UDP、服务是否可用或认证能否绕过；网关扫描不能代表对外放行端口。'
