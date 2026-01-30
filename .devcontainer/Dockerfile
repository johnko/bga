FROM --platform=linux/amd64 mcr.microsoft.com/devcontainers/universal:5-noble

COPY ./setup.sh /setup.sh
RUN bash /setup.sh

COPY ./opencode-serve.sh /opencode-serve.sh

EXPOSE 4096
