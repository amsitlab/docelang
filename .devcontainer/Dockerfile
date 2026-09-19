FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ARG LOGFILE=/container.log
ARG ZIG_VERSION=0.14.0
RUN apt-get update 2>&1 | tee -a $LOGFILE; \
    apt-get install -y  \
    curl git build-essential pkg-config cmake \
    python3 python3-pip xz-utils ca-certificates \
    libxcb1-dev libx11-dev socat supervisor 2>&1 | tee -a $LOGFILE; \
    apt-get clean 2>&1 | tee -a $LOGFILE; \
	rm -rf /var/lib/apt/lists/* 2>&1 | tee -a $LOGFILE

RUN curl -LO https://ziglang.org/download/${ZIG_VERSION}/zig-linux-x86_64-${ZIG_VERSION}.tar.xz 2>&1 | tee -a $LOGFILE; \
    tar -xf zig-linux-x86_64-${ZIG_VERSION}.tar.xz 2>&1 | tee -a $LOGFILE; \
    mv zig-linux-x86_64-${ZIG_VERSION} /opt/zig 2>&1 | tee -a $LOGFILE; \
    ln -s /opt/zig/zig /usr/local/bin/zig 2>&1 | tee -a $LOGFILE; \
    rm zig-linux-x86_64-${ZIG_VERSION}.tar.xz 2>&1 | tee -a $LOGFILE

#RUN git clone https://github.com/zigtools/zls.git --branch "0.14.0" /opt/zls && \
#    cd /opt/zls && \
#    /opt/zig/zig build -Doptimize=ReleaseSsafe && \
#    ln -s /opt/zls/zig-out/bin/zls /usr/local/bin/zls

RUN TMP_DIR=$(mktemp -d) && \
    curl -L "https://github.com/zigtools/zls/releases/download/0.14.0/zls-x86_64-linux.tar.xz" | \
	tar -xJ -C $TMP_DIR 2>&1 | tee -a $LOGFILE; \
	mv $TMP_DIR/zls /usr/local/bin/zls | tee -a $LOGFILE

RUN

RUN useradd -s /bin/bash -m devuser
#USER devuser
#WORKDIR /home/devuser

SHELL ["/bin/bash", "-c"]

# Copy supervisor config (pastikan file ini ada di .devcontainer/supervisord.conf di repo kamu)
#COPY .devcontainer/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Set supervisor as container entrypoint
#CMD ["/usr/bin/supervisord", "-c", ".devcontainer/supervisord.conf"]
