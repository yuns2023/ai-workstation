FROM node:22-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV DISPLAY=:1
ENV HOME=/home/dev
ENV SHELL=/bin/bash

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    chromium \
    curl \
    dbus-x11 \
    dnsutils \
    git \
    iproute2 \
    iptables \
    locales \
    netcat-openbsd \
    novnc \
    openssh-server \
    privoxy \
    procps \
    proxychains4 \
    python3 \
    python3-websockify \
    ripgrep \
    sudo \
    supervisor \
    tmux \
    vim-tiny \
    wget \
    xfce4 \
    xfce4-terminal \
    x11vnc \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen C.UTF-8

RUN mkdir -p /var/run/sshd /etc/supervisor/conf.d /opt/bin /workspace \
    && chmod 0755 /workspace

RUN npm install -g @openai/codex @anthropic-ai/claude-code

COPY config/sshd_config /etc/ssh/sshd_config
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY config/proxychains.conf /etc/proxychains4.conf
COPY scripts/entrypoint.sh /opt/bin/entrypoint.sh
COPY scripts/bootstrap-user.sh /opt/bin/bootstrap-user.sh
COPY scripts/start-xfce.sh /opt/bin/start-xfce.sh
COPY scripts/start-vnc.sh /opt/bin/start-vnc.sh
COPY scripts/start-novnc.sh /opt/bin/start-novnc.sh
COPY scripts/start-privoxy.sh /opt/bin/start-privoxy.sh
COPY scripts/apply-egress-lockdown.sh /opt/bin/apply-egress-lockdown.sh
COPY scripts/proxy-shell /usr/local/bin/proxy-shell
COPY scripts/codex-wrapper.sh /usr/local/bin/proxy-codex
COPY scripts/claude-wrapper.sh /usr/local/bin/proxy-claude
COPY scripts/proxy-browser.sh /usr/local/bin/proxy-browser

RUN chmod +x /opt/bin/*.sh /usr/local/bin/proxy-shell /usr/local/bin/proxy-codex /usr/local/bin/proxy-claude /usr/local/bin/proxy-browser

EXPOSE 22 5900 6080

ENTRYPOINT ["/opt/bin/entrypoint.sh"]
