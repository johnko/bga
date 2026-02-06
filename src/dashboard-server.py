import json
import subprocess

from fastapi import FastAPI
from pydantic import BaseModel, Field

app = FastAPI()


def dockerpsjson():
    dockerpsprocess = subprocess.run(
        [
            "docker",
            "ps",
            "--filter",
            "label=devcontainer.local_folder",
            "--format",
            "{{json}}",
        ],
        stdout=subprocess.PIPE,
    )
    dockerpsoutput = dockerpsprocess.stdout.decode("utf-8")
    dockerpsobject = json.loads(dockerpsoutput)
    for item in dockerpsobject:
        new_local_folder = "/".join(
            item.get("Labels").get("devcontainer.local_folder").split("/")[-2:]
        )
        if new_local_folder:
            item["Labels"]["devcontainer.local_folder"] = new_local_folder
    return dockerpsobject


class SafePort(BaseModel):
    host_ip: str
    host_port: int


class SafeLabels(BaseModel):
    dev__containers__id: str = Field(validation_alias="dev.containers.id")
    dev__containers__release: str = Field(validation_alias="dev.containers.release")
    dev__containers__source: str = Field(validation_alias="dev.containers.source")
    dev__containers__timestamp: str = Field(validation_alias="dev.containers.timestamp")
    dev__containers__variant: str = Field(validation_alias="dev.containers.variant")
    devcontainer__local_folder: str = Field(
        validation_alias="devcontainer.local_folder"
    )
    org__opencontainers__image__ref__name: str = Field(
        validation_alias="org.opencontainers.image.ref.name"
    )
    org__opencontainers__image__version: str = Field(
        validation_alias="org.opencontainers.image.version"
    )
    version: str


class Devcontainer(BaseModel):
    Id: str
    Names: list[str]
    Ports: list[SafePort]
    Labels: SafeLabels


@app.get("/v1")
def read_v1_api_root():
    return "OK"


@app.get("/v1/devcontainers")
def list_devcontainers() -> list[Devcontainer]:
    result_all = dockerpsjson()
    return result_all


@app.get("/v1/devcontainers/{devcontainer_id}")
def get_devcontainer_details(devcontainer_id: str) -> Devcontainer:
    result_all = dockerpsjson()
    for item in result_all:
        if item["Id"] == devcontainer_id:
            return item
