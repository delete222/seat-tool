#!/bin/sh
# UDP diagnostics: real DNS queries, then one small datagram per VPS port.
set -u
for tool in dig nc timeout; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo '请先在有网时安装：apk add bind-tools netcat-openbsd busybox-extras' >&2
    exit 1
  }
done
work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

dns_test() {
  label=$1
  shift
  printf '\n== UDP 53：%s ==\n' "$label"
  # +ignore prevents a truncated UDP reply from causing a TCP fallback.
  dig +notcp +ignore +time=3 +tries=1 "$@" example.com A > "$work/dns" 2>&1
  if grep -q 'HEADER.*status:' "$work/dns"; then
    echo '[收到 DNS 响应] 该解析器有响应；不表示任意外网 UDP 53 都放通。'
    sed -n '/HEADER/p; /SERVER:/p; /IN[[:space:]]*A[[:space:]]/p' "$work/dns"
  else
    echo '[未收到有效 DNS 响应] 原因无法仅凭此次测试确定。'
    tail -n 4 "$work/dns"
  fi
}
dns_test '系统配置的解析器'
dns_test '223.5.5.5' @223.5.5.5
dns_test '1.1.1.1' @1.1.1.1

printf '\n== VPS UDP 67 / 68：amd.23337788.xyz ==\n'
echo '67/68 是 DHCP 端口。本测试只向 VPS 发小数据报，不发送 DHCP 请求或广播。'
vps_ip=$(dig +notcp +ignore +time=3 +tries=1 +short A amd.23337788.xyz 2>/dev/null | awk '/^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {print; exit}')
if [ -z "$vps_ip" ]; then
  echo '[跳过] 无法解析 VPS IPv4 地址。'
  exit 0
fi
echo "目标 IP：$vps_ip"
for port in 67 68; do
  # UDP nc exit success alone NEVER proves reachability.
  printf 'UDPTEST\n' | timeout 4 nc -u -n -w 2 "$vps_ip" "$port" > "$work/reply" 2> "$work/error"
  if [ -s "$work/reply" ]; then
    bytes=$(wc -c < "$work/reply" | tr -d ' ')
    echo "UDP $port：[收到数据] $bytes 字节；不代表 DHCP 服务有效。"
  else
    echo "UDP $port：[无响应，无法判断] 可能未监听、不响应、或被某处过滤。"
  fi
done
printf '\nUDP 无响应不能证明端口关闭或被 Wi-Fi 拦截。\n要验证 67/68 数据报是否到达 VPS，需要在 VPS 上抓包或运行受控回应服务。\n此测试不验证本地 DHCP，不测试认证绕过。\n'
