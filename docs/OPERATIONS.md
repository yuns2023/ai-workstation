# Operations

## 查看日志

```bash
docker compose logs -f
```

```bash
docker exec -it ai-workstation tail -f /var/log/ai-workstation/sshd.log
```

## 重建

```bash
docker compose down
docker compose up -d --build
```

## 进入容器排障

```bash
docker exec -it ai-workstation bash
```

## 验证代理限制

进入容器后执行：

```bash
curl https://example.com
```

如果 `.bashrc` 已加载，这会通过 `proxychains4` 与 `ALL_PROXY` 出网。

再测试直连限制：

```bash
env -u ALL_PROXY -u HTTP_PROXY -u HTTPS_PROXY curl --max-time 5 https://example.com
```

在 `ENABLE_IPTABLES=1` 时，这个请求应失败。

## 白名单直连

如果你希望默认所有外网请求继续走代理，但允许少量目标直连，需要同时配置三层：

```env
DIRECT_HOSTS=api.saiai.top
DIRECT_IPS=64.186.230.21
DIRECT_HOST_IP_MAP=api.saiai.top:64.186.230.21
```

含义：

- `DIRECT_HOSTS`
  让 `codex`、浏览器和 shell 环境把这些域名加入直连白名单
- `DIRECT_IPS`
  让容器 `iptables` 放行这些固定 IP / CIDR
- `DIRECT_HOST_IP_MAP`
  在 `DISABLE_LOCAL_DNS=1` 时，把域名静态写入容器 `/etc/hosts`

注意：

- 只配 `DIRECT_HOSTS` 不够
- 在 `DISABLE_LOCAL_DNS=1` 下，如果没有 `DIRECT_IPS` 和 `DIRECT_HOST_IP_MAP`，应用虽然“不走代理”，但依然可能因为 DNS 或防火墙失败
- 不要对容器内的 `/etc/hosts` 使用 `sed -i` 这类需要 rename 的写法，Docker 管理的 `/etc/hosts` 可能因此报 `Device or resource busy`

## Codex 排障

如果 `codex` 报类似：

```text
stream disconnected before completion
error sending request for url (https://api.saiai.top/responses)
```

建议按这个顺序排查：

1. 先确认 `proxy-codex` 是否真的走了直连分支

```bash
bash -x /usr/local/bin/proxy-codex --version
```

如果命中白名单，应该看到：

```text
unset ALL_PROXY HTTP_PROXY HTTPS_PROXY ...
exec node ...
```

而不是：

```text
exec proxy-shell node ...
```

2. 再确认容器里是否真的能直连该域名

```bash
getent hosts api.saiai.top
curl --resolve api.saiai.top:443:64.186.230.21 https://api.saiai.top/responses
```

3. 如果最小化 `curl` 流式请求能通，但 `codex exec` 仍断流，再对比：

- 宿主机是否能用同一份 `~/.codex`
- 容器内是否存在额外网络栈差异

这通常说明问题不在基础连通性，而在 `Codex` 完整请求形态或容器运行环境差异。
