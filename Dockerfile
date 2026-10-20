ARG BASE_IMAGE=debian:stable-slim
FROM ${BASE_IMAGE}

RUN if command -v apk >/dev/null 2>&1; then \
      apk add --no-cache bash shadow acl openssl; \
    else \
      apt-get update && \
      apt-get install -y --no-install-recommends bash passwd acl openssl && \
      rm -rf /var/lib/apt/lists/*; \
    fi

WORKDIR /app

CMD ["bash", "-c", "bash main.sh; exec bash"]