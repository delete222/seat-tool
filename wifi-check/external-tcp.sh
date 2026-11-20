#!/bin/sh
# Compare TCP reachability to the user's VPS across network conditions.
set -eu
host=amd.23337788.xyz
label=${1:-wifi}
case "$label" in baseline|wifi) ;; *) echo '用法：sh external-tcp.sh [baseline|wifi]' >&2; exit 1;; esac
for tool in nmap awk; do
  command -v "$tool" >/dev/null 2>&1 || { echo '请在有网时安装：apk update && apk add nmap curl bind-tools' >&2; exit 1; }
done
outdir="$HOME/wifi-scan-results"
mkdir -p "$outdir"
# Pin a single IPv4 destination from the baseline so DNS changes do not
# accidentally turn the comparison into a test of different servers.
ipfile="$outdir/amd-target-ip.txt"
if [ -s "$ipfile" ]; then
  target=$(cat "$ipfile")
else
  command -v dig >/dev/null 2>&1 || { echo '首次运行需要 bind-tools：apk add bind-tools' >&2; exit 1; }
  target=$(dig +time=3 +tries=1 +short A "$host" | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {print; exit}')
fi
if ! printf '%s\n' "$target" | awk -F. 'NF!=4 {exit 1} {for(i=1;i<=4;i++) if($i !~ /^[0-9]+$/ || length($i)>3 || $i+0>255) exit 1}'; then
  echo '无法获得目标 IPv4；请在有网时先运行 baseline。' >&2; exit 1
fi
printf '%s\n' "$target" > "$ipfile"
prefix="$outdir/${label}-$(date +%Y%m%d-%H%M%S)-$$"
printf '目标：%s (%s)\n记录标签：%s\n扫描 TCP 1–65535，最高 30 次探测/秒，最多 8 个并发连接。\n' "$host" "$target" "$label"
echo '可能需要几十分钟至数小时；保持 iSH 前台，Ctrl+C 可停止。'
echo '只记录 TCP 连接情况；服务器未监听、服务器防火墙及网络策略均可导致连接失败。'
nmap -sT -Pn -n -p 1-65535 --max-rate 30 --max-parallelism 8 --max-retries 1 --stats-every 30s -oA "$prefix" "$target"
printf '\n报告：%s.nmap\n' "$prefix"
echo 'open = TCP 连接成功，不等于应用协议能正常使用。'
echo '比较 baseline 与 wifi 中同一 IP 的 open 端口；服务器配置应保持一致。'
echo '此脚本不测试 UDP，也不修改服务器监听或防火墙。'
