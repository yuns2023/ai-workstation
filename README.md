# AI Workstation Container

单容器远程工作站，集成了这些能力：

- `SSH` 远程登录
- `Codex` 与 `Claude Code` CLI
- `Xfce` 桌面
- `VNC` 与 `noVNC`，既支持原生 VNC 客户端，也支持浏览器直接访问桌面
- 可选 `RealVNC Server` 后端，兼容 `RealVNC Connect`
- `Fcitx5` 五笔输入法与中文字体
- `Chromium` 浏览器，默认走本地 `Privoxy -> SOCKS5`
- `proxychains4` 和 `iptables` 出站限制

其中 `Claude Code` 通过 Anthropic 官方 `install.sh` 原生安装。容器里默认的 `claude` 命令会经过代理 wrapper，并通过本地 `Privoxy` 使用官方支持的 `HTTP_PROXY/HTTPS_PROXY` 出网；原始官方二进制保留为 `claude-native`。

镜像还会安装仓库内置的 `Charles Proxy SSL Proxying Certificate` 到系统 CA，方便你在容器里直接调试经 Charles 解密的 HTTPS 流量。

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
TZ=America/New_York
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
LANGUAGE=en_US:en
BROWSER_LANG=en-US
USERNAME=dev
HOME_DIR=/home/dev
VNC_SERVER_IMPL=auto
REALVNC_LICENSE_KEY=
REALVNC_AUTHENTICATION=VncAuth
REALVNC_ENCRYPTION=AlwaysOn
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
DIRECT_HOSTS=
DIRECT_IPS=
DIRECT_HOST_IP_MAP=
DISABLE_LOCAL_DNS=1
BROWSER_HTTP_PROXY_PORT=8118
SSH_PORT=2222
WEB_VNC_PORT=6080
VNC_PORT=15900
```

默认模板会把系统 locale、终端语言和浏览器语言设置为美国英语环境，并把系统时区设置为 `America/New_York`。

如果你要启用 `RealVNC Server`，构建前需要把官方 Linux 安装包放到：

```text
vendor/realvnc/VNC-Server-6.7.4-Linux-x64-ANY.tar.gz
```

运行时再通过 `.env` 注入 license key：

```env
VNC_SERVER_IMPL=realvnc
REALVNC_LICENSE_KEY=XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
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

根路径会自动跳转到 noVNC 页面，不需要手工补 `/vnc.html`。

注意：当 `VNC_SERVER_IMPL=realvnc` 时，`noVNC` 会自动停用，只保留原生 VNC 入口。

原生 VNC 客户端也可以直接连接：

```text
<server-ip>:15900
```

这套模式适合在源码目录里开发和重建镜像。执行后会在本机生成 `ai-workstation:local` 镜像，后面的极简实例目录会直接复用它。

## 代理策略

容器默认会做两层代理控制：

- shell 环境里注入 `ALL_PROXY=socks5h://...`
- `codex`、`claude` 默认走代理 wrapper
- shell 默认导出 `NO_PROXY=127.0.0.1,localhost,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16`
- `DIRECT_HOSTS` 里的域名会加入 `NO_PROXY`，浏览器和 `codex` 会对这些目标直连
- `DIRECT_IPS` 里的固定 IP/CIDR 会加入 `NO_PROXY`，并被 `iptables` 放行直连
- `DIRECT_HOST_IP_MAP` 用于在关闭本地 DNS 时，把直连域名静态写入容器 `/etc/hosts`
- 访问内网地址时，`curl`、`wget`、`git` 默认直连
- 如果你要强制让它们走 `proxychains4`，使用 `pcurl`、`pwget`、`pgit`
- `Chromium` 通过本地 `Privoxy` HTTP 代理转发到上游认证 `SOCKS5`
- `claude` 通过本地 `Privoxy` 使用 `HTTP_PROXY/HTTPS_PROXY`，不直接使用 `SOCKS`
- 当 `DISABLE_LOCAL_DNS=1` 时，容器本地 resolver 被显式禁用
- 容器默认通过 `sysctl` 禁用 `IPv6`，并在 `ip6tables` 上将出站默认拒绝

如果 `ENABLE_IPTABLES=1`，容器还会设置出站白名单：

- 允许访问 `INTERNAL_DIRECT_CIDRS` 里的内网网段
- 允许访问 `DIRECT_IPS` 里的额外直连目标
- 允许访问 `SOCKS5_PROXY_HOST:SOCKS5_PROXY_PORT`
- 允许访问容器本地回环
- 允许已建立连接
- 拒绝其他所有出站

这意味着：

- 内网网段可直连
- 外网访问只能经你的 SOCKS5 代理
- 外网 `UDP` 默认不会直连，当前仅内网网段可直连 `UDP`
- `IPv6` 默认禁用，不会通过 IPv6 出站绕过
- 本地 DNS 不放行，因此 `SOCKS5_PROXY_HOST` 应填写固定 IP
- 使用 `socks5h` 或 `proxychains4` 的 `proxy_dns` 做外部域名解析
- 浏览器通过本地 `127.0.0.1:${BROWSER_HTTP_PROXY_PORT}`，避免 Chromium 直接处理 SOCKS5 认证

交互式 shell 里常用的代理行为如下：

- `curl http://192.168.1.4:9001/login` 会直连内网
- `pcurl https://example.com` 会强制走 `proxychains4`
- `pgit clone ...` 和 `pwget ...` 同理

## 认证与登录

- 默认用户来自 `.env` 的 `USERNAME`
- 容器内 home 路径来自 `.env` 的 `HOME_DIR`，默认是 `/home/<USERNAME>`
- SSH 使用密码登录
- 原生 VNC 使用 `.env` 的 `VNC_PASSWORD`
- `RealVNC Server` 模式还需要 `.env` 的 `REALVNC_LICENSE_KEY`
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
- `USERNAME`、`HOME_DIR`
- `PASSWORD`、`SSH_PASSWORD`、`VNC_PASSWORD`
- `SOCKS5_PROXY_HOST`、`SOCKS5_PROXY_PORT`、`SOCKS5_PROXY_USERNAME`、`SOCKS5_PROXY_PASSWORD`
- `DIRECT_HOSTS`、`DIRECT_IPS`、`DIRECT_HOST_IP_MAP`
- `HOME_HOST_DIR`、`WORKSPACE_HOST_DIR`、`LOGS_HOST_DIR`
- `SSH_PORT`、`VNC_PORT`、`WEB_VNC_PORT`

这个模式下，新目录里只需要：

- `.env`
- `docker-compose.yml`

建议每个副本目录使用不同的目录名，并确保端口和宿主机数据目录不冲突。这样每个实例都可以独立维护、独立持久化，而源码仓库只负责构建和升级镜像。

如果后续会持续创建更多环境，推荐直接用脚手架：

```bash
cd /path/to/ai-workstation
./scripts/create-instance.sh alice
```

它会默认做这几件事：

- 在源码仓库外创建实例目录：`../ai-workstation-instances/alice`
- 在源码仓库外创建持久化目录：`../ai-workstation-state/alice`
- 实例目录里只放 `docker-compose.yml` 和 `.env`
- 自动写入唯一的容器内 `HOME_DIR`
- 自动写入独立的 `HOME_HOST_DIR`、`WORKSPACE_HOST_DIR`、`LOGS_HOST_DIR`
- 自动分配未占用的 `SSH_PORT`、`VNC_PORT` 和 `WEB_VNC_PORT`

脚手架支持自定义目录和端口：

```bash
./scripts/create-instance.sh alice \
  --dir /srv/ai-workstations/alice \
  --state-root /srv/ai-workstation-state/alice \
  --ssh-port 2225 \
  --web-port 6083
```

这套结构更适合长期维护多环境：

- 源码仓库只负责 `build` 和升级镜像
- 每个实例目录只保留运行配置
- 每个实例的数据目录完全独立
- 后续升级镜像后，只需要在各实例目录里执行 `docker compose up -d`

## 注意事项

- `docker compose` 运行时需要 `NET_ADMIN`，否则无法应用 `iptables`
- 如果宿主机本身拉镜像也要走代理，还需要单独配置 Docker daemon 代理
- 在当前策略下，本地 DNS 不放行，因此 `SOCKS5_PROXY_HOST` 必须使用 IP 地址
