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
