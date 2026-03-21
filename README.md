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
EMPLOYEE_ID=alice
DATA_ROOT=./employee-data
PASSWORD=your-login-password
SSH_PASSWORD=your-login-password
VNC_PASSWORD=your-vnc-password
SOCKS5_PROXY_HOST=your-proxy-host-or-ip
SOCKS5_PROXY_PORT=1080
SOCKS5_PROXY_USERNAME=your-proxy-username
SOCKS5_PROXY_PASSWORD=your-proxy-password
INTERNAL_DIRECT_CIDRS=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
DISABLE_LOCAL_DNS=1
BROWSER_HTTP_PROXY_PORT=8118
```

3. 构建并启动：

```bash
./scripts/employee-compose.sh up -d --build
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

如果直接用 `docker compose`，默认会挂载这些路径：

- `./data/home:/home`
- `./data/workspace:/workspace`
- `./logs:/var/log/ai-workstation`

如果用推荐的 `./scripts/employee-compose.sh`，宿主机会自动按员工生成目录：

- `${DATA_ROOT}/${EMPLOYEE_ID}/home`
- `${DATA_ROOT}/${EMPLOYEE_ID}/workspace`
- `${DATA_ROOT}/${EMPLOYEE_ID}/logs`

这意味着你外部只需要维护：

- `EMPLOYEE_ID`
- `DATA_ROOT`
- 该员工的代理配置

浏览器 profile、shell 历史、SSH known_hosts、工作目录都会自动落到对应员工的外部目录里，不需要单独再配一套路径。

## 多员工

推荐每个员工一份 env 文件，例如：

```text
employees/alice.env
employees/bob.env
```

启动时：

```bash
./scripts/employee-compose.sh employees/alice.env up -d --build
./scripts/employee-compose.sh employees/bob.env up -d --build
```

这个脚本会自动：

- 用 `EMPLOYEE_ID` 生成 compose project name
- 自动创建该员工的宿主机目录
- 自动把外部目录映射到容器内

如果多名员工要在同一台宿主机上同时运行，还需要保证每份 env 文件里的：

- `SSH_PORT`
- `WEB_VNC_PORT`

彼此不冲突。这两个端口仍然建议由外部显式分配，而目录不需要手工维护。

## 注意事项

- `docker compose` 运行时需要 `NET_ADMIN`，否则无法应用 `iptables`
- 如果宿主机本身拉镜像也要走代理，还需要单独配置 Docker daemon 代理
- 在当前策略下，本地 DNS 不放行，因此 `SOCKS5_PROXY_HOST` 必须使用 IP 地址

## 后续可扩展

- 安装浏览器并固定代理启动参数
- 增加 `code-server`
- 增加 `tailscale` 或 `cloudflared` 作为远程入口
