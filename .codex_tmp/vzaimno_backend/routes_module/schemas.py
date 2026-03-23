from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel, Field


class CoordinateIn(BaseModel):
    lat: float
    lon: float


class CoordinateOut(BaseModel):
    lat: float
    lon: float


class RouteBuildIn(BaseModel):
    announcement_id: str | None = None
    polyline: List[List[float]] = Field(default_factory=list)
    start_address: str | None = None
    end_address: str | None = None
    distance_meters: int | None = None
    duration_seconds: int | None = None
    radius_m: int = Field(default=500, ge=50, le=5_000)
    travel_mode: str = Field(default="driving")


class RouteContextOut(BaseModel):
    entity_id: str
    start_address: str
    end_address: str
    start: CoordinateOut
    end: CoordinateOut
    radius_m: int = Field(default=500)
    travel_mode: str = Field(default="driving")


class RouteTaskByPathOut(BaseModel):
    id: str
    title: str
    category: Optional[str] = None
    address_text: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    distance_to_route_meters: float = Field(default=0)
    price_text: Optional[str] = None
    preview_image_url: Optional[str] = None
    status: Optional[str] = None


class RouteDetailsOut(BaseModel):
    entity_id: str
    start_address: str
    end_address: str
    distance_meters: int = 0
    duration_seconds: int = 0
    distance_text: str
    duration_text: str
    polyline: List[List[float]] = Field(default_factory=list)
    tasks_by_route: List[RouteTaskByPathOut] = Field(default_factory=list)
