"""API v1 router."""

from fastapi import APIRouter

from app.api.v1 import (
    auth, automations, charging, devices, llm, routes, shares, trips, user, vehicles,
)

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(vehicles.router, prefix="/vehicles", tags=["vehicles"])
api_router.include_router(routes.router, prefix="/routes", tags=["routes"])
api_router.include_router(charging.router, prefix="/charging", tags=["charging"])
api_router.include_router(devices.router, prefix="/devices", tags=["devices"])
api_router.include_router(automations.router, prefix="/automations", tags=["automations"])
api_router.include_router(user.router, prefix="/user", tags=["user"])
api_router.include_router(shares.router, prefix="/shares", tags=["shares"])
api_router.include_router(trips.router, prefix="/trips", tags=["trips"])
api_router.include_router(llm.router, prefix="/llm", tags=["llm"])
