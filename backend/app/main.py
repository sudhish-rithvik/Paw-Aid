"""
app/main.py — PAW-AID FastAPI application entry point.

Configures:
- CORS (all origins for hackathon)
- Static file serving for local uploads
- All API routers with /api prefix
- Startup event to create upload directory
- Health check endpoint
"""

from __future__ import annotations

import logging
import os
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import get_settings
from app.routers import auth, reports, cases, ngos, admin, analytics

# ── Logging setup ─────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(name)s — %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# ── App factory ───────────────────────────────────────────────────────────────
settings = get_settings()

app = FastAPI(
    title="PAW-AID API",
    description=(
        "AI-powered emergency animal rescue platform. "
        "Instantly connects citizens with NGOs using computer vision and smart dispatch."
    ),
    version="1.0.0",
    contact={"name": "PAW-AID Team", "email": "admin@paw-aid.app"},
    license_info={"name": "MIT"},
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
)

# ── CORS ──────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],          # Hackathon: open; restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(auth.router,      prefix="/api/auth")
app.include_router(reports.router,   prefix="/api")
app.include_router(cases.router,     prefix="/api")
app.include_router(ngos.router,      prefix="/api")
app.include_router(admin.router,     prefix="/api")
app.include_router(analytics.router, prefix="/api")


# ── Startup ───────────────────────────────────────────────────────────────────
@app.on_event("startup")
async def on_startup() -> None:
    upload_path = Path(settings.upload_dir)
    upload_path.mkdir(parents=True, exist_ok=True)
    logger.info("Upload directory ready: %s", upload_path.resolve())

    # Serve local uploads as static files
    app.mount(
        "/uploads",
        StaticFiles(directory=str(upload_path)),
        name="uploads",
    )

    demo_msg = " [DEMO MODE — no external API keys required]" if settings.demo_mode else ""
    logger.info("PAW-AID backend started on %s%s", settings.backend_url, demo_msg)


# ── Health check ──────────────────────────────────────────────────────────────
@app.get("/", tags=["health"])
async def health_check():
    """Simple liveness probe."""
    return {
        "status": "ok",
        "service": "PAW-AID API",
        "version": "1.0.0",
        "demo_mode": settings.demo_mode,
    }


@app.get("/api/health", tags=["health"])
async def api_health():
    """Detailed health check with connectivity status."""
    from app.supabase_client import get_supabase

    db_ok = False
    try:
        supabase = get_supabase()
        supabase.table("profiles").select("id").limit(1).execute()
        db_ok = True
    except Exception as exc:
        logger.warning("DB health check failed: %s", exc)

    return {
        "status": "ok" if db_ok else "degraded",
        "database": "connected" if db_ok else "unavailable",
        "demo_mode": settings.demo_mode,
        "version": "1.0.0",
    }
