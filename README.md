# AI Workstation Container

单容器远程工作站，集成了这些能力：

- `SSH` 远程登录
- `Codex` 与 `Claude Code` CLI
- `Xfce` 桌面
- `VNC` 与 `noVNC`，支持浏览器直接访问桌面
- `proxychains4` 和 `iptables` 出站限制

## 目录

- `Dockerfile`: 镜像定义
- `docker-compose.yml`: 默认启动方式
- `config/`: `sshd`、`supervisor`、`proxychains` 配置
- `scripts/`: 启动、用户初始化、出站限制脚本

## 快速开始

1. 复制环境变量模板：

```bash
cp .env.example .env
```

2. 编辑 `.env`，至少修改这些值：

```env
PASSWORD=your-login-password
SSH_PASSWORD=your-login-password
VNC_PASSWORD=your-vnc-password
SOCKS5_PROXY_HOST=your-proxy-host-or-ip
SOCKS5_PROXY_PORT=1080
SOCKS5_PROXY_USERNAME=your-proxy-username
SOCKS5_PROXY_PASSWORD=your-proxy-password
INTERNAL_DIRECT_CIDRS=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
DISABLE_LOCAL_DNS=1
```

3. 构建并启动：

```bash
docker compose up -d --build
```

4. 连接方式：

```bash
ssh dev@<server-ip> -p 2222
```

浏览器访问：

```text
http://<server-ip>:6080/
```

## 代理策略

容器默认会做两层代理控制：

- shell 环境里注入 `ALL_PROXY=socks5h://...`
- `codex`、`claude`、`git`、`curl`、`wget` 默认通过 `proxychains4`
- 当 `DISABLE_LOCAL_DNS=1` 时，容器本地 resolver 被显式禁用

如果 `ENABLE_IPTABLES=1`，容器还会设置出站白名单：

- 允许访问 `INTERNAL_DIRECT_CIDRS` 里的内网网段
- 允许访问 `SOCKS5_PROXY_HOST:SOCKS5_PROXY_PORT`
- 允许访问容器本地回环
- 允许已建立连接
- 拒绝其他所有出站

这意味着：

- 内网网段可直连
- 外网访问只能经你的 SOCKS5 代理
- 本地 DNS 不放行，因此 `SOCKS5_PROXY_HOST` 应填写固定 IP
- 使用 `socks5h` 或 `proxychains4` 的 `proxy_dns` 做外部域名解析

## 认证与登录

- 默认用户来自 `.env` 的 `USERNAME`
- SSH 使用密码登录
- VNC 使用 `.env` 的 `VNC_PASSWORD`
- 容器里的工作目录是 `/workspace`

## 数据持久化

默认会挂载这些路径：

- `./data/home:/home`
- `./data/workspace:/workspace`
- `./logs:/var/log/ai-workstation`

## 注意事项

- `docker compose` 运行时需要 `NET_ADMIN`，否则无法应用 `iptables`
- 如果宿主机本身拉镜像也要走代理，还需要单独配置 Docker daemon 代理
- 在当前策略下，本地 DNS 不放行，因此 `SOCKS5_PROXY_HOST` 必须使用 IP 地址

## 后续可扩展

- 安装浏览器并固定代理启动参数
- 增加 `code-server`
- 增加 `tailscale` 或 `cloudflared` 作为远程入口
