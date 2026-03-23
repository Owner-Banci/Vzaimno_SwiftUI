from __future__ import annotations

FIND_ANNOUNCEMENT_SQL = """
SELECT id, user_id, category, title, status, data
FROM announcements
WHERE id::text = %s
  AND deleted_at IS NULL
"""

HAS_ACCEPTED_OFFER_SQL = """
SELECT 1
FROM announcement_offers
WHERE announcement_id::text = %s
  AND performer_id::text = %s
  AND status = 'accepted'
  AND deleted_at IS NULL
LIMIT 1
"""

FIND_CURRENT_ROUTE_ANNOUNCEMENT_SQL = """
SELECT a.id
FROM announcement_offers ao
JOIN announcements a
  ON a.id::text = ao.announcement_id::text
WHERE ao.performer_id::text = %s
  AND ao.status = 'accepted'
  AND ao.deleted_at IS NULL
  AND a.deleted_at IS NULL
ORDER BY ao.created_at DESC
LIMIT 1
"""

NEARBY_TASKS_BY_ROUTE_SQL = """
WITH route AS (
    SELECT ST_SetSRID(ST_GeomFromGeoJSON(%s), 4326)::geography AS geog
),
candidates AS (
    SELECT
        a.id,
        a.title,
        a.category,
        a.status,
        a.data,
        COALESCE(
            a.location_point,
            CASE
                WHEN jsonb_typeof(a.data -> 'point') = 'object'
                     AND COALESCE(a.data -> 'point' ->> 'lat', '') ~ '^-?[0-9]+(\\.[0-9]+)?$'
                     AND COALESCE(a.data -> 'point' ->> 'lon', '') ~ '^-?[0-9]+(\\.[0-9]+)?$'
                THEN ST_SetSRID(
                    ST_MakePoint(
                        (a.data -> 'point' ->> 'lon')::double precision,
                        (a.data -> 'point' ->> 'lat')::double precision
                    ),
                    4326
                )::geography
                ELSE NULL
            END
        ) AS point_geog
FROM announcements a
WHERE a.deleted_at IS NULL
  AND a.status = 'active'
  AND a.id::text <> %s
  AND a.user_id::text <> %s
)
SELECT
    c.id,
    c.title,
    c.category,
    c.status,
    c.data,
    ST_Y(c.point_geog::geometry) AS latitude,
    ST_X(c.point_geog::geometry) AS longitude,
    ST_Distance(c.point_geog, (SELECT geog FROM route)) AS distance_to_route_meters
FROM candidates c
WHERE c.point_geog IS NOT NULL
  AND ST_DWithin(c.point_geog, (SELECT geog FROM route), %s)
ORDER BY distance_to_route_meters ASC
LIMIT %s
"""
