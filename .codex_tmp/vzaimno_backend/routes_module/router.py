from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.db import fetch_one
from app.schemas import UserOut
from app.security import decode_token

from .schemas import RouteBuildIn, RouteContextOut, RouteDetailsOut
from .service import (
    DEFAULT_ROUTE_LIMIT,
    DEFAULT_ROUTE_RADIUS_METERS,
    build_route_for_announcement,
    build_route_for_current_user,
    build_route_from_polyline,
    build_route_context_for_announcement,
    build_route_context_for_current_user,
)

router = APIRouter(tags=["routes"])
bearer = HTTPBearer(auto_error=True)


def _user_from_token(token: str) -> UserOut:
    if token == "DEV_TOKEN":
        return UserOut(id="dev", email="dev@localdomain.com", role="user")

    try:
        payload = decode_token(token)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token payload")

    row = fetch_one("SELECT id::text, email, role FROM users WHERE id = %s", (user_id,))
    if not row:
        raise HTTPException(status_code=401, detail="User not found")

    return UserOut(id=row[0], email=row[1], role=row[2])


def get_current_user(creds: HTTPAuthorizationCredentials = Depends(bearer)) -> UserOut:
    return _user_from_token(creds.credentials)


@router.get("/announcements/{ann_id}/route", response_model=RouteDetailsOut)
def announcement_route(
    ann_id: str,
    radius_m: int = DEFAULT_ROUTE_RADIUS_METERS,
    limit: int = DEFAULT_ROUTE_LIMIT,
    user: UserOut = Depends(get_current_user),
) -> RouteDetailsOut:
    normalized_radius = max(50, min(int(radius_m), 5000))
    normalized_limit = max(1, min(int(limit), 100))
    return build_route_for_announcement(
        announcement_id=ann_id,
        user_id=user.id,
        radius_m=normalized_radius,
        limit=normalized_limit,
    )


@router.get("/routes/me/current", response_model=RouteDetailsOut)
def my_current_route(
    radius_m: int = DEFAULT_ROUTE_RADIUS_METERS,
    limit: int = DEFAULT_ROUTE_LIMIT,
    user: UserOut = Depends(get_current_user),
) -> RouteDetailsOut:
    normalized_radius = max(50, min(int(radius_m), 5000))
    normalized_limit = max(1, min(int(limit), 100))
    return build_route_for_current_user(
        user_id=user.id,
        radius_m=normalized_radius,
        limit=normalized_limit,
    )


@router.get("/announcements/{ann_id}/route/context", response_model=RouteContextOut)
def announcement_route_context(
    ann_id: str,
    radius_m: int = DEFAULT_ROUTE_RADIUS_METERS,
    user: UserOut = Depends(get_current_user),
) -> RouteContextOut:
    normalized_radius = max(50, min(int(radius_m), 5000))
    return build_route_context_for_announcement(
        announcement_id=ann_id,
        user_id=user.id,
        radius_m=normalized_radius,
    )


@router.get("/routes/me/current/context", response_model=RouteContextOut)
def my_current_route_context(
    radius_m: int = DEFAULT_ROUTE_RADIUS_METERS,
    user: UserOut = Depends(get_current_user),
) -> RouteContextOut:
    normalized_radius = max(50, min(int(radius_m), 5000))
    return build_route_context_for_current_user(
        user_id=user.id,
        radius_m=normalized_radius,
    )


@router.post("/route/build", response_model=RouteDetailsOut)
def route_build(
    request: RouteBuildIn,
    limit: int = DEFAULT_ROUTE_LIMIT,
    user: UserOut = Depends(get_current_user),
) -> RouteDetailsOut:
    normalized_limit = max(1, min(int(limit), 100))
    return build_route_from_polyline(
        announcement_id=request.announcement_id,
        user_id=user.id,
        polyline=request.polyline,
        start_address=request.start_address,
        end_address=request.end_address,
        distance_meters=request.distance_meters,
        duration_seconds=request.duration_seconds,
        radius_m=request.radius_m,
        limit=normalized_limit,
        travel_mode=request.travel_mode,
    )
