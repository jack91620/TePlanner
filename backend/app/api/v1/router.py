"""API v1 router."""

from fastapi import APIRouter

from app.api.v1 import auth, charging, routes, vehicles

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(vehicles.router, prefix="/vehicles", tags=["vehicles"])
api_router.include_router(routes.router, prefix="/routes", tags=["routes"])
api_router.include_router(charging.router, prefix="/charging", tags=["charging"])
