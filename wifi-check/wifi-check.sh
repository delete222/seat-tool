#!/bin/sh
# Low-impact connectivity checks for Wi-Fi networks you are authorized to test.
# No captive-portal bypass, authentication, tunneling, or subnet scanning.

set -u

TIMEOUT="${TIMEOUT:-3}"
DNS_NAME="${DNS_NAME:-example.com}"
HTTP_URL="${HTTP_URL:-http://neverssl.com/}"
HTTPS_URL="${HTTPS_URL:-https://example.com/}"

command -v timeout >/dev/null 2>&1 || { echo "缺少 timeout。请在 iSH 执行: apk add busybox-extras" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }
line() { printf '\n== %s ==\n' "$1"; }

check_tcp() {
  host="$1" port="$2" label="$3"
  if ! have nc; then printf '[跳过] %s：缺少 nc（apk add netcat-openbsd）\n' "$label"; return; fi
  if timeout "$TIMEOUT" nc -z -w "$TIMEOUT" "$host" "$port" >/dev/null 2>&1; then
    printf '[可连接] %s (%s:%s)\n' "$label" "$host" "$port"
  else
    printf '[不可连接/超时] %s (%s:%s)\n' "$label" "$host" "$port"
  fi
}

line '本机与默认路由'
if have ip; then
  ip addr 2>/dev/null | sed -n '/inet /p' || true
  ip route 2>/dev/null | sed -n '1,4p' || true
else
  echo '[提示] 未找到 ip 命令（iSH 可能不暴露 iOS 网络接口信息）'
fi

line 'DNS 查询'
if have nslookup; then
  timeout "$TIMEOUT" nslookup "$DNS_NAME" 2>&1 | sed -n '1,12p'
elif have drill; then
  timeout "$TIMEOUT" drill "$DNS_NAME" 2>&1 | sed -n '1,12p'
else
  echo '[跳过] 请安装 bind-tools：apk add bind-tools'
fi

line 'DNS 端口 53 可达性（TCP）'
# Connection checks only; no tunneling or traffic disguise.
check_tcp 1.1.1.1 53 'Cloudflare TCP DNS'
check_tcp 8.8.8.8 53 'Google TCP DNS'

line 'HTTP / HTTPS 与门户提示'
if have curl; then
  for url in "$HTTP_URL" "$HTTPS_URL"; do
    echo "目标: $url"
    timeout "$((TIMEOUT + 2))" curl -sS -L --max-redirs 3 --connect-timeout "$TIMEOUT" --max-time "$((TIMEOUT + 2))" \
      -o /dev/null -w 'HTTP=%{http_code} final=%{url_effective} remote=%{remote_ip}\n' "$url" 2>&1 || true
  done
else
  echo '[跳过] 请安装 curl：apk add curl'
fi

line '少量常见 TCP 端口'
# Fixed, small set of public service endpoints; no ranges or retries.
check_tcp example.com 22 'SSH'
check_tcp example.com 80 'HTTP'
check_tcp example.com 443 'HTTPS'
check_tcp example.com 8080 'HTTP alternate'
check_tcp example.com 8443 'HTTPS alternate'
check_tcp 1.1.1.1 53 'DNS TCP'
check_tcp 1.1.1.1 853 'DNS-over-TLS'

cat <<'NOTICE'

说明：
- “可连接”只表示 TCP 握手成功，不代表该服务可正常使用；“不可连接/超时”也可能是测试目标未监听该端口。
- 这些结果无法识别认证网关的厂商，也无法证明认证前可用哪些获准服务。
- HTTP 跳转到陌生登录页、HTTP 状态为 30x，或 HTTPS 出现证书/连接错误，可能表示门户认证或网络策略；请使用网络提供方的正常认证流程。
- 仅在获准测试的 Wi-Fi 上运行。脚本不会枚举局域网设备、发送认证凭据或尝试绕过认证。
NOTICE
