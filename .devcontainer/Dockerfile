FROM --platform=linux/amd64 mcr.microsoft.com/devcontainers/universal:5-noble

COPY ./setup.sh /setup.sh
RUN bash /setup.sh

COPY ./opencode-serve.sh /opencode-serve.sh
RUN chmod a+rx /opencode-serve.sh

# RUN install -d -o codespace /home/codespace/.opencode/plugin/
# COPY ./opencode-background-agents/src/plugin/ /home/codespace/.opencode/plugin/
# RUN chown -R codespace /home/codespace/.opencode

EXPOSE 4096
