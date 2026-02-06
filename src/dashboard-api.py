import devcontainers_v1

from fastapi import FastAPI

app = FastAPI()

app.include_router(devcontainers_v1.router, prefix="/v1")
