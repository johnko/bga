from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, RedirectResponse, Response
from fastapi.staticfiles import StaticFiles

import urllib.request
import urllib.parse

app = FastAPI()


@app.get("/")
def index():
    return RedirectResponse(url="/dashboard/")


@app.get("/v1/devcontainers")
async def list_devcontainers():
    from api.routers import v1

    result = v1.dockerpsjson()
    # Process containers to detect code-server ports and add proxy URLs
    containers = []
    for container in result:
        processed_container = container.copy()
        if container.get("Ports"):
            codeserver_proxy = None
            for port in container["Ports"]:
                if (
                    port.get("container_port") == 8080
                    and port.get("host_ip") == "127.0.0.1"
                    and container.get("Labels", {}).get("devcontainer.metadata", "")
                    and "code-server" in container["Labels"]["devcontainer.metadata"]
                ):
                    codeserver_proxy = {
                        "proxy_path": f"/proxy/codeserver/{container['Id'].split(':')[0]}/",
                        "host_port": port["host_port"],
                        "container_port": port["container_port"],
                    }
                    break
            processed_container["codeserver_proxy"] = codeserver_proxy
        containers.append(processed_container)
    return {"containers": containers}


@app.get("/v1/devcontainers/{devcontainer_id}")
async def get_devcontainer_details(devcontainer_id: str):
    from api.routers import v1

    try:
        for container in v1.dockerpsjson():
            if container.get("Id") == devcontainer_id:
                # Detect code-server port
                codeserver_proxy = None
                if container.get("Ports"):
                    for port in container["Ports"]:
                        if (
                            port.get("container_port") == 8080
                            and port.get("host_ip") == "127.0.0.1"
                            and container.get("Labels", {}).get(
                                "devcontainer.metadata", ""
                            )
                            and "code-server"
                            in container["Labels"]["devcontainer.metadata"]
                        ):
                            codeserver_proxy = {
                                "proxy_path": f"/proxy/codeserver/{devcontainer_id.split(':')[0]}/",
                                "host_port": port["host_port"],
                                "container_port": port["container_port"],
                            }
                            break
                container["codeserver_proxy"] = codeserver_proxy
                return container
        raise HTTPException(status_code=404, detail="Container not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/proxy/codeserver/{devcontainer_id:path}/")
async def proxy_code_server(devcontainer_id: str, request: Request):
    """Proxy requests to code-server container for the web interface"""
    container = await get_devcontainer_details(devcontainer_id)
    host_port = (
        container
        .get("codeserver_proxy", {})
        .get("host_port")
    )

    proxied_path = request.url.path.replace(f"/proxy/codeserver/{devcontainer_id}", "")

    target_url = f"http://127.0.0.1:{host_port}{proxied_path}"
    print(target_url)

    try:
        import urllib.request

        headers = {}
        body = None

        if request.method not in ["GET", "HEAD"]:
            body_bytes = await request.body()
            if body_bytes:
                body = (
                    bytes(body_bytes)
                    if isinstance(body_bytes, memoryview)
                    else body_bytes
                )

        req = urllib.request.Request(target_url, data=body, headers=headers)

        with urllib.request.urlopen(req, timeout=120) as response:
            return Response(
                response.read(),
                status_code=response.status,
            )
    except Exception as e:
        error_msg = str(e)
        raise HTTPException(status_code=502, detail=error_msg)


@app.get("/proxy/codeserver/{devcontainer_id:path}/{extra_path}")
async def proxy_code_server(devcontainer_id: str, request: Request, extra_path: str):
    """Proxy requests to code-server container for the web interface"""
    container = await get_devcontainer_details(devcontainer_id)
    host_port = (
        container
        .get("codeserver_proxy", {})
        .get("host_port")
    )

    proxied_path = request.url.path.replace(f"/proxy/codeserver/{devcontainer_id}", "")

    target_url = f"http://127.0.0.1:{host_port}{proxied_path}"
    print(target_url)

    try:
        import urllib.request

        headers = {}
        body = None

        if request.method not in ["GET", "HEAD"]:
            body_bytes = await request.body()
            if body_bytes:
                body = (
                    bytes(body_bytes)
                    if isinstance(body_bytes, memoryview)
                    else body_bytes
                )

        req = urllib.request.Request(target_url, data=body, headers=headers)

        with urllib.request.urlopen(req, timeout=120) as response:
            return Response(
                response.read(),
                status_code=response.status,
            )
    except Exception as e:
        error_msg = str(e)
        raise HTTPException(status_code=502, detail=error_msg)


app.mount("/dashboard", StaticFiles(directory="web", html=True), name="dashboard")
