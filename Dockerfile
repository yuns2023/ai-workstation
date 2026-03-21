FROM node:22-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV HOME=/home/dev
ENV SHELL=/bin/bash
ENV TZ=America/New_York

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
    ncurses-term \
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
    tzdata \
    vim-tiny \
    wget \
    xfce4 \
    xfce4-terminal \
    x11vnc \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

RUN sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 LANGUAGE=en_US:en

ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV LANGUAGE=en_US:en

RUN mkdir -p /var/run/sshd /etc/supervisor/conf.d /opt/bin /workspace \
    && chmod 0755 /workspace

RUN npm install -g @openai/codex \
    && BUILD_HOME="$(mktemp -d)" \
    && export HOME="${BUILD_HOME}" \
    && export PATH="${BUILD_HOME}/.local/bin:${PATH}" \
    && curl -fsSL https://claude.ai/install.sh | bash \
    && install -d /usr/local/lib/claude-native \
    && install -m 0755 "$(readlink -f "${BUILD_HOME}/.local/bin/claude")" /usr/local/lib/claude-native/claude \
    && ln -sf /usr/local/lib/claude-native/claude /usr/local/bin/claude-native \
    && rm -rf "${BUILD_HOME}"

COPY config/sshd_config /etc/ssh/sshd_config
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY config/proxychains.conf /etc/proxychains4.conf
COPY config/novnc-index.html /usr/share/novnc/index.html
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

RUN chmod +x /opt/bin/*.sh /usr/local/bin/proxy-shell /usr/local/bin/proxy-codex /usr/local/bin/proxy-claude /usr/local/bin/proxy-browser \
    && ln -sf /usr/local/bin/proxy-claude /usr/local/bin/claude

EXPOSE 22 5900 6080

ENTRYPOINT ["/opt/bin/entrypoint.sh"]
