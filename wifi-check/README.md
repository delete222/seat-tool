# Wi-Fi 连通性检查（iSH）

在 iPhone 的 iSH（Alpine Linux）中做少量、低频的网络连通性检查，判断 DNS、HTTP/HTTPS 和少数标准 TCP 端口是否可用，并观察 HTTP 是否被重定向到认证门户。

仅用于你有权限测试的网络。本工具不绕过认证，不隧道或伪装流量，不提交账号密码，也不扫描网段。

## 安装依赖

```sh
apk update
apk add curl netcat-openbsd bind-tools iproute2 busybox-extras
```

## 下载并运行

```sh
cd ~
curl -fL https://raw.githubusercontent.com/delete222/seat-tool/main/wifi-check/wifi-check.sh -o wifi-check.sh
chmod +x wifi-check.sh
./wifi-check.sh
```

也可以合并成一条命令：

```sh
curl -fL https://raw.githubusercontent.com/delete222/seat-tool/main/wifi-check/wifi-check.sh -o ~/wifi-check.sh && chmod +x ~/wifi-check.sh && ~/wifi-check.sh
```

## 可选参数

通过环境变量修改超时秒数、DNS 查询域名和 HTTP/HTTPS 测试地址：

```sh
TIMEOUT=5 DNS_NAME=example.org HTTP_URL=http://neverssl.com/ HTTPS_URL=https://example.org/ ./wifi-check.sh
```

## 结果说明

- DNS 查询成功表示当前配置的 DNS 能解析该域名。
- `可连接` 只表示目标 TCP 端口接受连接，不代表应用层服务一定能正常使用。
- HTTP 的 `final=` 若变成陌生登录页域名，或出现重定向状态，可能说明存在认证门户。
- HTTPS 失败、HTTP 被重定向，常见于门户认证前的网络状态；请按 Wi-Fi 提供方的正常流程认证。
