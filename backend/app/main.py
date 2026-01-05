"""FastAPI application entry point."""

from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, PlainTextResponse
from fastapi.staticfiles import StaticFiles

from app.api.v1.router import api_router
from app.config import settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    # Startup
    print(f"Starting {settings.APP_NAME}...")
    # Initialize database tables
    from app.db import init_db
    await init_db()
    print("Database initialized.")
    yield
    # Shutdown
    print(f"Shutting down {settings.APP_NAME}...")


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
    """Health check endpoint."""
    return {"status": "healthy"}


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
