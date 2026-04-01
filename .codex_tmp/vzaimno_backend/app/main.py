from __future__ import annotations

import json
import os
import uuid
import itsdangerous
from datetime import datetime, timezone
from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from fastapi import Depends, FastAPI, File, HTTPException, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from starlette.concurrency import run_in_threadpool

from app.bootstrap import ensure_all_tables
from app.chat import (
    assert_thread_access,
    broadcast_chat_event,
    broadcast_chat_message,
    connect_chat_socket,
    disconnect_chat_socket,
    get_or_create_offer_thread,
    list_thread_messages,
    list_user_threads,
    post_thread_message,
)
from app.db import execute, fetch_all, fetch_one
from app.geocoding import geocode_address
from app.moderation_image import get_nsfw_detector
from app.moderation_text import classify_text
from app.ops import create_notification, create_report, ensure_appeal_report, report_status_select_sql
from app.routes_module.router import router as routes_router
from app.schema_compat import table_has_column
from app.schemas import (
    AcceptOfferOut,
    AnnouncementOut,
    AppealIn,
    ChatMessageIn,
    ChatMessageOut,
    ChatThreadOut,
    CreateAnnouncementIn,
    CreateOfferIn,
    DeviceRegisterIn,
    DeviceUnregisterIn,
    GeoPointOut,
    LoginIn,
    MeProfileOut,
    OKOut,
    RegisterIn,
    ReportCreateIn,
    ReportOut,
    SupportMessageIn,
    SupportMessageOut,
    SupportThreadOut,
    TokenOut,
    UpdateMyProfileIn,
    OfferOut,
    OfferOutExpanded,
    UserProfileOut,
    UserReviewListOut,
    UserReviewOut,
    UserStatsOut,
    UserOut,
)
from app.security import create_access_token, decode_token, hash_password, verify_password
from app.support import get_or_create_support_thread, list_support_messages, post_support_message

app = FastAPI(title="Slayma Backend (MVP)")
bearer = HTTPBearer(auto_error=True)
app.include_router(routes_router)

# ----------------------------
# Statuses (string enum in DB)
# ----------------------------
STATUS_PENDING = "pending_review"
STATUS_NEEDS_FIX = "needs_fix"
STATUS_REJECTED = "rejected"
STATUS_ACTIVE = "active"
STATUS_ARCHIVED = "archived"

# ----------------------------
# Upload config
# ----------------------------
UPLOADS_DIR = Path(os.getenv("UPLOADS_DIR", "uploads"))
NSFW_REVIEW = float(os.getenv("NSFW_REVIEW", "0.30"))
NSFW_HARD_BLOCK = float(os.getenv("NSFW_HARD_BLOCK", "0.85"))

app.mount("/uploads", StaticFiles(directory=str(UPLOADS_DIR), check_dir=False), name="uploads")


@app.on_event("startup")
def ensure_tables() -> None:
    ensure_all_tables()


# ----------------------------
# Auth
# ----------------------------
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


def _extract_ws_token(websocket: WebSocket) -> Optional[str]:
    auth_header = websocket.headers.get("authorization")
    if auth_header:
        prefix = "bearer "
        if auth_header.lower().startswith(prefix):
            token = auth_header[len(prefix) :].strip()
            if token:
                return token

    query_token = websocket.query_params.get("token")
    if query_token:
        return query_token.strip() or None

    return None


def _ws_current_user(websocket: WebSocket) -> UserOut:
    token = _extract_ws_token(websocket)
    if not token:
        raise HTTPException(status_code=401, detail="Missing token")
    return _user_from_token(token)


@app.post("/auth/register", response_model=TokenOut)
def register(data: RegisterIn) -> TokenOut:
    existing = fetch_one("SELECT 1 FROM users WHERE email=%s", (data.email,))
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    user_id = str(uuid.uuid4())
    pwd_hash = hash_password(data.password)

    execute(
        "INSERT INTO users (id, email, password_hash, role) VALUES (%s,%s,%s,%s)",
        (user_id, data.email, pwd_hash, "user"),
    )
    _ensure_profile_and_stats(user_id)

    token = create_access_token({"sub": user_id, "role": "user"})
    return TokenOut(access_token=token)


@app.post("/auth/login", response_model=TokenOut)
def login(data: LoginIn) -> TokenOut:
    row = fetch_one(
        "SELECT id::text, password_hash, role FROM users WHERE email=%s",
        (data.email,),
    )
    if not row:
        raise HTTPException(status_code=401, detail="Invalid credentials")

    user_id, pwd_hash, role = row
    if not verify_password(data.password, pwd_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token({"sub": user_id, "role": role})
    return TokenOut(access_token=token)


@app.get("/me", response_model=UserOut)
def me(user: UserOut = Depends(get_current_user)) -> UserOut:
    return user


# ----------------------------
# Profile / devices
# ----------------------------
def _model_dump(model: Any) -> Dict[str, Any]:
    if hasattr(model, "model_dump"):
        return model.model_dump()
    if hasattr(model, "dict"):
        return model.dict()
    return {}


def _normalize_optional_text(value: Optional[str], collapse_spaces: bool = False) -> Optional[str]:
    if value is None:
        return None

    normalized = value.strip()
    if collapse_spaces:
        normalized = " ".join(normalized.split())

    return normalized or None


def _normalize_home_location(value: Any) -> Optional[Dict[str, float]]:
    if value is None:
        return None

    raw_value = value
    if isinstance(raw_value, str):
        try:
            raw_value = json.loads(raw_value)
        except Exception:
            return None

    if not isinstance(raw_value, dict):
        return None

    try:
        lat = float(raw_value.get("lat"))
        lon = float(raw_value.get("lon"))
    except (TypeError, ValueError):
        return None

    if not (-90 <= lat <= 90 and -180 <= lon <= 180):
        return None

    return {"lat": lat, "lon": lon}


def _point_out(value: Any) -> Optional[GeoPointOut]:
    point = _normalize_home_location(value)
    if not point:
        return None
    return GeoPointOut(**point)


def _normalize_json_object(value: Any) -> Dict[str, Any]:
    if value is None:
        return {}

    raw_value = value
    if isinstance(raw_value, str):
        try:
            raw_value = json.loads(raw_value)
        except Exception:
            return {}

    if isinstance(raw_value, dict):
        return dict(raw_value)

    return {}


def _preferred_address_from_extra(value: Any) -> Optional[str]:
    extra = _normalize_json_object(value)
    return _normalize_optional_text(extra.get("preferred_address"), collapse_spaces=True)


@lru_cache(maxsize=1)
def _profile_has_extra_column() -> bool:
    return table_has_column("user_profiles", "extra")


@lru_cache(maxsize=1)
def _profile_home_location_udt_name() -> Optional[str]:
    row = fetch_one(
        """
        SELECT udt_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'user_profiles'
          AND column_name = 'home_location'
        """,
    )
    if not row or not row[0]:
        return None
    return str(row[0]).lower()


def _profile_extra_select_sql(alias: str) -> str:
    if not _profile_has_extra_column():
        return "NULL::jsonb AS profile_extra"

    prefix = f"{alias}." if alias else ""
    return f"{prefix}extra AS profile_extra"


def _profile_home_location_select_sql(alias: str) -> str:
    prefix = f"{alias}." if alias else ""
    column_type = _profile_home_location_udt_name()

    if not column_type:
        return "NULL AS home_lat, NULL AS home_lon"

    if column_type in {"geography", "geometry"}:
        return (
            f"CASE WHEN {prefix}home_location IS NULL THEN NULL ELSE ST_Y({prefix}home_location::geometry) END AS home_lat, "
            f"CASE WHEN {prefix}home_location IS NULL THEN NULL ELSE ST_X({prefix}home_location::geometry) END AS home_lon"
        )

    if column_type in {"jsonb", "json"}:
        return (
            f"CASE WHEN {prefix}home_location IS NULL THEN NULL ELSE NULLIF({prefix}home_location->>'lat', '')::double precision END AS home_lat, "
            f"CASE WHEN {prefix}home_location IS NULL THEN NULL ELSE NULLIF({prefix}home_location->>'lon', '')::double precision END AS home_lon"
        )

    return "NULL AS home_lat, NULL AS home_lon"


def _fetch_profile_extra(user_id: str) -> Dict[str, Any]:
    if not _profile_has_extra_column():
        return {}

    row = fetch_one(
        """
        SELECT extra
        FROM user_profiles
        WHERE user_id = %s
        """,
        (user_id,),
    )
    if not row:
        return {}

    return _normalize_json_object(row[0])


def _ensure_profile_and_stats(user_id: str) -> None:
    if user_id == "dev":
        return

    execute(
        """
        INSERT INTO user_profiles (user_id, display_name, created_at, updated_at)
        SELECT
            u.id,
            COALESCE(NULLIF(BTRIM(u.phone), ''), NULLIF(BTRIM(u.email), ''), 'Пользователь'),
            now(),
            now()
        FROM users u
        WHERE u.id = %s
        ON CONFLICT (user_id) DO NOTHING
        """,
        (user_id,),
    )
    execute(
        """
        INSERT INTO user_stats (user_id, created_at, updated_at)
        VALUES (%s, now(), now())
        ON CONFLICT (user_id) DO NOTHING
        """,
        (user_id,),
    )


def _dev_me_profile() -> MeProfileOut:
    return MeProfileOut(
        user={
            "id": "dev",
            "email": "dev@localdomain.com",
            "phone": None,
            "created_at": datetime.now(timezone.utc),
        },
        profile={
            "display_name": "Dev User",
            "bio": None,
            "city": None,
            "preferred_address": None,
            "home_location": None,
        },
        stats={
            "rating_avg": 0.0,
            "rating_count": 0,
            "completed_count": 0,
            "cancelled_count": 0,
        },
    )


def _fetch_me_profile(user_id: str) -> MeProfileOut:
    if user_id == "dev":
        return _dev_me_profile()

    _ensure_profile_and_stats(user_id)

    row = fetch_one(
        f"""
        SELECT
            u.id::text,
            u.email,
            u.phone,
            u.created_at,
            up.display_name,
            up.bio,
            up.city,
            {_profile_extra_select_sql("up")},
            {_profile_home_location_select_sql("up")},
            COALESCE(us.rating_avg, 0),
            COALESCE(us.rating_count, 0),
            COALESCE(us.completed_count, 0),
            COALESCE(us.cancelled_count, 0)
        FROM users u
        LEFT JOIN user_profiles up ON up.user_id = u.id
        LEFT JOIN user_stats us ON us.user_id = u.id
        WHERE u.id = %s
        """,
        (user_id,),
    )
    if not row:
        raise HTTPException(status_code=404, detail="User not found")

    return MeProfileOut(
        user={
            "id": row[0],
            "email": row[1],
            "phone": row[2],
            "created_at": row[3],
        },
        profile={
            "display_name": _normalize_optional_text(row[4], collapse_spaces=True),
            "bio": _normalize_optional_text(row[5]),
            "city": _normalize_optional_text(row[6], collapse_spaces=True),
            "preferred_address": _preferred_address_from_extra(row[7]),
            "home_location": _point_out({"lat": row[8], "lon": row[9]}) if row[8] is not None and row[9] is not None else None,
        },
        stats=UserStatsOut(
            rating_avg=float(row[10] or 0),
            rating_count=int(row[11] or 0),
            completed_count=int(row[12] or 0),
            cancelled_count=int(row[13] or 0),
        ),
    )


def _fetch_profile_section(user_id: str) -> UserProfileOut:
    if user_id == "dev":
        return UserProfileOut(display_name="Dev User", preferred_address=None)

    _ensure_profile_and_stats(user_id)

    row = fetch_one(
        f"""
        SELECT
            display_name,
            bio,
            city,
            {_profile_extra_select_sql("")},
            {_profile_home_location_select_sql("")}
        FROM user_profiles
        WHERE user_id = %s
        """,
        (user_id,),
    )

    if not row:
        return UserProfileOut()

    return UserProfileOut(
        display_name=_normalize_optional_text(row[0], collapse_spaces=True),
        bio=_normalize_optional_text(row[1]),
        city=_normalize_optional_text(row[2], collapse_spaces=True),
        preferred_address=_preferred_address_from_extra(row[3]),
        home_location=_point_out({"lat": row[4], "lon": row[5]}) if row[4] is not None and row[5] is not None else None,
    )


@app.get("/users/me", response_model=MeProfileOut)
def users_me(user: UserOut = Depends(get_current_user)) -> MeProfileOut:
    return _fetch_me_profile(user.id)


@app.patch("/users/me/profile", response_model=UserProfileOut)
def update_my_profile(
    payload: UpdateMyProfileIn,
    user: UserOut = Depends(get_current_user),
) -> UserProfileOut:
    display_name = _normalize_optional_text(payload.display_name, collapse_spaces=True)
    bio = _normalize_optional_text(payload.bio)
    city = _normalize_optional_text(payload.city, collapse_spaces=True)
    preferred_address = _normalize_optional_text(payload.preferred_address, collapse_spaces=True)
    if not display_name or len(display_name) < 2:
        raise HTTPException(status_code=422, detail="Display name must contain at least 2 characters")

    if user.id == "dev":
        return UserProfileOut(
            display_name=display_name,
            bio=bio,
            city=city,
            preferred_address=preferred_address,
            home_location=payload.home_location,
        )

    _ensure_profile_and_stats(user.id)

    current_profile = _fetch_profile_section(user.id)

    resolved_home_location = payload.home_location
    if resolved_home_location is None:
        if preferred_address:
            geocoded = geocode_address(preferred_address)
            if geocoded:
                resolved_home_location = GeoPointOut(lat=geocoded[0], lon=geocoded[1])
            else:
                resolved_home_location = current_profile.home_location
        else:
            resolved_home_location = None

    set_clauses = [
        "display_name = %s",
        "bio = %s",
        "city = %s",
    ]
    params: List[Any] = [display_name, bio, city]

    if _profile_has_extra_column():
        extra_payload = _fetch_profile_extra(user.id)
        if preferred_address:
            extra_payload["preferred_address"] = preferred_address
        else:
            extra_payload.pop("preferred_address", None)

        set_clauses.append("extra = %s::jsonb")
        params.append(json.dumps(extra_payload, ensure_ascii=False) if extra_payload else None)

    home_location_type = _profile_home_location_udt_name()
    if home_location_type in {"geography", "geometry"}:
        if resolved_home_location is not None:
            geometry_expression = "ST_SetSRID(ST_MakePoint(%s::double precision, %s::double precision), 4326)"
            if home_location_type == "geography":
                geometry_expression = f"{geometry_expression}::geography"

            set_clauses.append(f"home_location = {geometry_expression}")
            params.extend([resolved_home_location.lon, resolved_home_location.lat])
        else:
            set_clauses.append("home_location = NULL")
    elif home_location_type in {"jsonb", "json"}:
        if resolved_home_location is not None:
            set_clauses.append("home_location = %s::jsonb")
            params.append(
                json.dumps(
                    {"lat": resolved_home_location.lat, "lon": resolved_home_location.lon},
                    ensure_ascii=False,
                )
            )
        else:
            set_clauses.append("home_location = NULL")

    set_clauses.append("updated_at = now()")
    params.append(user.id)

    execute(
        f"""
        UPDATE user_profiles
        SET {", ".join(set_clauses)}
        WHERE user_id = %s
        """,
        tuple(params),
    )

    return _fetch_profile_section(user.id)


@app.get("/users/me/reviews", response_model=UserReviewListOut)
def my_reviews(
    limit: int = 2,
    offset: int = 0,
    user: UserOut = Depends(get_current_user),
) -> UserReviewListOut:
    if user.id == "dev":
        return UserReviewListOut(items=[])

    lim = max(1, min(int(limit), 100))
    off = max(0, int(offset))

    rows = fetch_all(
        """
        SELECT
            COALESCE(NULLIF(up.display_name, ''), u.email, 'Пользователь') AS from_user_display_name,
            r.stars,
            r.text,
            r.created_at
        FROM reviews r
        LEFT JOIN user_profiles up ON up.user_id = r.from_user_id
        LEFT JOIN users u ON u.id = r.from_user_id
        WHERE r.to_user_id = %s
        ORDER BY r.created_at DESC
        LIMIT %s OFFSET %s
        """,
        (user.id, lim, off),
    )

    return UserReviewListOut(
        items=[
            UserReviewOut(
                from_user_display_name=row[0],
                stars=int(row[1]),
                text=row[2],
                created_at=row[3],
            )
            for row in rows
        ]
    )


@app.post("/devices/register", response_model=OKOut)
def register_device(
    payload: DeviceRegisterIn,
    user: UserOut = Depends(get_current_user),
) -> OKOut:
    if user.id == "dev":
        return OKOut(ok=True)

    device_id = _normalize_optional_text(payload.device_id)
    if not device_id:
        raise HTTPException(status_code=422, detail="device_id is required")

    existing = fetch_one(
        """
        SELECT id
        FROM user_devices
        WHERE device_id = %s
        ORDER BY created_at DESC
        LIMIT 1
        """,
        (device_id,),
    )

    if existing:
        execute(
            """
            UPDATE user_devices
            SET user_id = %s,
                platform = %s,
                push_token = %s,
                locale = %s,
                timezone = %s,
                device_name = %s,
                last_seen_at = now(),
                deleted_at = NULL
            WHERE id = %s
            """,
            (
                user.id,
                payload.platform,
                payload.push_token,
                payload.locale,
                payload.timezone,
                payload.device_name,
                existing[0],
            ),
        )
    else:
        execute(
            """
            INSERT INTO user_devices (
                id, user_id, platform, device_id, push_token, locale, timezone, device_name, created_at, last_seen_at, deleted_at
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, now(), now(), NULL)
            """,
            (
                str(uuid.uuid4()),
                user.id,
                payload.platform,
                device_id,
                payload.push_token,
                payload.locale,
                payload.timezone,
                payload.device_name,
            ),
        )
    return OKOut(ok=True)


@app.delete("/devices/me", response_model=OKOut)
def unregister_device(
    payload: DeviceUnregisterIn,
    user: UserOut = Depends(get_current_user),
) -> OKOut:
    if user.id == "dev":
        return OKOut(ok=True)

    device_id = _normalize_optional_text(payload.device_id)
    if not device_id:
        raise HTTPException(status_code=422, detail="device_id is required")

    execute(
        """
        UPDATE user_devices
        SET deleted_at = now(),
            last_seen_at = now(),
            push_token = NULL
        WHERE user_id = %s
          AND deleted_at IS NULL
          AND (
              device_id = %s
              OR (%s IS NOT NULL AND push_token = %s)
          )
        """,
        (user.id, device_id, payload.push_token, payload.push_token),
    )
    return OKOut(ok=True)


# ----------------------------
# Helpers (announcements / moderation)
# ----------------------------
def _row_to_announcement(row) -> AnnouncementOut:
    raw_data = row[5]
    if raw_data is None:
        data_obj: Dict[str, Any] = {}
    elif isinstance(raw_data, str):
        try:
            data_obj = json.loads(raw_data)
        except Exception:
            data_obj = {}
    else:
        data_obj = raw_data

    return AnnouncementOut(
        id=row[0],
        user_id=row[1],
        category=row[2],
        title=row[3],
        status=row[4],
        data=data_obj,
        created_at=row[6],
    )


def _row_to_report(row) -> ReportOut:
    return ReportOut(
        id=row[0],
        reporter_id=row[1],
        target_type=row[2],
        target_id=row[3],
        reason_code=row[4],
        reason_text=row[5],
        status=row[6],
        resolution=row[7],
        resolved_by=row[8],
        moderator_comment=row[9],
        created_at=row[10],
        resolved_at=row[11],
    )


def _ensure_obj(x: Any) -> Dict[str, Any]:
    return x if isinstance(x, dict) else {}


def _ensure_list(x: Any) -> List[Any]:
    return x if isinstance(x, list) else []


def _get_mod(data: Dict[str, Any]) -> Dict[str, Any]:
    return _ensure_obj(data.get("moderation"))


def _set_mod(data: Dict[str, Any], mod: Dict[str, Any]) -> None:
    data["moderation"] = mod


def _set_decision(mod: Dict[str, Any], status: str, message: str) -> None:
    mod["decision"] = {"status": status, "message": message}


def _remove_reasons_for_field(mod: Dict[str, Any], field: str) -> None:
    reasons = _ensure_list(mod.get("reasons"))
    mod["reasons"] = [r for r in reasons if not (isinstance(r, dict) and r.get("field") == field)]


def _add_reason(mod: Dict[str, Any], field: str, code: str, details: str, can_appeal: bool) -> None:
    reasons = _ensure_list(mod.get("reasons"))
    reasons.append(
        {
            "field": field,
            "code": code,
            "details": details,
            "can_appeal": bool(can_appeal),
        }
    )
    mod["reasons"] = reasons


def _set_suggestions(mod: Dict[str, Any], suggestions: List[str]) -> None:
    mod["suggestions"] = [s for s in suggestions if isinstance(s, str) and s.strip()]


def _is_manual_review_required(mod: Dict[str, Any], section: str) -> bool:
    section_obj = _ensure_obj(mod.get(section))
    return section_obj.get("manual_review_required") is True


def _status_priority(s: str) -> int:
    return {
        STATUS_ACTIVE: 0,
        STATUS_PENDING: 1,
        STATUS_NEEDS_FIX: 2,
        STATUS_REJECTED: 3,
        STATUS_ARCHIVED: 4,
        "draft": 1,
    }.get(s or "", 1)


def _keep_stricter(current: str, candidate: str) -> str:
    return current if _status_priority(current) >= _status_priority(candidate) else candidate


def _normalize_address(value: Any) -> Optional[str]:
    if not isinstance(value, str):
        return None
    normalized = " ".join(value.strip().split())
    return normalized or None


def _normalize_message(value: Any) -> Optional[str]:
    if not isinstance(value, str):
        return None
    normalized = " ".join(value.strip().split())
    return normalized or None


def _parse_float(value: Any) -> Optional[float]:
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        raw = value.strip().replace(",", ".")
        if not raw:
            return None
        try:
            return float(raw)
        except ValueError:
            return None
    return None


def _extract_point(value: Any) -> Optional[Tuple[float, float]]:
    if not isinstance(value, dict):
        return None
    lat = _parse_float(value.get("lat"))
    lon = _parse_float(value.get("lon"))
    if lat is None or lon is None:
        return None
    if not (-90 <= lat <= 90 and -180 <= lon <= 180):
        return None
    return lat, lon


def _point_obj(point: Tuple[float, float]) -> Dict[str, float]:
    return {"lat": point[0], "lon": point[1]}


def _normalize_budget_fields(data: Dict[str, Any]) -> None:
    for key in ("budget", "budget_min", "budget_max"):
        if key not in data:
            continue

        parsed = _parse_float(data.get(key))
        if parsed is None:
            if data.get(key) in ("", None):
                data[key] = None
            continue

        data[key] = int(parsed)


def _extract_primary_address(category: str, data: Dict[str, Any]) -> Optional[str]:
    cat = (category or "").strip().lower()
    if cat == "delivery":
        return _normalize_address(data.get("pickup_address"))
    if cat == "help":
        return _normalize_address(data.get("address"))
    return _normalize_address(data.get("address"))


def _resolve_point(
    data: Dict[str, Any],
    preferred_key: str,
    fallback_key: Optional[str],
    address: Optional[str],
) -> Optional[Tuple[float, float]]:
    point = _extract_point(data.get(preferred_key))
    if point:
        return point

    if fallback_key:
        point = _extract_point(data.get(fallback_key))
        if point:
            return point

    if address:
        return geocode_address(address)

    return None


def _announcement_point_for_storage(category: str, data: Dict[str, Any]) -> Optional[Tuple[float, float]]:
    normalized_category = (category or "").strip().lower()
    if normalized_category == "delivery":
        return _extract_point(data.get("pickup_point")) or _extract_point(data.get("point"))
    if normalized_category == "help":
        return _extract_point(data.get("help_point")) or _extract_point(data.get("point"))
    return _extract_point(data.get("point"))


def _save_upload(ann_id: str, file: UploadFile, content: bytes) -> str:
    safe_name = (file.filename or "image").replace("/", "_").replace("\\", "_")
    folder = UPLOADS_DIR / ann_id
    folder.mkdir(parents=True, exist_ok=True)
    out = folder / f"{uuid.uuid4().hex}_{safe_name}"
    out.write_bytes(content)
    return "/" + out.as_posix().lstrip("/")


def _utc_iso_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _fetch_announcement_or_404(ann_id: str) -> AnnouncementOut:
    row = fetch_one(
        """
        SELECT id, user_id, category, title, status, data, created_at
        FROM announcements
        WHERE id = %s
          AND deleted_at IS NULL
        """,
        (ann_id,),
    )
    if not row:
        raise HTTPException(status_code=404, detail="Announcement not found")
    return _row_to_announcement(row)


def _count_pending_offers(ann_id: str) -> int:
    row = fetch_one(
        """
        SELECT COUNT(*)
        FROM announcement_offers
        WHERE announcement_id = %s
          AND status IN ('pending', 'accepted')
          AND deleted_at IS NULL
        """,
        (ann_id,),
    )
    return int(row[0] or 0) if row else 0


def _sync_announcement_offers_count(ann_id: str) -> int:
    row = fetch_one(
        """
        SELECT data
        FROM announcements
        WHERE id = %s
        """,
        (ann_id,),
    )
    if not row:
        return 0

    raw_data = row[0]
    if raw_data is None:
        data_obj: Dict[str, Any] = {}
    elif isinstance(raw_data, str):
        try:
            data_obj = json.loads(raw_data)
        except Exception:
            data_obj = {}
    else:
        data_obj = dict(raw_data)

    offers_count = _count_pending_offers(ann_id)
    data_obj["offers_count"] = offers_count

    execute(
        """
        UPDATE announcements
        SET data = %s::jsonb,
            updated_at = now()
        WHERE id = %s
        """,
        (json.dumps(data_obj, ensure_ascii=False), ann_id),
    )
    return offers_count


def _offer_avatar_select_sql() -> str:
    if _profile_has_extra_column():
        return "up.extra->>'avatar_url' AS avatar_url"
    return "NULL AS avatar_url"


def _offer_from_row(row) -> OfferOut:
    return OfferOut(
        id=row[0],
        announcement_id=row[1],
        performer_id=row[2],
        message=_normalize_message(row[3]),
        proposed_price=int(row[4]) if row[4] is not None else None,
        status=row[5],
        created_at=row[6],
    )


def _offer_expanded_from_row(row) -> OfferOutExpanded:
    offer = _offer_from_row(row)
    return OfferOutExpanded(
        id=offer.id,
        announcement_id=offer.announcement_id,
        performer_id=offer.performer_id,
        message=offer.message,
        proposed_price=offer.proposed_price,
        status=offer.status,
        created_at=offer.created_at,
        performer_profile={
            "user_id": row[7],
            "display_name": row[8],
            "city": _normalize_optional_text(row[9], collapse_spaces=True),
            "contact": _normalize_optional_text(row[10], collapse_spaces=True),
            "avatar_url": row[11],
        },
        performer_stats={
            "rating_avg": float(row[12] or 0),
            "rating_count": int(row[13] or 0),
            "completed_count": int(row[14] or 0),
            "cancelled_count": int(row[15] or 0),
        },
    )


def _fetch_expanded_offer(ann_id: str, offer_id: str) -> Optional[OfferOutExpanded]:
    row = fetch_one(
        f"""
        SELECT
            ao.id,
            ao.announcement_id,
            ao.performer_id,
            ao.message,
            ao.proposed_price,
            ao.status,
            ao.created_at,
            ao.performer_id::text,
            COALESCE(
                NULLIF(BTRIM(up.display_name), ''),
                NULLIF(BTRIM(u.phone), ''),
                NULLIF(BTRIM(u.email), ''),
                'Пользователь'
            ) AS performer_display_name,
            up.city,
            COALESCE(
                NULLIF(BTRIM(u.phone), ''),
                NULLIF(BTRIM(u.email), '')
            ) AS performer_contact,
            {_offer_avatar_select_sql()},
            COALESCE(us.rating_avg, 0),
            COALESCE(us.rating_count, 0),
            COALESCE(us.completed_count, 0),
            COALESCE(us.cancelled_count, 0)
        FROM announcement_offers ao
        JOIN users u
          ON u.id::text = ao.performer_id::text
        LEFT JOIN user_profiles up
          ON up.user_id::text = ao.performer_id::text
        LEFT JOIN user_stats us
          ON us.user_id::text = ao.performer_id::text
        WHERE ao.announcement_id = %s
          AND ao.id = %s
          AND ao.deleted_at IS NULL
        """,
        (ann_id, offer_id),
    )
    if not row:
        return None
    return _offer_expanded_from_row(row)


# ----------------------------
# Announcements (Create)
# ----------------------------
@app.post("/announcements", response_model=AnnouncementOut, status_code=201)
def create_announcement(
    payload: CreateAnnouncementIn,
    user: UserOut = Depends(get_current_user),
) -> AnnouncementOut:
    ann_id = str(uuid.uuid4())

    data: Dict[str, Any] = dict(payload.data or {})
    category = (payload.category or "").strip().lower()
    _normalize_budget_fields(data)
    data["offers_count"] = int(_parse_float(data.get("offers_count")) or 0)

    if category == "delivery":
        pickup_address = _normalize_address(data.get("pickup_address"))
        dropoff_address = _normalize_address(data.get("dropoff_address"))
        if pickup_address:
            data["pickup_address"] = pickup_address
        if dropoff_address:
            data["dropoff_address"] = dropoff_address

        pickup_point = _resolve_point(
            data=data,
            preferred_key="pickup_point",
            fallback_key="point",
            address=pickup_address,
        )
        dropoff_point = _resolve_point(
            data=data,
            preferred_key="dropoff_point",
            fallback_key=None,
            address=dropoff_address,
        )

        if pickup_point:
            data["pickup_point"] = _point_obj(pickup_point)
            data["point"] = _point_obj(pickup_point)
        if pickup_address:
            data["address_text"] = pickup_address
        if dropoff_point:
            data["dropoff_point"] = _point_obj(dropoff_point)

    elif category == "help":
        help_address = _normalize_address(data.get("address"))
        destination_address = _normalize_address(
            data.get("destination_address")
            or data.get("to_address")
            or data.get("end_address")
        )
        if help_address:
            data["address"] = help_address
        if destination_address:
            data["destination_address"] = destination_address

        help_point = _resolve_point(
            data=data,
            preferred_key="help_point",
            fallback_key="point",
            address=help_address,
        )
        destination_point = _resolve_point(
            data=data,
            preferred_key="destination_point",
            fallback_key="to_point",
            address=destination_address,
        )

        if help_point:
            data["help_point"] = _point_obj(help_point)
            data["point"] = _point_obj(help_point)
        if help_address:
            data["address_text"] = help_address
        if destination_point:
            data["destination_point"] = _point_obj(destination_point)

    else:
        addr = _extract_primary_address(payload.category, data)
        point = _resolve_point(data=data, preferred_key="point", fallback_key=None, address=addr)
        if point:
            data["point"] = _point_obj(point)
        if addr:
            data["address_text"] = addr

    mod = _get_mod(data)

    title = (payload.title or "").strip()
    notes = data.get("notes")

    parts = [title]
    if isinstance(notes, str) and notes.strip():
        parts.append(notes.strip())

    text_for_check = "\n\n".join([p for p in parts if p])

    text_mod = classify_text(text_for_check) if text_for_check else {"label": "LEGAL", "reason": ""}
    label = str(text_mod.get("label", "UNKNOWN")).upper()
    reason = str(text_mod.get("reason", "")).strip()

    _remove_reasons_for_field(mod, "title")
    _remove_reasons_for_field(mod, "notes")

    status = STATUS_PENDING
    suggestions: List[str] = []

    mod["text"] = {
        "label": label,
        "reason": reason,
        "can_appeal": True if label in ("ILLEGAL", "UNKNOWN") else False,
        "manual_review_required": False,
    }

    if label == "ILLEGAL":
        status = STATUS_REJECTED
        _set_decision(mod, status, "Отказано: текст похож на запрещённый контент. Измените формулировку.")
        _add_reason(mod, "title", "TEXT_ILLEGAL", reason or "Запрещённый текст", True)
        if isinstance(notes, str) and notes.strip():
            _add_reason(mod, "notes", "TEXT_ILLEGAL", reason or "Запрещённый текст", True)
        suggestions = [
            "Переформулируйте название и описание.",
            "Уберите неоднозначные или запрещённые формулировки.",
        ]
    elif label == "UNKNOWN":
        status = STATUS_PENDING
        mod["text"]["manual_review_required"] = True
        _set_decision(
            mod,
            status,
            "Автоматическая проверка текста временно недоступна. Объявление отправлено на дополнительную проверку.",
        )
    else:
        status = STATUS_PENDING
        _set_decision(mod, status, "На проверке: сначала проверим фото, затем объявление появится на карте.")

    mod["image"] = {
        "max_nsfw": None,
        "items": [],
        "can_appeal": None,
        "manual_review_required": False,
        "review_thr": NSFW_REVIEW,
        "hard_block_thr": NSFW_HARD_BLOCK,
    }

    if suggestions:
        _set_suggestions(mod, suggestions)

    _set_mod(data, mod)

    location_point = _announcement_point_for_storage(payload.category, data)
    location_lon = location_point[1] if location_point else None
    location_lat = location_point[0] if location_point else None

    execute(
        """
        INSERT INTO announcements (id, user_id, category, title, status, data, location_point)
        VALUES (
            %s,
            %s,
            %s,
            %s,
            %s,
            %s::jsonb,
            CASE
                WHEN %s IS NULL OR %s IS NULL THEN NULL
                ELSE ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography
            END
        )
        """,
        (
            ann_id,
            user.id,
            payload.category,
            title,
            status,
            json.dumps(data, ensure_ascii=False),
            location_lon,
            location_lat,
            location_lon,
            location_lat,
        ),
    )

    row = fetch_one(
        """
        SELECT id, user_id, category, title, status, data, created_at
        FROM announcements
        WHERE id = %s
        """,
        (ann_id,),
    )
    if not row:
        raise HTTPException(status_code=500, detail="Failed to create announcement")

    return _row_to_announcement(row)


# ----------------------------
# Announcements (Media)
# ----------------------------
@app.post("/announcements/{ann_id}/media", response_model=AnnouncementOut)
def upload_announcement_media(
    ann_id: str,
    files: List[UploadFile] = File(...),
    user: UserOut = Depends(get_current_user),
) -> AnnouncementOut:
    row = fetch_one(
        """
        SELECT id, user_id, category, title, status, data, created_at
        FROM announcements
        WHERE id=%s AND deleted_at IS NULL
        """,
        (ann_id,),
    )
    if not row:
        raise HTTPException(status_code=404, detail="Announcement not found")

    ann = _row_to_announcement(row)
    if ann.user_id != user.id:
        raise HTTPException(status_code=403, detail="Not your announcement")

    data_obj: Dict[str, Any] = dict(ann.data or {})
    mod = _get_mod(data_obj)

    detector_error: str | None = None
    try:
        det = get_nsfw_detector()
    except Exception as exc:
        det = None
        detector_error = str(exc)

    items: List[Dict[str, Any]] = []
    max_nsfw = 0.0

    for f in files:
        content = f.file.read()
        if not content:
            continue

        path = _save_upload(ann_id, f, content)
        if det is None:
            items.append(
                {
                    "filename": f.filename,
                    "path": path,
                    "nsfw": None,
                    "sfw": None,
                    "top_label": "manual_review",
                    "top_prob": None,
                    "infer_s": None,
                    "service_error": detector_error,
                }
            )
            continue

        try:
            r = det.predict_bytes(content)
            max_nsfw = max(max_nsfw, float(r.nsfw))
            items.append(
                {
                    "filename": f.filename,
                    "path": path,
                    "nsfw": float(r.nsfw),
                    "sfw": float(r.sfw),
                    "top_label": r.top_label,
                    "top_prob": float(r.top_prob),
                    "infer_s": float(r.infer_seconds),
                }
            )
        except Exception as exc:
            detector_error = str(exc)
            det = None
            items.append(
                {
                    "filename": f.filename,
                    "path": path,
                    "nsfw": None,
                    "sfw": None,
                    "top_label": "manual_review",
                    "top_prob": None,
                    "infer_s": None,
                    "service_error": detector_error,
                }
            )

    data_obj["media"] = items
    _remove_reasons_for_field(mod, "media")

    current_status = ann.status or STATUS_PENDING
    new_status = current_status

    if detector_error:
        new_status = _keep_stricter(current_status, STATUS_PENDING)
        _set_decision(
            mod,
            new_status,
            "Автоматическая проверка фото временно недоступна. Объявление отправлено на дополнительную проверку.",
        )
        mod["image"] = {
            "max_nsfw": None,
            "items": items,
            "can_appeal": None,
            "manual_review_required": True,
            "service_error": detector_error,
            "review_thr": NSFW_REVIEW,
            "hard_block_thr": NSFW_HARD_BLOCK,
        }
    elif max_nsfw >= NSFW_HARD_BLOCK:
        new_status = _keep_stricter(current_status, STATUS_REJECTED)
        _add_reason(mod, "media", "NSFW_HARD", f"NSFW {max_nsfw:.2f} ≥ {NSFW_HARD_BLOCK:.2f}", False)
        _set_decision(mod, new_status, "Отказано: фото содержит запрещённый/неприемлемый контент.")
        mod["penalty_stub"] = {"type": "warning", "points": 1, "applied_at": None}
        mod["image"] = {
            "max_nsfw": max_nsfw,
            "items": items,
            "can_appeal": False,
            "manual_review_required": False,
            "review_thr": NSFW_REVIEW,
            "hard_block_thr": NSFW_HARD_BLOCK,
        }
    elif max_nsfw >= NSFW_REVIEW:
        new_status = _keep_stricter(current_status, STATUS_NEEDS_FIX)
        _add_reason(mod, "media", "NSFW_REVIEW", f"NSFW {max_nsfw:.2f}", True)
        _set_decision(mod, new_status, "Нужно исправить: фото выглядит спорным. Замените фото и отправьте заново.")
        mod["image"] = {
            "max_nsfw": max_nsfw,
            "items": items,
            "can_appeal": True,
            "manual_review_required": False,
            "review_thr": NSFW_REVIEW,
            "hard_block_thr": NSFW_HARD_BLOCK,
        }
    else:
        if _is_manual_review_required(mod, "text"):
            new_status = _keep_stricter(current_status, STATUS_PENDING)
            _set_decision(
                mod,
                new_status,
                "Фото загружены. Объявление ждёт дополнительной проверки текста.",
            )
        elif _status_priority(current_status) <= _status_priority(STATUS_PENDING):
            new_status = STATUS_ACTIVE
            _set_decision(mod, new_status, "Одобрено: объявление активно и отображается на карте.")
        else:
            new_status = current_status
        mod["image"] = {
            "max_nsfw": max_nsfw,
            "items": items,
            "can_appeal": None,
            "manual_review_required": False,
            "review_thr": NSFW_REVIEW,
            "hard_block_thr": NSFW_HARD_BLOCK,
        }

    _set_mod(data_obj, mod)

    execute(
        "UPDATE announcements SET status=%s, data=%s::jsonb, updated_at=now() WHERE id=%s",
        (new_status, json.dumps(data_obj, ensure_ascii=False), ann_id),
    )

    updated = fetch_one(
        "SELECT id, user_id, category, title, status, data, created_at FROM announcements WHERE id=%s",
        (ann_id,),
    )
    return _row_to_announcement(updated)


# ----------------------------
# Announcements (Appeal / Archive / Delete)
# ----------------------------
@app.post("/announcements/{ann_id}/appeal", response_model=AnnouncementOut)
def appeal_announcement(
    ann_id: str,
    payload: AppealIn,
    user: UserOut = Depends(get_current_user),
) -> AnnouncementOut:
    row = fetch_one(
        """
        SELECT id, user_id, category, title, status, data, created_at
        FROM announcements
        WHERE id = %s AND deleted_at IS NULL
        """,
        (ann_id,),
    )
    if not row:
        raise HTTPException(status_code=404, detail="Announcement not found")

    ann = _row_to_announcement(row)
    if ann.user_id != user.id:
        raise HTTPException(status_code=403, detail="Not your announcement")

    data_obj: Dict[str, Any] = dict(ann.data or {})
    mod = _get_mod(data_obj)
    appeal = _ensure_obj(mod.get("appeal"))
    appeal["requested"] = True
    appeal["reason"] = (payload.reason or "").strip() or None
    appeal["requested_at"] = _utc_iso_now()
    appeal["resolved_at"] = None
    mod["appeal"] = appeal

    _set_decision(mod, STATUS_PENDING, "Апелляция принята и отправлена на повторную проверку.")
    _set_mod(data_obj, mod)

    execute(
        """
        UPDATE announcements
        SET status = %s,
            data = %s::jsonb,
            updated_at = now()
        WHERE id = %s
        """,
        (STATUS_PENDING, json.dumps(data_obj, ensure_ascii=False), ann_id),
    )
    ensure_appeal_report(user.id, ann_id, payload.reason)

    updated = fetch_one(
        "SELECT id, user_id, category, title, status, data, created_at FROM announcements WHERE id = %s",
        (ann_id,),
    )
    return _row_to_announcement(updated)


@app.patch("/announcements/{ann_id}/archive", response_model=AnnouncementOut)
def archive_announcement(
    ann_id: str,
    user: UserOut = Depends(get_current_user),
) -> AnnouncementOut:
    row = fetch_one(
        """
        SELECT id, user_id, category, title, status, data, created_at
        FROM announcements
        WHERE id=%s AND deleted_at IS NULL
        """,
        (ann_id,),
    )
    if not row:
        raise HTTPException(status_code=404, detail="Announcement not found")

    ann = _row_to_announcement(row)
    if ann.user_id != user.id:
        raise HTTPException(status_code=403, detail="Not your announcement")

    execute("UPDATE announcements SET status=%s, updated_at=now() WHERE id=%s", (STATUS_ARCHIVED, ann_id))

    updated = fetch_one(
        "SELECT id, user_id, category, title, status, data, created_at FROM announcements WHERE id=%s",
        (ann_id,),
    )
    return _row_to_announcement(updated)


@app.delete("/announcements/{ann_id}")
def delete_announcement(
    ann_id: str,
    user: UserOut = Depends(get_current_user),
) -> Dict[str, bool]:
    row = fetch_one(
        "SELECT id, user_id FROM announcements WHERE id=%s AND deleted_at IS NULL",
        (ann_id,),
    )
    if not row:
        return {"ok": True}

    if row[1] != user.id:
        raise HTTPException(status_code=403, detail="Not your announcement")

    execute("UPDATE announcements SET deleted_at=now(), updated_at=now() WHERE id=%s", (ann_id,))
    return {"ok": True}


# ----------------------------
# Offers
# ----------------------------
@app.post("/announcements/{ann_id}/offers", response_model=OfferOut, status_code=201)
def create_offer(
    ann_id: str,
    payload: CreateOfferIn,
    user: UserOut = Depends(get_current_user),
) -> OfferOut:
    ann = _fetch_announcement_or_404(ann_id)

    if ann.user_id == user.id:
        raise HTTPException(status_code=403, detail="Нельзя откликаться на своё объявление")

    if ann.status != STATUS_ACTIVE:
        raise HTTPException(status_code=400, detail="Отклики доступны только для активных объявлений")

    accepted_offer = fetch_one(
        """
        SELECT id
        FROM announcement_offers
        WHERE announcement_id = %s
          AND status = 'accepted'
          AND deleted_at IS NULL
        LIMIT 1
        """,
        (ann_id,),
    )
    if accepted_offer:
        raise HTTPException(status_code=409, detail="По объявлению уже выбран исполнитель")

    message = _normalize_message(payload.message)
    proposed_price = payload.proposed_price

    existing = fetch_one(
        """
        SELECT id
        FROM announcement_offers
        WHERE announcement_id = %s
          AND performer_id = %s
          AND status = 'pending'
          AND deleted_at IS NULL
        ORDER BY created_at DESC
        LIMIT 1
        """,
        (ann_id, user.id),
    )

    if existing:
        offer_id = existing[0]
        execute(
            """
            UPDATE announcement_offers
            SET message = %s,
                proposed_price = %s,
                deleted_at = NULL
            WHERE id = %s
            """,
            (message, proposed_price, offer_id),
        )
    else:
        offer_id = str(uuid.uuid4())
        execute(
            """
            INSERT INTO announcement_offers (
                id, announcement_id, performer_id, message, proposed_price, status, created_at, deleted_at
            )
            VALUES (%s, %s, %s, %s, %s, 'pending', now(), NULL)
            """,
            (offer_id, ann_id, user.id, message, proposed_price),
        )

    _sync_announcement_offers_count(ann_id)
    create_notification(
        user_id=ann.user_id,
        notif_type="offer",
        body="Новый отклик на ваше объявление",
        payload={"announcement_id": ann_id, "offer_id": offer_id},
    )

    row = fetch_one(
        """
        SELECT id, announcement_id, performer_id, message, proposed_price, status, created_at
        FROM announcement_offers
        WHERE id = %s
        """,
        (offer_id,),
    )
    if not row:
        raise HTTPException(status_code=500, detail="Failed to create offer")

    return _offer_from_row(row)


@app.get("/announcements/{ann_id}/offers", response_model=List[OfferOutExpanded])
def list_announcement_offers(
    ann_id: str,
    user: UserOut = Depends(get_current_user),
) -> List[OfferOutExpanded]:
    ann = _fetch_announcement_or_404(ann_id)
    if ann.user_id != user.id:
        raise HTTPException(status_code=403, detail="Not your announcement")

    rows = fetch_all(
        f"""
        SELECT
            ao.id,
            ao.announcement_id,
            ao.performer_id,
            ao.message,
            ao.proposed_price,
            ao.status,
            ao.created_at,
            ao.performer_id::text,
            COALESCE(
                NULLIF(BTRIM(up.display_name), ''),
                NULLIF(BTRIM(u.phone), ''),
                NULLIF(BTRIM(u.email), ''),
                'Пользователь'
            ) AS performer_display_name,
            up.city,
            COALESCE(
                NULLIF(BTRIM(u.phone), ''),
                NULLIF(BTRIM(u.email), '')
            ) AS performer_contact,
            {_offer_avatar_select_sql()},
            COALESCE(us.rating_avg, 0),
            COALESCE(us.rating_count, 0),
            COALESCE(us.completed_count, 0),
            COALESCE(us.cancelled_count, 0)
        FROM announcement_offers ao
        JOIN users u
          ON u.id::text = ao.performer_id::text
        LEFT JOIN user_profiles up
          ON up.user_id::text = ao.performer_id::text
        LEFT JOIN user_stats us
          ON us.user_id::text = ao.performer_id::text
        WHERE ao.announcement_id = %s
          AND ao.status IN ('pending', 'accepted')
          AND ao.deleted_at IS NULL
        ORDER BY CASE WHEN ao.status = 'accepted' THEN 0 ELSE 1 END,
                 ao.created_at DESC
        """,
        (ann_id,),
    )

    return [_offer_expanded_from_row(row) for row in rows]


@app.post("/announcements/{ann_id}/offers/{offer_id}/accept", response_model=AcceptOfferOut)
def accept_announcement_offer(
    ann_id: str,
    offer_id: str,
    user: UserOut = Depends(get_current_user),
) -> AcceptOfferOut:
    ann = _fetch_announcement_or_404(ann_id)
    if ann.user_id != user.id:
        raise HTTPException(status_code=403, detail="Not your announcement")

    row = fetch_one(
        """
        SELECT performer_id, status
        FROM announcement_offers
        WHERE id = %s
          AND announcement_id = %s
          AND deleted_at IS NULL
        """,
        (offer_id, ann_id),
    )
    if not row:
        raise HTTPException(status_code=404, detail="Offer not found")

    performer_id, status = row
    if status == "rejected":
        raise HTTPException(status_code=409, detail="Отклик уже отклонён")

    did_accept_now = False
    thread_id = get_or_create_offer_thread(
        offer_id=offer_id,
        owner_id=ann.user_id,
        performer_id=performer_id,
    )

    if status != "accepted":
        if status != "pending":
            raise HTTPException(status_code=409, detail="Отклик нельзя принять в текущем статусе")

        execute(
            """
            UPDATE announcement_offers
            SET status = 'accepted'
            WHERE id = %s
            """,
            (offer_id,),
        )
        _sync_announcement_offers_count(ann_id)
        did_accept_now = True

    if did_accept_now:
        create_notification(
            user_id=performer_id,
            notif_type="offer_accepted",
            body="Ваш отклик принят. Открыт чат.",
            payload={"thread_id": thread_id, "announcement_id": ann_id, "offer_id": offer_id},
        )

    expanded = _fetch_expanded_offer(ann_id, offer_id)
    if expanded is None:
        raise HTTPException(status_code=500, detail="Failed to load accepted offer")

    return AcceptOfferOut(thread_id=thread_id, offer=expanded)


@app.post("/announcements/{ann_id}/offers/{offer_id}/reject", response_model=OKOut)
def reject_announcement_offer(
    ann_id: str,
    offer_id: str,
    user: UserOut = Depends(get_current_user),
) -> OKOut:
    ann = _fetch_announcement_or_404(ann_id)
    if ann.user_id != user.id:
        raise HTTPException(status_code=403, detail="Not your announcement")

    row = fetch_one(
        """
        SELECT performer_id, status
        FROM announcement_offers
        WHERE id = %s
          AND announcement_id = %s
          AND deleted_at IS NULL
        """,
        (offer_id, ann_id),
    )
    if not row:
        raise HTTPException(status_code=404, detail="Offer not found")

    performer_id, status = row
    if status == "accepted":
        raise HTTPException(status_code=409, detail="Нельзя отклонить уже принятый отклик")

    if status != "rejected":
        execute(
            """
            UPDATE announcement_offers
            SET status = 'rejected'
            WHERE id = %s
            """,
            (offer_id,),
        )
        _sync_announcement_offers_count(ann_id)
        create_notification(
            user_id=performer_id,
            notif_type="offer_rejected",
            body="Ваш отклик отклонён.",
            payload={"announcement_id": ann_id, "offer_id": offer_id},
        )

    return OKOut(ok=True)


# ----------------------------
# Chat (offer threads)
# ----------------------------
@app.get("/chats", response_model=List[ChatThreadOut])
def get_chats(user: UserOut = Depends(get_current_user)) -> List[ChatThreadOut]:
    if user.id == "dev":
        return []

    threads = list_user_threads(user.id)
    return [ChatThreadOut(**thread) for thread in threads]


@app.get("/chats/{thread_id}/messages", response_model=List[ChatMessageOut])
def get_chat_messages(
    thread_id: str,
    limit: int = 50,
    before: Optional[datetime] = None,
    user: UserOut = Depends(get_current_user),
) -> List[ChatMessageOut]:
    if user.id == "dev":
        return []

    messages = list_thread_messages(thread_id=thread_id, user_id=user.id, limit=limit, before=before)
    return [ChatMessageOut(**message) for message in messages]


@app.post("/chats/{thread_id}/messages", response_model=ChatMessageOut, status_code=201)
async def send_chat_message(
    thread_id: str,
    payload: ChatMessageIn,
    user: UserOut = Depends(get_current_user),
) -> ChatMessageOut:
    if user.id == "dev":
        raise HTTPException(status_code=400, detail="DEV chat is not available")

    await run_in_threadpool(assert_thread_access, thread_id, user.id)
    message = await run_in_threadpool(post_thread_message, thread_id, user.id, payload.text)
    await broadcast_chat_message(thread_id=thread_id, message=message)
    return ChatMessageOut(**message)


def _parse_ws_chat_text(raw_message: str) -> Optional[str]:
    raw = (raw_message or "").strip()
    if not raw:
        return None

    if not raw.startswith("{"):
        return raw

    try:
        payload = json.loads(raw)
    except Exception:
        return raw

    if not isinstance(payload, dict):
        return None

    message_type = str(payload.get("type") or "").lower()
    if message_type == "ping":
        return None

    text_value = payload.get("text")
    if isinstance(text_value, str):
        normalized = text_value.strip()
        return normalized or None

    return None


@app.websocket("/ws/chats/{thread_id}")
async def chat_websocket(thread_id: str, websocket: WebSocket) -> None:
    try:
        user = _ws_current_user(websocket)
    except HTTPException:
        await websocket.close(code=4401)
        return

    if user.id == "dev":
        await websocket.close(code=4403)
        return

    try:
        await run_in_threadpool(assert_thread_access, thread_id, user.id)
    except HTTPException:
        await websocket.close(code=4403)
        return

    await connect_chat_socket(thread_id, websocket)
    try:
        await websocket.send_json({"type": "ready", "thread_id": thread_id})
        while True:
            incoming = await websocket.receive_text()
            text = _parse_ws_chat_text(incoming)
            if text is None:
                await websocket.send_json({"type": "pong"})
                continue

            message = await run_in_threadpool(post_thread_message, thread_id, user.id, text)
            await broadcast_chat_event(
                thread_id=thread_id,
                payload={"type": "message", "payload": message},
            )
    except WebSocketDisconnect:
        pass
    except Exception:
        try:
            await websocket.send_json({"type": "error", "message": "Ошибка чата"})
        except Exception:
            pass
    finally:
        await disconnect_chat_socket(thread_id, websocket)


# ----------------------------
# Reports
# ----------------------------
@app.post("/reports", response_model=ReportOut, status_code=201)
def submit_report(
    payload: ReportCreateIn,
    user: UserOut = Depends(get_current_user),
) -> ReportOut:
    allowed_targets = {"announcement", "message", "user", "task"}
    if payload.target_type not in allowed_targets:
        raise HTTPException(status_code=400, detail="Unsupported target type")

    report_id = create_report(
        reporter_id=user.id,
        target_type=payload.target_type,
        target_id=payload.target_id,
        reason_code=payload.reason_code,
        reason_text=payload.reason_text,
    )
    row = fetch_one(
        f"""
        SELECT id, reporter_id, target_type, target_id, reason_code, reason_text, status,
               resolution, resolved_by, moderator_comment, created_at, resolved_at
        FROM reports
        WHERE id = %s
        """.replace("status", f"{report_status_select_sql('reports')} AS status", 1),
        (report_id,),
    )
    if not row:
        raise HTTPException(status_code=500, detail="Failed to create report")
    return _row_to_report(row)


# ----------------------------
# Support chat (public API)
# ----------------------------
@app.get("/support/thread", response_model=SupportThreadOut)
def get_support_thread(user: UserOut = Depends(get_current_user)) -> SupportThreadOut:
    return SupportThreadOut(thread_id=get_or_create_support_thread(user.id))


@app.get("/support/thread/{thread_id}/messages", response_model=List[SupportMessageOut])
def get_support_thread_messages(
    thread_id: str,
    limit: int = 50,
    before: Optional[datetime] = None,
    user: UserOut = Depends(get_current_user),
) -> List[SupportMessageOut]:
    messages = list_support_messages(thread_id=thread_id, user_id=user.id, limit=limit, before=before)
    return [SupportMessageOut(**message) for message in messages]


@app.post("/support/thread/{thread_id}/messages", response_model=SupportMessageOut, status_code=201)
def send_support_thread_message(
    thread_id: str,
    payload: SupportMessageIn,
    user: UserOut = Depends(get_current_user),
) -> SupportMessageOut:
    message = post_support_message(
        thread_id=thread_id,
        sender_id=user.id,
        text=payload.text,
        sender_role=user.role,
    )
    return SupportMessageOut(**message)


# ----------------------------
# Lists
# ----------------------------
@app.get("/announcements/me", response_model=List[AnnouncementOut])
def my_announcements(user: UserOut = Depends(get_current_user)) -> List[AnnouncementOut]:
    rows = fetch_all(
        """
        SELECT id, user_id, category, title, status, data, created_at
        FROM announcements
        WHERE user_id = %s AND deleted_at IS NULL
        ORDER BY created_at DESC
        """,
        (user.id,),
    )
    return [_row_to_announcement(r) for r in rows]


@app.get("/announcements/public", response_model=List[AnnouncementOut])
def public_announcements(limit: int = 200) -> List[AnnouncementOut]:
    lim = max(1, min(int(limit), 500))
    rows = fetch_all(
        """
        SELECT id, user_id, category, title, status, data, created_at
        FROM announcements
        WHERE deleted_at IS NULL
          AND status = %s
          AND COALESCE(announcements.data -> 'moderation' -> 'text' ->> 'manual_review_required', 'false') <> 'true'
          AND COALESCE(announcements.data -> 'moderation' -> 'image' ->> 'manual_review_required', 'false') <> 'true'
          AND jsonb_array_length(
                CASE
                    WHEN jsonb_typeof(announcements.data -> 'moderation' -> 'reasons') = 'array'
                    THEN announcements.data -> 'moderation' -> 'reasons'
                    ELSE '[]'::jsonb
                END
              ) = 0
          AND NOT EXISTS (
              SELECT 1
              FROM announcement_offers ao
              WHERE ao.announcement_id::text = announcements.id::text
                AND ao.status = 'accepted'
                AND ao.deleted_at IS NULL
          )
          AND announcements.user_id::text <> 'dev'
          AND EXISTS (
              SELECT 1
              FROM users u
              WHERE u.id::text = announcements.user_id::text
          )
        ORDER BY created_at DESC
        LIMIT %s
        """,
        (STATUS_ACTIVE, lim),
    )
    return [_row_to_announcement(r) for r in rows]
