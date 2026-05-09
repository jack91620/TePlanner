"""FastAPI application entry point."""

import asyncio
import logging
import sys
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, PlainTextResponse
from fastapi.staticfiles import StaticFiles

from app.api.v1.router import api_router
from app.config import settings

# Configure logging with timestamp
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(name)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    handlers=[logging.StreamHandler(sys.stdout)],
)

# Also configure uvicorn access logs
uvicorn_access = logging.getLogger("uvicorn.access")
uvicorn_access.handlers = []
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(logging.Formatter("%(asctime)s - %(levelname)s - %(message)s", "%Y-%m-%d %H:%M:%S"))
uvicorn_access.addHandler(handler)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    # Startup
    print(f"Starting {settings.APP_NAME}...")
    # Initialize database tables.
    # 2026-05-10: gate behind DB_AUTO_MIGRATE because asyncio.to_thread
    # → alembic upgrade head is racing with sqlite WAL on prod under
    # uvicorn --reload (worker spawns concurrently with cron_tick worker
    # and they fight over the schema-modify lock). Production DB is
    # already at head; treat schema migrations as a deploy-time op:
    #     ssh prod && alembic upgrade head
    # Set DB_AUTO_MIGRATE=true on dev / fresh boxes to opt back in.
    if str(getattr(settings, "DB_AUTO_MIGRATE", "false")).lower() == "true":
        from app.db import init_db
        await init_db()
        print("Database initialized.")
    else:
        print("Database init skipped (DB_AUTO_MIGRATE=false).")

    cron_task = None
    cron_stop = None
    cron_interval = (
        getattr(settings, "AUTOMATION_CRON_TICK_SECONDS", 0)
        or settings.AUTOMATION_POLL_INTERVAL_SECONDS
    )
    if cron_interval and int(cron_interval) > 0:
        from app.services.cron_tick import run_loop as cron_loop

        cron_stop = asyncio.Event()
        cron_task = asyncio.create_task(cron_loop(cron_stop), name="cron_tick")
        print(f"Cron tick loop started (interval={cron_interval}s).")
    else:
        print("Cron tick disabled (AUTOMATION_CRON_TICK_SECONDS=0).")

    telemetry_task = None
    telemetry_stop = None
    if settings.TELEMETRY_ZMQ_ADDR:
        from app.services.telemetry.consumer import consume as telemetry_consume

        telemetry_stop = asyncio.Event()
        telemetry_task = asyncio.create_task(
            telemetry_consume(telemetry_stop), name="telemetry_consumer"
        )
        print(f"Telemetry consumer started (zmq={settings.TELEMETRY_ZMQ_ADDR}).")
    else:
        print("Telemetry consumer disabled (TELEMETRY_ZMQ_ADDR empty).")

    yield

    # Shutdown
    print(f"Shutting down {settings.APP_NAME}...")
    if cron_stop is not None:
        cron_stop.set()
    if cron_task is not None:
        try:
            await asyncio.wait_for(cron_task, timeout=10.0)
        except asyncio.TimeoutError:
            cron_task.cancel()
    if telemetry_stop is not None:
        telemetry_stop.set()
    if telemetry_task is not None:
        try:
            await asyncio.wait_for(telemetry_task, timeout=5.0)
        except asyncio.TimeoutError:
            telemetry_task.cancel()


app = FastAPI(
    title=settings.APP_NAME,
    description="Tesla intelligent charging route planner for highway service areas",
    version="0.1.0",
    lifespan=lifespan,
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API router
app.include_router(api_router, prefix="/api/v1")

# Mount static files for WeChat verification
static_dir = Path(__file__).parent.parent / "static"
static_dir.mkdir(exist_ok=True)
app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "name": settings.APP_NAME,
        "version": "0.1.0",
        "status": "running",
    }


@app.get("/health")
async def health_check():
    """Health check endpoint. Returns app version + status — the
    `version` field is consumed by `tests/test_health.py` and
    surfaced in the `ops/server-monitor.sh` snapshot for cross-
    referencing post-deploy. Source: `app.config.settings.APP_VERSION`
    if defined, falling back to '0.0.0' for local runs.
    """
    return {
        "status": "healthy",
        "version": getattr(settings, "APP_VERSION", "0.0.0"),
    }


# WeChat verification file endpoint
# Files like WW_verify_xxxxx.txt need to be served from root
@app.get("/{filename:path}")
async def serve_wechat_verification(filename: str):
    """Serve WeChat domain verification files from static directory."""
    # Only serve .txt files that look like verification files
    if not filename.endswith(".txt"):
        raise HTTPException(status_code=404, detail="Not found")

    file_path = static_dir / filename
    if file_path.exists() and file_path.is_file():
        return FileResponse(file_path, media_type="text/plain")

    raise HTTPException(status_code=404, detail="Not found")


# For Serverless deployment
def handler(event, context):
    """AWS Lambda / Serverless handler."""
    from mangum import Mangum

    asgi_handler = Mangum(app)
    return asgi_handler(event, context)
