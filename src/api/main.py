from fastapi import FastAPI
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles

app = FastAPI()

@app.get("/")
def index():
    return RedirectResponse(url="/dashboard/")


@app.get("/v1/devcontainers")
async def list_devcontainers():
    from api.routers import v1
    result = v1.dockerpsjson()
    return {"containers": result}


@app.get("/v1/devcontainers/{devcontainer_id}")
async def get_devcontainer_details(devcontainer_id: str):
    from api.routers import v1
    try:
        for container in v1.dockerpsjson():
            if container.get("Id") == devcontainer_id:
                return container
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Container not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


app.mount("/dashboard", StaticFiles(directory="web"), name="dashboard")
