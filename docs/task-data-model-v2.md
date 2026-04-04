# Task Data Model V2

## Why the old model breaks

The legacy backend treats `announcements` as the root record and stores most task semantics in `announcements.data` JSON. That creates four systemic problems:

1. Task identity is not the source of truth.
   Chat threads, offers, route visibility, moderation state, and execution flow are attached to an announcement in loosely coupled ways.
2. Task lifecycle and execution lifecycle are mixed together.
   A single `status` string is used for moderation, publication, assignment, execution, and archive semantics.
3. Builder data is stored as UI payload instead of domain data.
   Search, map, analytics, route matching, and recommendations all depend on fields that live in flexible JSON without a normalized projection.
4. Deletion is not modeled as a lifecycle transition.
   Soft-deleting the parent announcement leaves route/chat/offer state to be filtered ad hoc.

## Core design principles

1. `task` is the central aggregate.
2. Builder parameters are stored twice:
   a. as an immutable task snapshot for reconstruction/history,
   b. as normalized/derived columns for filtering, ranking, and joins.
3. Task lifecycle and execution lifecycle are separate state machines.
4. Accepted performer flow is modeled as an assignment, not as a side effect of offer status alone.
5. Task-specific chats always belong to both `task_id` and `assignment_id`.
6. Public visibility is derived from task state, not from individual screens.

## New aggregates

- `tasks`
  The root entity. Owns lifecycle, visibility, deletion policy, current snapshot, current assignment, and public search fields.
- `task_snapshots`
  Immutable builder snapshots. Every publish/edit operation produces a versioned snapshot.
- `task_route_points`
  Ordered stops for source/destination/waypoints, including visibility rules.
- `task_media`
  Task-bound media with moderation fields.
- `task_offers`
  One logical offer row per performer per task. Status transitions update the same row, which blocks repeated re-application after reject/withdraw.
- `task_assignments`
  The accepted performer execution context. Route visibility, execution status, chat scope, and completion state hang off this record.
- `task_execution_events`
  Append-only state transition log for performer/customer synchronization.
- `chat_threads`, `chat_thread_participants`, `chat_messages`
  Threads are explicitly task-bound and assignment-bound.
- `moderation_cases`, `moderation_artifacts`, `moderation_events`
  Moderation becomes first-class and can affect task lifecycle deterministically.

## State model

### Task lifecycle

- `draft`
- `pending_review`
- `needs_fix`
- `open`
- `assigned`
- `in_progress`
- `completed`
- `cancelled`
- `archived`
- `rejected`
- `deleted`

### Assignment / execution lifecycle

- `accepted`
- `en_route`
- `on_site`
- `in_progress`
- `handoff`
- `completed`
- `cancelled_by_customer`
- `cancelled_by_performer`
- `disputed`

### Offer lifecycle

- `pending`
- `accepted`
- `rejected`
- `withdrawn`
- `expired`
- `blocked`

## Visibility rules

- Map discovery:
  only `tasks.lifecycle_status = 'open'`, `deleted_at IS NULL`, `public_visibility = true`, and no active assignment.
- Route suggestions:
  same as map discovery plus geospatial match and route compatibility.
- Customer route visibility:
  only after an active assignment exists for the task.
- Task chat:
  created only when an assignment is created; archived when task/assignment is closed.

## Deletion strategy

- `tasks.deleted_at` is the product-facing delete switch.
- Public queries must exclude deleted tasks.
- Child records with no long-term business value cascade physically:
  `task_route_points`, derived search rows, ephemeral media links, route caches.
- Child records with audit value remain but are archived:
  `task_offers`, `task_assignments`, `chat_threads`, `chat_messages`, `moderation_events`, `task_execution_events`.
- A deleted task can never appear on map, route discovery, active offers, or live task chat flows.

## Migration from legacy tables

- `announcements` -> `tasks` + `task_snapshots` + `task_route_points`
- `announcement_offers` -> `task_offers`
- accepted offer side effects -> `task_assignments`
- offer threads -> `chat_threads`
- moderation JSON in `announcements.data` -> `moderation_cases` + `moderation_artifacts` + `moderation_events`

## What the client now sends

The client keeps legacy flat keys for backward compatibility, but also sends a new nested `task` payload with:

- `task.schema_version`
- `task.lifecycle.status`
- `task.builder.*`
- `task.attributes.*`
- `task.budget.*`
- `task.route.*`
- `task.contacts.*`
- `task.search.*`
- `task.offer_policy.*`
- `task.execution.*`

That payload is the contract for the V2 backend schema.
