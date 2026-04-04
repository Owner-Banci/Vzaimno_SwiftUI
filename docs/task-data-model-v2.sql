-- Task data model V2
-- This file is a migration blueprint for replacing the legacy
-- announcements + announcement_offers centric schema.

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_lifecycle_status') THEN
        CREATE TYPE task_lifecycle_status AS ENUM (
            'draft',
            'pending_review',
            'needs_fix',
            'open',
            'assigned',
            'in_progress',
            'completed',
            'cancelled',
            'archived',
            'rejected',
            'deleted'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_execution_status') THEN
        CREATE TYPE task_execution_status AS ENUM (
            'accepted',
            'en_route',
            'on_site',
            'in_progress',
            'handoff',
            'completed',
            'cancelled_by_customer',
            'cancelled_by_performer',
            'disputed'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_offer_status') THEN
        CREATE TYPE task_offer_status AS ENUM (
            'pending',
            'accepted',
            'rejected',
            'withdrawn',
            'expired',
            'blocked'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'task_offer_pricing_mode') THEN
        CREATE TYPE task_offer_pricing_mode AS ENUM (
            'quick_min_price',
            'counter_price',
            'agreed_price'
        );
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'moderation_case_status') THEN
        CREATE TYPE moderation_case_status AS ENUM (
            'pending',
            'approved',
            'needs_fix',
            'rejected',
            'appealed',
            'resolved'
        );
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id UUID NOT NULL REFERENCES users(id),
    public_id TEXT UNIQUE,
    title TEXT NOT NULL,
    main_group TEXT NOT NULL,
    action_type TEXT NOT NULL,
    lifecycle_status task_lifecycle_status NOT NULL DEFAULT 'draft',
    current_snapshot_id UUID,
    current_assignment_id UUID,
    moderation_state moderation_case_status NOT NULL DEFAULT 'pending',
    budget_min INTEGER,
    budget_max INTEGER,
    quick_offer_price INTEGER,
    currency_code TEXT NOT NULL DEFAULT 'RUB',
    source_point GEOGRAPHY(Point, 4326),
    destination_point GEOGRAPHY(Point, 4326),
    source_address TEXT,
    destination_address TEXT,
    search_document JSONB NOT NULL DEFAULT '{}'::jsonb,
    analytics_document JSONB NOT NULL DEFAULT '{}'::jsonb,
    public_visibility BOOLEAN NOT NULL DEFAULT FALSE,
    offers_open BOOLEAN NOT NULL DEFAULT FALSE,
    deleted_at TIMESTAMPTZ,
    archived_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (budget_min IS NULL OR budget_min >= 0),
    CHECK (budget_max IS NULL OR budget_max >= 0),
    CHECK (
        budget_min IS NULL
        OR budget_max IS NULL
        OR budget_min <= budget_max
    )
);

CREATE INDEX IF NOT EXISTS idx_tasks_public_visibility
    ON tasks (lifecycle_status, public_visibility, deleted_at);

CREATE INDEX IF NOT EXISTS idx_tasks_source_point
    ON tasks USING gist (source_point);

CREATE INDEX IF NOT EXISTS idx_tasks_destination_point
    ON tasks USING gist (destination_point);

CREATE TABLE IF NOT EXISTS task_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    version_no INTEGER NOT NULL,
    builder_payload JSONB NOT NULL,
    derived_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (task_id, version_no)
);

CREATE TABLE IF NOT EXISTS task_route_points (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    snapshot_id UUID NOT NULL REFERENCES task_snapshots(id) ON DELETE CASCADE,
    point_role TEXT NOT NULL,
    sequence_no INTEGER NOT NULL,
    address_text TEXT,
    point GEOGRAPHY(Point, 4326),
    visibility_scope TEXT NOT NULL DEFAULT 'public',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (snapshot_id, sequence_no)
);

CREATE INDEX IF NOT EXISTS idx_task_route_points_point
    ON task_route_points USING gist (point);

CREATE TABLE IF NOT EXISTS task_media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
    snapshot_id UUID NOT NULL REFERENCES task_snapshots(id) ON DELETE CASCADE,
    media_type TEXT NOT NULL DEFAULT 'image',
    storage_path TEXT NOT NULL,
    moderation_state moderation_case_status NOT NULL DEFAULT 'pending',
    moderation_payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS task_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES tasks(id),
    performer_user_id UUID NOT NULL REFERENCES users(id),
    pricing_mode task_offer_pricing_mode NOT NULL,
    message TEXT,
    proposed_price INTEGER,
    agreed_price INTEGER,
    minimum_price_accepted BOOLEAN NOT NULL DEFAULT FALSE,
    status task_offer_status NOT NULL DEFAULT 'pending',
    rejection_reason_code TEXT,
    blocked_reapply BOOLEAN NOT NULL DEFAULT FALSE,
    responded_at TIMESTAMPTZ,
    status_changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (task_id, performer_user_id),
    CHECK (proposed_price IS NULL OR proposed_price >= 0),
    CHECK (agreed_price IS NULL OR agreed_price >= 0),
    CHECK (
        pricing_mode <> 'quick_min_price'
        OR (minimum_price_accepted = TRUE AND agreed_price IS NOT NULL)
    )
);

CREATE INDEX IF NOT EXISTS idx_task_offers_task_status
    ON task_offers (task_id, status);

CREATE TABLE IF NOT EXISTS task_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES tasks(id),
    accepted_offer_id UUID NOT NULL UNIQUE REFERENCES task_offers(id),
    customer_user_id UUID NOT NULL REFERENCES users(id),
    performer_user_id UUID NOT NULL REFERENCES users(id),
    execution_status task_execution_status NOT NULL DEFAULT 'accepted',
    route_visible_to_customer BOOLEAN NOT NULL DEFAULT TRUE,
    chat_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    archived_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (task_id) DEFERRABLE INITIALLY IMMEDIATE
);

CREATE TABLE IF NOT EXISTS task_execution_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES tasks(id),
    assignment_id UUID NOT NULL REFERENCES task_assignments(id),
    actor_user_id UUID NOT NULL REFERENCES users(id),
    from_status task_execution_status,
    to_status task_execution_status NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS moderation_cases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES tasks(id),
    snapshot_id UUID REFERENCES task_snapshots(id) ON DELETE SET NULL,
    target_type TEXT NOT NULL,
    target_id UUID,
    status moderation_case_status NOT NULL DEFAULT 'pending',
    decision_code TEXT,
    reason_code TEXT,
    can_appeal BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS moderation_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    moderation_case_id UUID NOT NULL REFERENCES moderation_cases(id) ON DELETE CASCADE,
    actor_user_id UUID REFERENCES users(id),
    event_type TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chat_threads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES tasks(id),
    assignment_id UUID REFERENCES task_assignments(id),
    thread_kind TEXT NOT NULL DEFAULT 'task_assignment',
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    archived_at TIMESTAMPTZ,
    last_message_id UUID,
    last_message_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS chat_thread_participants (
    thread_id UUID NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    role_in_thread TEXT NOT NULL,
    last_read_message_id UUID,
    last_read_at TIMESTAMPTZ,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (thread_id, user_id)
);

CREATE TABLE IF NOT EXISTS chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id UUID NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
    task_id UUID NOT NULL REFERENCES tasks(id),
    assignment_id UUID REFERENCES task_assignments(id),
    sender_user_id UUID NOT NULL REFERENCES users(id),
    message_type TEXT NOT NULL DEFAULT 'text',
    body TEXT NOT NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_thread_created
    ON chat_messages (thread_id, created_at DESC);

-- Optional trigger blueprint:
-- 1. when a task assignment is created:
--      a. set tasks.lifecycle_status = 'assigned'
--      b. close tasks.offers_open
--      c. archive or block all non-accepted offers
--      d. create one chat thread bound to task_id + assignment_id
-- 2. when a task is soft-deleted:
--      a. set tasks.lifecycle_status = 'deleted'
--      b. set public_visibility = FALSE and offers_open = FALSE
--      c. archive related chat_threads and task_assignments
-- 3. when an execution event is appended:
--      a. update task_assignments.execution_status
--      b. mirror tasks.lifecycle_status for open/assigned/in_progress/completed
