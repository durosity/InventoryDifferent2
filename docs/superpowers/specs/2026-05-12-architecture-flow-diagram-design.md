# Architecture Flow Diagram

**Date:** 2026-05-12
**Status:** Approved

## Overview

A self-contained interactive HTML diagram that documents data flows between the app's packages and components. Two files live in `docs/architecture/`: a `flows.json` data file and a `flows.html` viewer. The JSON is the authoritative source for both human reference and AI agent understanding; the HTML renders it as a clickable diagram.

## Files

| File | Purpose |
|------|---------|
| `docs/architecture/flows.json` | Authoritative data: packages, edges, flows |
| `docs/architecture/flows.html` | Interactive viewer — loads flows.json via fetch |

The HTML has no build step and no dependencies. It must be served (not opened as `file://`) due to `fetch()`. A clear error message guides the user to run `python3 -m http.server` from `docs/architecture/` if fetch fails.

## JSON Schema

```json
{
  "packages": [
    {
      "id": "p-web",
      "name": "Web",
      "sub": "Next.js admin",
      "tier": "client"
    }
  ],
  "edges": [
    {
      "id": "e-web-api",
      "from": "p-web",
      "to": "p-api",
      "label": "GraphQL mutation / REST"
    }
  ],
  "flows": [
    {
      "id": "create-device",
      "icon": "📦",
      "name": "Create Device",
      "path": "Web → API → PostgreSQL",
      "steps": [
        {
          "title": "User submits form",
          "desc": "Apollo Client fires createDevice mutation from web/src/app.",
          "packages": ["p-web"],
          "edges": ["e-web-api"]
        }
      ]
    }
  ]
}
```

### Package tiers

The `tier` field controls vertical position in the diagram:

| Tier | Packages |
|------|---------|
| `client` | Web, iOS, Storefront, Showcase |
| `middleware` | MCP Server |
| `api` | GraphQL API |
| `storage` | PostgreSQL, /uploads |

### Step granularity

Each step references the packages and edges active during that step. A step may reference multiple packages and edges to represent parallel operations (e.g. a resolver that writes to both PostgreSQL and /uploads in one call).

## HTML Viewer Layout

**Left panel — architecture diagram**
- Packages rendered as rounded boxes arranged by tier (top = client, bottom = storage)
- SVG edges connect packages; edges are named and match IDs in `flows.json`
- When a flow is selected: unrelated packages dim, flow packages highlight, active-step edges glow with a numbered badge at the midpoint

**Right panel — flow list + step detail**
- Top section: scrollable list of all flows from `flows.json`
  - Hover previews which packages are involved (dim/highlight without locking)
  - Click locks the selection
- Bottom section: step list for the selected flow
  - Each step is clickable; clicking highlights the specific packages and edges active at that step
  - Numbered badge appears on the active edge midpoint

No action buttons in a top bar — flows live only in the right panel list.

## CLAUDE.md Addition

A new **"App Flow Reference"** section will be added with these instructions:

- Before implementing a new feature, read `docs/architecture/flows.json` to understand which packages the feature touches and how data currently moves through the system
- When adding a new user-facing action, add a corresponding flow entry with accurate steps, package references, and edge references
- When changing how an existing feature works (new endpoint, new package involved, changed data path), update the relevant flow's steps
- When removing a feature, remove its flow entry
- To view the diagram: `cd docs/architecture && python3 -m http.server`, then open `http://localhost:8000/flows.html`

## Initial Flow Coverage

The following flows will be extracted from the codebase and documented in `flows.json`:

**Device management**
- Create Device
- Edit Device
- Delete Device (soft)
- Restore Device
- Permanently Delete Device

**Media**
- Add Photo (web + iOS)
- Upload Video
- Delete Image
- Replace Showcase Image

**Notes & tasks**
- Add Note
- Edit / Delete Note
- Add Maintenance Task

**Tags & custom fields**
- Add / Remove Tag
- Create Custom Field
- Set Custom Field Value

**Authentication**
- Login
- Token Refresh

**Bulk operations**
- Bulk Import (ZIP)
- Bulk Export (ZIP)

**Showcase / The Archive**
- Create Journey
- Edit Journey (chapters, devices)
- Publish / Unpublish Journey
- Showcase Import / Export

**AI / MCP**
- AI Query (chat → MCP → API)

**Storefront**
- Browse For-Sale Devices
- Device Detail Page

**Admin utilities**
- Orphaned File Scan & Delete
- Value Snapshot (auto on device save)

## Out of Scope

- Deployment flows (Docker, GitHub Actions CI) — these are infrastructure, not app data flows
- Internal Prisma query mechanics — documented at the resolver level, not the ORM level
- iOS-internal navigation flows — this document covers cross-package data flows only
