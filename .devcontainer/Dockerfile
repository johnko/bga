FROM --platform=linux/amd64 mcr.microsoft.com/devcontainers/universal:5-noble

COPY ./setup.sh /setup.sh
RUN bash /setup.sh

COPY ./opencode-serve.sh /opencode-serve.sh
RUN chmod a+rx /opencode-serve.sh

EXPOSE 4096

CMD ["bash", "/opencode-serve.sh"]
