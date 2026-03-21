# AI Workstation Container

单容器远程工作站，集成了这些能力：

- `SSH` 远程登录
- `Codex` 与 `Claude Code` CLI
- `Xfce` 桌面
- `VNC` 与 `noVNC`，支持浏览器直接访问桌面
- `Chromium` 浏览器，默认走本地 `Privoxy -> SOCKS5`
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
HOME_HOST_DIR=./data/home
WORKSPACE_HOST_DIR=./data/workspace
LOGS_HOST_DIR=./logs
SOCKS5_PROXY_HOST=your-proxy-host-or-ip
SOCKS5_PROXY_PORT=1080
SOCKS5_PROXY_USERNAME=your-proxy-username
SOCKS5_PROXY_PASSWORD=your-proxy-password
INTERNAL_DIRECT_CIDRS=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
DISABLE_LOCAL_DNS=1
BROWSER_HTTP_PROXY_PORT=8118
SSH_PORT=2222
WEB_VNC_PORT=6080
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

这套模式适合在源码目录里开发和重建镜像。执行后会在本机生成 `ai-workstation:local` 镜像，后面的极简实例目录会直接复用它。

## 代理策略

容器默认会做两层代理控制：

- shell 环境里注入 `ALL_PROXY=socks5h://...`
- `codex`、`claude`、`git`、`curl`、`wget` 默认通过 `proxychains4`
- `Chromium` 通过本地 `Privoxy` HTTP 代理转发到上游认证 `SOCKS5`
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
- 浏览器通过本地 `127.0.0.1:${BROWSER_HTTP_PROXY_PORT}`，避免 Chromium 直接处理 SOCKS5 认证

## 认证与登录

- 默认用户来自 `.env` 的 `USERNAME`
- SSH 使用密码登录
- VNC 使用 `.env` 的 `VNC_PASSWORD`
- 容器里的工作目录是 `/workspace`
- 桌面有 `Chromium (Proxy)` 启动器，shell 里可执行 `browser`

## 数据持久化

默认会把这些宿主机目录映射进容器：

- `./data/home:/home`
- `./data/workspace:/workspace`
- `./logs:/var/log/ai-workstation`

如果你不想把数据放在项目目录里，直接在 `.env` 里改这三个变量即可：

- `HOME_HOST_DIR`
- `WORKSPACE_HOST_DIR`
- `LOGS_HOST_DIR`

浏览器 profile、shell 历史、SSH known_hosts、桌面配置和工作目录都会保存在这些外部目录里，不会随着容器重建而丢失。

## 复制新实例

如果你想为另一个代理或另一套配置再起一个容器，不需要复制整个源码仓库。先在源码目录里至少构建过一次本地镜像：

```bash
cd /path/to/ai-workstation
docker compose up -d --build
```

然后从仓库里的 `deploy-template/` 拿两份文件到新目录即可：

```bash
mkdir -p /path/to/ai-workstation-bob
cp /path/to/ai-workstation/deploy-template/docker-compose.yml /path/to/ai-workstation-bob/
cp /path/to/ai-workstation/deploy-template/.env.example /path/to/ai-workstation-bob/
cd /path/to/ai-workstation-bob
cp .env.example .env
docker compose up -d
```

需要修改的通常只有：

- `IMAGE_NAME`
- `PASSWORD`、`SSH_PASSWORD`、`VNC_PASSWORD`
- `SOCKS5_PROXY_HOST`、`SOCKS5_PROXY_PORT`、`SOCKS5_PROXY_USERNAME`、`SOCKS5_PROXY_PASSWORD`
- `HOME_HOST_DIR`、`WORKSPACE_HOST_DIR`、`LOGS_HOST_DIR`
- `SSH_PORT`、`WEB_VNC_PORT`

这个模式下，新目录里只需要：

- `.env`
- `docker-compose.yml`

建议每个副本目录使用不同的目录名，并确保端口和宿主机数据目录不冲突。这样每个实例都可以独立维护、独立持久化，而源码仓库只负责构建和升级镜像。

## 注意事项

- `docker compose` 运行时需要 `NET_ADMIN`，否则无法应用 `iptables`
- 如果宿主机本身拉镜像也要走代理，还需要单独配置 Docker daemon 代理
- 在当前策略下，本地 DNS 不放行，因此 `SOCKS5_PROXY_HOST` 必须使用 IP 地址
