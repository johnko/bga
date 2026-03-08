from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import HTMLResponse, RedirectResponse, Response
from fastapi.staticfiles import StaticFiles

import io
import re

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


@app.get("/proxy/codeserver/{path:path}")
async def proxy_code_server(path: str, request: Request):
    """Proxy requests to code-server container for the web interface"""
    devcontainer_id = path.split("/")[0]
    container = await get_devcontainer_details(devcontainer_id)
    host_port = container.get("codeserver_proxy", {}).get("host_port")

    proxied_path = request.url.path.replace(f"/proxy/codeserver/{devcontainer_id}", "")
    # Ensure no double slashes and handle trailing slash properly
    if proxied_path.endswith("/"):
        proxied_path = proxied_path.rstrip("/")

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
            raw_bytes = response.read()
            encoding = response.headers.get_content_charset() or "utf-8"
            if not proxied_path.endswith(
                (
                    ".ico",
                    ".png",
                    ".ttf",
                )
            ):
                decoded_string = raw_bytes.decode(encoding)
                response_content = (
                    decoded_string.replace(
                        'src="s', f'src="/proxy/codeserver/{devcontainer_id}/s'
                    )
                    .replace('href="./', f'href="/proxy/codeserver/{devcontainer_id}/')
                    .replace('href="s', f'href="/proxy/codeserver/{devcontainer_id}/s')
                )
            else:
                response_content = raw_bytes
            response_headers = response.headers
            if response_headers["Content-Security-Policy"]:
                # print(response_headers["Content-Security-Policy"])
                temp = re.sub(
                    r"script-src[^;]+;",
                    "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
                    response_headers["Content-Security-Policy"].replace(
                        "script-src 'self'", "script-src 'self' 'unsafe-inline'"
                    ),
                )
                # print(temp)
                del response_headers["Content-Security-Policy"]
                response_headers["Content-Security-Policy"] = temp
                print(response_headers["Content-Security-Policy"])
            return Response(
                response_content,
                headers=response_headers,
                status_code=response.status,
            )
    except Exception as e:
        error_msg = str(e)
        raise HTTPException(status_code=502, detail=error_msg)


app.mount("/dashboard", StaticFiles(directory="web", html=True), name="dashboard")
