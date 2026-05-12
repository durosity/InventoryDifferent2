# Architecture Flow Diagram Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `docs/architecture/flows.json` (authoritative app flow data) and `docs/architecture/flows.html` (interactive diagram viewer), then update CLAUDE.md to instruct agents to reference and maintain the JSON.

**Architecture:** The JSON defines packages (diagram nodes), edges (named connections), and flows (user actions with ordered steps). The HTML loads the JSON via `fetch()`, renders a tiered architecture diagram on the left, and a flow list + step detail panel on the right. Hovering a flow previews which packages are involved; clicking locks the selection; clicking a step highlights the active edges with a numbered badge.

**Tech Stack:** Vanilla HTML/CSS/JS (no build step, no dependencies). JSON loaded via `fetch()` — must be served, not opened as `file://`.

---

## File Map

| File | Action | Purpose |
|------|--------|---------|
| `docs/architecture/flows.json` | Create | All packages, edges, and flows — the authoritative data source |
| `docs/architecture/flows.html` | Create | Interactive viewer that renders flows.json |
| `CLAUDE.md` | Modify | Add "App Flow Reference" section |

---

## Task 1: Create `docs/architecture/flows.json`

**Files:**
- Create: `docs/architecture/flows.json`

- [ ] **Step 1: Create the directory**

```bash
mkdir -p /Users/wottle/Documents/Development/InvDifferent2/docs/architecture
```

- [ ] **Step 2: Write `flows.json`**

Write this complete file to `docs/architecture/flows.json`:

```json
{
  "packages": [
    { "id": "p-web",        "name": "Web",          "sub": "Next.js admin",       "tier": "client" },
    { "id": "p-ios",        "name": "iOS",          "sub": "SwiftUI",             "tier": "client" },
    { "id": "p-storefront", "name": "Storefront",   "sub": "Next.js shop",        "tier": "client" },
    { "id": "p-showcase",   "name": "Showcase",     "sub": "The Archive",         "tier": "client" },
    { "id": "p-mcp",        "name": "MCP Server",   "sub": "AI tools / stdio",    "tier": "middleware" },
    { "id": "p-api",        "name": "GraphQL API",  "sub": "Express · Apollo · Prisma", "tier": "api" },
    { "id": "p-db",         "name": "PostgreSQL",   "sub": "Prisma ORM",          "tier": "storage" },
    { "id": "p-uploads",    "name": "/uploads",     "sub": "file storage",        "tier": "storage" }
  ],
  "edges": [
    { "id": "e-web-api",       "from": "p-web",        "to": "p-api", "label": "GraphQL / REST" },
    { "id": "e-ios-api",       "from": "p-ios",        "to": "p-api", "label": "GraphQL / REST" },
    { "id": "e-store-api",     "from": "p-storefront", "to": "p-api", "label": "GraphQL" },
    { "id": "e-showcase-api",  "from": "p-showcase",   "to": "p-api", "label": "GraphQL" },
    { "id": "e-mcp-api",       "from": "p-mcp",        "to": "p-api", "label": "GraphQL" },
    { "id": "e-api-db",        "from": "p-api",        "to": "p-db",  "label": "Prisma ORM" },
    { "id": "e-api-uploads",   "from": "p-api",        "to": "p-uploads", "label": "fs / sharp / ffmpeg" }
  ],
  "flows": [
    {
      "id": "create-device",
      "icon": "📦",
      "name": "Create Device",
      "path": "Web / iOS → API → PostgreSQL",
      "steps": [
        {
          "title": "User submits create form",
          "desc": "Apollo Client fires the createDevice GraphQL mutation with a DeviceCreateInput payload. JWT in Authorization header.",
          "packages": ["p-web", "p-ios"],
          "edges": ["e-web-api", "e-ios-api"]
        },
        {
          "title": "Resolver validates & writes",
          "desc": "createDevice resolver in resolvers.ts calls requireAuth(), then prisma.device.create() with DEVICE_INCLUDE.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        },
        {
          "title": "Activity log written",
          "desc": "If dateAcquired is set, a DEVICE_ACQUIRED ActivityLog row is inserted. This powers the dashboard activity feed.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        },
        {
          "title": "Device returned to client",
          "desc": "Full Device object (with relations) returned. Apollo Client writes it to its normalised cache; UI re-renders.",
          "packages": ["p-web", "p-ios"],
          "edges": ["e-web-api", "e-ios-api"]
        }
      ]
    },
    {
      "id": "edit-device",
      "icon": "✏️",
      "name": "Edit Device",
      "path": "Web / iOS → API → PostgreSQL",
      "steps": [
        {
          "title": "User saves changes",
          "desc": "Apollo Client fires updateDevice mutation with a DeviceUpdateInput. Only changed fields are sent.",
          "packages": ["p-web", "p-ios"],
          "edges": ["e-web-api", "e-ios-api"]
        },
        {
          "title": "Resolver reads current state",
          "desc": "updateDevice resolver reads the existing device (status, functionalStatus, lastPowerOnDate) before applying the update — needed to detect what changed for activity logging.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        },
        {
          "title": "DB row updated",
          "desc": "prisma.device.update() writes the clean data. Undefined fields are stripped so they don't overwrite existing values with null.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        },
        {
          "title": "Value snapshot created (conditional)",
          "desc": "If estimatedValue changed, a ValueSnapshot row is inserted — but only if the value differs from the last snapshot. Powers the per-device value history chart.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        },
        {
          "title": "Activity log entries written",
          "desc": "STATUS_CHANGED, FUNCTIONAL_STATUS_CHANGED, or POWERED_ON entries are inserted for each detected change. Powers the dashboard feed.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        }
      ]
    },
    {
      "id": "delete-device",
      "icon": "🗑",
      "name": "Delete Device (soft)",
      "path": "Web / iOS → API → PostgreSQL",
      "steps": [
        {
          "title": "User clicks Delete",
          "desc": "deleteDevice(id) mutation fired from web Trash page or iOS device detail.",
          "packages": ["p-web", "p-ios"],
          "edges": ["e-web-api", "e-ios-api"]
        },
        {
          "title": "Resolver sets deleted flag",
          "desc": "prisma.device.update({ data: { deleted: true } }) — device is hidden from all queries but not removed from DB.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        }
      ]
    },
    {
      "id": "restore-device",
      "icon": "♻️",
      "name": "Restore Device",
      "path": "Web → API → PostgreSQL",
      "steps": [
        {
          "title": "User clicks Restore in Trash",
          "desc": "restoreDevice(id) mutation fired from the /trash admin page.",
          "packages": ["p-web"],
          "edges": ["e-web-api"]
        },
        {
          "title": "Resolver clears deleted flag",
          "desc": "prisma.device.update({ data: { deleted: false } }). Full device object returned.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        }
      ]
    },
    {
      "id": "permanently-delete-device",
      "icon": "💥",
      "name": "Permanently Delete Device",
      "path": "Web → API → PostgreSQL + /uploads",
      "steps": [
        {
          "title": "User confirms permanent deletion",
          "desc": "permanentlyDeleteDevice(id) mutation fired from the /trash admin page after confirmation dialog.",
          "packages": ["p-web"],
          "edges": ["e-web-api"]
        },
        {
          "title": "API collects image paths",
          "desc": "Resolver fetches device with { include: { images: true } } to get all file paths before deletion.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        },
        {
          "title": "DB cascade delete",
          "desc": "prisma.device.delete() removes the row; Prisma cascades to images, notes, maintenanceTasks, tags, customFieldValues.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        },
        {
          "title": "Upload files deleted from disk",
          "desc": "Resolver loops over image paths and calls fs.unlinkSync() on each. The device's upload directory is then removed.",
          "packages": ["p-api"],
          "edges": ["e-api-uploads"]
        }
      ]
    },
    {
      "id": "add-photo",
      "icon": "📷",
      "name": "Add Photo",
      "path": "Web / iOS → REST /upload → /uploads → createImage → PostgreSQL",
      "steps": [
        {
          "title": "Client selects image file",
          "desc": "Web: file input triggers. iOS: PHPickerViewController presents photo library. Image is held in memory ready to POST.",
          "packages": ["p-web", "p-ios"],
          "edges": []
        },
        {
          "title": "POST /upload (multipart/form-data)",
          "desc": "Client POSTs to /upload?deviceId=X. This is a REST endpoint — not GraphQL — handled by multer (2 GB limit). JWT required.",
          "packages": ["p-web", "p-ios"],
          "edges": ["e-web-api", "e-ios-api"]
        },
        {
          "title": "File saved to /uploads",
          "desc": "multer writes the file to /uploads/devices/{deviceId}/{uuid}.ext on disk. The path is returned in the JSON response.",
          "packages": ["p-api"],
          "edges": ["e-api-uploads"]
        },
        {
          "title": "createImage mutation fired",
          "desc": "Client passes the returned path to createImage GraphQL mutation. Resolver calls generateThumbnailForUpload() — sharp generates a 320×320 WebP thumbnail and saves it alongside the original.",
          "packages": ["p-api"],
          "edges": ["e-api-uploads"]
        },
        {
          "title": "Image row saved to DB",
          "desc": "prisma.image.create() writes path, thumbnailPath, dateTaken (from EXIF), isThumbnail, and deviceId. First IMAGE auto-becomes the device thumbnail.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        }
      ]
    },
    {
      "id": "upload-video",
      "icon": "🎥",
      "name": "Upload Video",
      "path": "Web / iOS → REST /upload → /uploads → createImage (async thumb) → PostgreSQL",
      "steps": [
        {
          "title": "Client selects video file",
          "desc": "Web: file input with video/* accept. iOS: PHPickerViewController with video media type.",
          "packages": ["p-web", "p-ios"],
          "edges": []
        },
        {
          "title": "POST /upload",
          "desc": "Client POSTs the video to /upload?deviceId=X. multer accepts mp4/mov/webm/avi up to 2 GB.",
          "packages": ["p-web", "p-ios"],
          "edges": ["e-web-api", "e-ios-api"]
        },
        {
          "title": "File saved to /uploads",
          "desc": "multer writes the video to /uploads/devices/{deviceId}/{uuid}.mp4 (or original ext). Path returned to client.",
          "packages": ["p-api"],
          "edges": ["e-api-uploads"]
        },
        {
          "title": "createImage mutation — DB row created immediately",
          "desc": "Resolver creates the image record instantly (mediaType: VIDEO, no thumbnailPath yet) so the client isn't blocked by ffmpeg processing.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        },
        {
          "title": "Async: ffmpeg generates thumbnail",
          "desc": "setImmediate() runs generateVideoThumbnail() in the background: ffmpeg extracts frame at 1s, sharp converts to 320×320 WebP, ffprobe reads duration. The image row is updated when done.",
          "packages": ["p-api"],
          "edges": ["e-api-uploads", "e-api-db"]
        }
      ]
    },
    {
      "id": "delete-image",
      "icon": "🗑",
      "name": "Delete Image / Video",
      "path": "Web / iOS → API → PostgreSQL + /uploads",
      "steps": [
        {
          "title": "User clicks Delete on image",
          "desc": "deleteImage(id) mutation fired from web device detail Photos tab or iOS Images tab.",
          "packages": ["p-web", "p-ios"],
          "edges": ["e-web-api", "e-ios-api"]
        },
        {
          "title": "Resolver fetches paths then deletes DB row",
          "desc": "deleteImage resolver reads the image record to get path and thumbnailPath, then calls prisma.image.delete().",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        },
        {
          "title": "Files removed from disk",
          "desc": "fs.unlinkSync() called on both the original file and the WebP thumbnail (if it exists).",
          "packages": ["p-api"],
          "edges": ["e-api-uploads"]
        }
      ]
    },
    {
      "id": "add-note",
      "icon": "📝",
      "name": "Add Note",
      "path": "Web / iOS / MCP → API → PostgreSQL",
      "steps": [
        {
          "title": "Note submitted",
          "desc": "createNote(input) mutation fired from web device detail, iOS Notes tab, or MCP add_note tool.",
          "packages": ["p-web", "p-ios", "p-mcp"],
          "edges": ["e-web-api", "e-ios-api", "e-mcp-api"]
        },
        {
          "title": "Resolver writes note",
          "desc": "createNote resolver calls prisma.note.create() with content, date (auto-timestamped), and deviceId.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        }
      ]
    },
    {
      "id": "add-maintenance-task",
      "icon": "🔧",
      "name": "Add Maintenance Task",
      "path": "Web / iOS / MCP → API → PostgreSQL",
      "steps": [
        {
          "title": "Task submitted",
          "desc": "createMaintenanceTask(input) mutation fired from web, iOS, or MCP add_maintenance_task tool. Input includes label, dateCompleted, notes, optional cost.",
          "packages": ["p-web", "p-ios", "p-mcp"],
          "edges": ["e-web-api", "e-ios-api", "e-mcp-api"]
        },
        {
          "title": "Resolver writes task",
          "desc": "prisma.maintenanceTask.create(). The cost field rolls up into totalMaintenanceCost on the financials page.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        }
      ]
    },
    {
      "id": "login",
      "icon": "🔐",
      "name": "Login",
      "path": "Web / iOS → REST /auth/login → API",
      "steps": [
        {
          "title": "User submits password",
          "desc": "Client POSTs { password } to /auth/login. This is a REST endpoint — not GraphQL.",
          "packages": ["p-web", "p-ios"],
          "edges": ["e-web-api", "e-ios-api"]
        },
        {
          "title": "API validates password",
          "desc": "Express route compares against AUTH_PASSWORD env var using bcrypt. If AUTH_PASSWORD is not set, auth is disabled entirely.",
          "packages": ["p-api"],
          "edges": []
        },
        {
          "title": "JWT tokens issued",
          "desc": "API returns { accessToken (1h), refreshToken (7d) } signed with JWT_SECRET. Client stores tokens and attaches accessToken as Authorization: Bearer header on subsequent requests.",
          "packages": ["p-web", "p-ios"],
          "edges": ["e-web-api", "e-ios-api"]
        }
      ]
    },
    {
      "id": "token-refresh",
      "icon": "🔄",
      "name": "Token Refresh",
      "path": "Web / iOS → REST /auth/refresh → API",
      "steps": [
        {
          "title": "Client detects expiring access token",
          "desc": "Before the 1-hour access token expires, client POSTs { refreshToken } to /auth/refresh.",
          "packages": ["p-web", "p-ios"],
          "edges": ["e-web-api", "e-ios-api"]
        },
        {
          "title": "API issues new access token",
          "desc": "Express verifies the refresh token against JWT_SECRET and returns a new { accessToken }. Refresh token is not rotated.",
          "packages": ["p-api"],
          "edges": []
        }
      ]
    },
    {
      "id": "bulk-import",
      "icon": "📥",
      "name": "Bulk Import (ZIP)",
      "path": "Web → REST /import → API (async) → PostgreSQL + /uploads",
      "steps": [
        {
          "title": "User uploads ZIP file",
          "desc": "Backup page POSTs ZIP to /import (2 GB limit via multer diskStorage to /tmp/imports). Server returns { jobId } immediately — processing is async.",
          "packages": ["p-web"],
          "edges": ["e-web-api"]
        },
        {
          "title": "API extracts and validates",
          "desc": "ZIP is unpacked; manifest JSON parsed; device records validated. Errors are collected (fail-collect, not fail-fast) so partial imports succeed.",
          "packages": ["p-api"],
          "edges": []
        },
        {
          "title": "Images written to /uploads",
          "desc": "Each bundled image extracted to /uploads/devices/{id}/. sharp generates a 320×320 WebP thumbnail per image.",
          "packages": ["p-api"],
          "edges": ["e-api-uploads"]
        },
        {
          "title": "Devices upserted to DB",
          "desc": "prisma.device.upsert() called per device. Images inserted via prisma.image.createMany().",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        },
        {
          "title": "Client polls for progress",
          "desc": "Web polls GET /import/progress/:jobId. On completion, result includes { imported, skipped, errors }. Progress bar advances in real-time.",
          "packages": ["p-web"],
          "edges": ["e-web-api"]
        }
      ]
    },
    {
      "id": "bulk-export",
      "icon": "📤",
      "name": "Bulk Export (ZIP)",
      "path": "Web → REST /export/start → API (async) → Web download",
      "steps": [
        {
          "title": "User initiates export",
          "desc": "Backup page POSTs { deviceIds } to /export/start. Server returns { jobId } immediately.",
          "packages": ["p-web"],
          "edges": ["e-web-api"]
        },
        {
          "title": "API builds ZIP asynchronously",
          "desc": "API reads device rows and image files from disk, bundles them into a ZIP with a manifest JSON. Progress tracked in exportJobs Map.",
          "packages": ["p-api"],
          "edges": ["e-api-db", "e-api-uploads"]
        },
        {
          "title": "Client polls progress",
          "desc": "Web polls GET /export/progress/:jobId until status = 'done'.",
          "packages": ["p-web"],
          "edges": ["e-web-api"]
        },
        {
          "title": "Client downloads ZIP",
          "desc": "Browser navigates to GET /export/download/:jobId which streams the assembled ZIP file.",
          "packages": ["p-web"],
          "edges": ["e-web-api"]
        }
      ]
    },
    {
      "id": "create-journey",
      "icon": "🗺",
      "name": "Create Journey",
      "path": "Showcase → API → PostgreSQL",
      "steps": [
        {
          "title": "Admin fills journey form",
          "desc": "JourneyEditor.tsx in showcase/src/components/admin/ fires the createJourney mutation with { title, slug, description, published, sortOrder }.",
          "packages": ["p-showcase"],
          "edges": ["e-showcase-api"]
        },
        {
          "title": "Resolver creates journey",
          "desc": "createJourney resolver calls prisma.showcaseJourney.create(). Returns the new journey with its id.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        },
        {
          "title": "Admin list cache invalidated",
          "desc": "createJourney mutation has refetchQueries: [GET_ALL_SHOWCASE_JOURNEYS_ADMIN] so the journey list page reflects the new entry immediately without a page refresh.",
          "packages": ["p-showcase"],
          "edges": ["e-showcase-api"]
        },
        {
          "title": "Editor navigates to edit page",
          "desc": "On success, router.push('/admin/journeys/{id}') takes the admin to the full editor where chapters and devices can be added.",
          "packages": ["p-showcase"],
          "edges": []
        }
      ]
    },
    {
      "id": "edit-journey",
      "icon": "✏️",
      "name": "Edit Journey (chapters & devices)",
      "path": "Showcase → API → PostgreSQL",
      "steps": [
        {
          "title": "Editor loads journey data",
          "desc": "GET_ALL_JOURNEYS_FOR_EDIT query fetches chapters and their showcase devices via Apollo. Cache-first, network if stale.",
          "packages": ["p-showcase"],
          "edges": ["e-showcase-api"]
        },
        {
          "title": "Chapter title/description auto-saves on blur",
          "desc": "ChapterCard.tsx fires upsertChapter mutation on input blur. Creates a new chapter if no id yet; updates if id exists.",
          "packages": ["p-showcase"],
          "edges": ["e-showcase-api"]
        },
        {
          "title": "Resolver upserts chapter",
          "desc": "prisma.showcaseChapter.upsert() keyed on id. sortOrder changes from reorder buttons are also persisted here.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        },
        {
          "title": "Device added to chapter",
          "desc": "DeviceSearchModal fires upsertShowcaseDevice mutation with { chapterId, deviceId, sortOrder, isFeatured }.",
          "packages": ["p-showcase"],
          "edges": ["e-showcase-api"]
        },
        {
          "title": "ShowcaseDevice row created",
          "desc": "prisma.showcaseDevice.upsert() links the inventory Device to the chapter. curatorNote and isFeatured can be edited inline.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        }
      ]
    },
    {
      "id": "showcase-export-import",
      "icon": "📦",
      "name": "Showcase Export / Import",
      "path": "Web → REST /showcase/export|import → API → PostgreSQL + /uploads",
      "steps": [
        {
          "title": "Admin triggers export or import",
          "desc": "GET /showcase/export streams a ZIP. POST /showcase/import receives a ZIP (up to 2 GB). Both endpoints require auth.",
          "packages": ["p-web"],
          "edges": ["e-web-api"]
        },
        {
          "title": "Export: ZIP built from DB + uploads",
          "desc": "API reads all journeys, chapters, and showcase devices from DB. For export, active showcase images are bundled into the ZIP.",
          "packages": ["p-api"],
          "edges": ["e-api-db", "e-api-uploads"]
        },
        {
          "title": "Import: ZIP extracted, DB upserted",
          "desc": "Import unpacks ZIP, parses manifest, upserts journeys/chapters/devices by slug. Images are written to /uploads. Missing inventory devices are silently skipped.",
          "packages": ["p-api"],
          "edges": ["e-api-db", "e-api-uploads"]
        }
      ]
    },
    {
      "id": "ai-query",
      "icon": "🤖",
      "name": "AI Query (Chat)",
      "path": "iOS / Web → OpenAI → MCP Server → API → PostgreSQL",
      "steps": [
        {
          "title": "User types or speaks a question",
          "desc": "iOS ChatView (AVSpeechRecognizer for voice input) or web CollectionChat sends the message to OpenAI with the MCP tool list attached.",
          "packages": ["p-web", "p-ios"],
          "edges": []
        },
        {
          "title": "OpenAI selects an MCP tool",
          "desc": "The model chooses from: list_all_devices, search_devices, get_device_details, get_financial_summary, list_devices, update_device, add_note, add_maintenance_task.",
          "packages": ["p-mcp"],
          "edges": []
        },
        {
          "title": "MCP server calls GraphQL API",
          "desc": "MCP server sends the appropriate GraphQL query or mutation to /graphql using a service JWT. Results serialised and returned as tool output.",
          "packages": ["p-mcp"],
          "edges": ["e-mcp-api", "e-api-db"]
        },
        {
          "title": "OpenAI composes response",
          "desc": "Tool result fed back to OpenAI; model writes a natural-language reply. iOS streams text via AVSpeechSynthesizer if voice mode is on.",
          "packages": ["p-web", "p-ios"],
          "edges": []
        }
      ]
    },
    {
      "id": "storefront-browse",
      "icon": "🛍",
      "name": "Storefront Browse",
      "path": "Storefront → API → PostgreSQL",
      "steps": [
        {
          "title": "Next.js SSR page loads",
          "desc": "Storefront server-side fetches devices({ where: { status: FOR_SALE } }) via GraphQL. No auth token — storefront is fully public.",
          "packages": ["p-storefront"],
          "edges": ["e-store-api"]
        },
        {
          "title": "API filters devices",
          "desc": "devices resolver queries DB with status filter. Auth-sensitive fields (priceAcquired, notes, whereAcquired) are excluded from the response for unauthenticated requests.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        },
        {
          "title": "HTML rendered and served",
          "desc": "Next.js renders the product grid to HTML. Umami analytics events fire in the browser when the user searches, filters, or sorts.",
          "packages": ["p-storefront"],
          "edges": []
        }
      ]
    },
    {
      "id": "orphaned-file-scan",
      "icon": "🔍",
      "name": "Orphaned File Scan & Delete",
      "path": "Web → API → /uploads + PostgreSQL",
      "steps": [
        {
          "title": "Admin opens Usage page",
          "desc": "orphanedFiles query fires lazily when the user opens the orphaned files section on /usage. Returns files on disk not referenced by any Image record.",
          "packages": ["p-web"],
          "edges": ["e-web-api"]
        },
        {
          "title": "API scans /uploads against DB",
          "desc": "Resolver walks /uploads directory tree and compares each file path against all Image.path and Image.thumbnailPath values in DB. Unreferenced paths returned as [OrphanedFile].",
          "packages": ["p-api"],
          "edges": ["e-api-db", "e-api-uploads"]
        },
        {
          "title": "Admin deletes selected files",
          "desc": "deleteOrphanedFiles(paths) mutation called with selected paths. Resolver calls fs.unlinkSync() on each path after verifying it's inside /uploads.",
          "packages": ["p-web"],
          "edges": ["e-web-api"]
        },
        {
          "title": "Files removed from disk",
          "desc": "API deletes each validated path from /uploads. Returns count of deleted files. No DB changes needed — these files had no DB record.",
          "packages": ["p-api"],
          "edges": ["e-api-uploads"]
        }
      ]
    },
    {
      "id": "generate-ai-image",
      "icon": "🎨",
      "name": "Generate AI Image",
      "path": "Web → REST /generate-image → API → OpenAI → /uploads → PostgreSQL",
      "steps": [
        {
          "title": "Admin triggers generation",
          "desc": "Web POSTs to /generate-image with { deviceId, prompt, model, sourceImageId? }. Returns { jobId } immediately.",
          "packages": ["p-web"],
          "edges": ["e-web-api"]
        },
        {
          "title": "API calls OpenAI",
          "desc": "If sourceImageId provided, the source image is converted to PNG and sent as an edit request. Otherwise a new generation is requested. Model is configurable (gpt-image-1.5 or gpt-image-2).",
          "packages": ["p-api"],
          "edges": []
        },
        {
          "title": "Generated image saved to /uploads",
          "desc": "OpenAI returns base64 image data. API decodes and writes to /uploads/devices/{deviceId}/{uuid}.png.",
          "packages": ["p-api"],
          "edges": ["e-api-uploads"]
        },
        {
          "title": "Image record created in DB",
          "desc": "createImage mutation called internally; thumbnailPath generated via sharp. Showcase flag set if this is a showcase image.",
          "packages": ["p-api"],
          "edges": ["e-api-db"]
        },
        {
          "title": "Client polls for completion",
          "desc": "Web polls GET /generate-image/status/:jobId. On completion, the new image appears in the device's photo gallery.",
          "packages": ["p-web"],
          "edges": ["e-web-api"]
        }
      ]
    }
  ]
}
```

- [ ] **Step 3: Verify valid JSON**

```bash
python3 -m json.tool /Users/wottle/Documents/Development/InvDifferent2/docs/architecture/flows.json > /dev/null && echo "Valid JSON"
```

Expected: `Valid JSON`

- [ ] **Step 4: Commit**

```bash
git -C /Users/wottle/Documents/Development/InvDifferent2 add docs/architecture/flows.json
git -C /Users/wottle/Documents/Development/InvDifferent2 commit -m "$(cat <<'EOF'
docs: add flows.json — authoritative app architecture flow data

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Create `docs/architecture/flows.html`

**Files:**
- Create: `docs/architecture/flows.html`

This is a self-contained HTML/CSS/JS file. It loads `flows.json` via `fetch('./flows.json')`, lays packages out by tier, draws SVG edges between them, and renders the flow list + step detail panel on the right.

**Layout algorithm:**
- Packages are grouped by tier: `client` (top row), `middleware` (mid-left), `api` (mid-center), `storage` (bottom row)
- After rendering, JS reads each package element's `getBoundingClientRect()` and draws SVG `<line>` elements connecting box edges (not centers)
- Edges are redrawn on `window.resize`

- [ ] **Step 1: Write `flows.html`**

Write this complete file to `docs/architecture/flows.html`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>InvDifferent — App Architecture Flows</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
  background: #0f1117;
  color: #e2e8f0;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  height: 100vh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* ── Top bar ── */
.topbar {
  background: #161b27;
  border-bottom: 1px solid #1e293b;
  padding: 10px 20px;
  display: flex;
  align-items: center;
  gap: 8px;
  flex-shrink: 0;
}
.topbar-title { font-size: 13px; font-weight: 700; color: #e2e8f0; }
.topbar-sub { font-size: 11px; color: #475569; }

/* ── Main ── */
.main { display: flex; flex: 1; overflow: hidden; }

/* ── Diagram ── */
.diagram-wrap {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px 32px;
  position: relative;
  overflow: hidden;
}

.diagram {
  position: relative;
  width: 100%;
  max-width: 600px;
  height: 100%;
  max-height: 420px;
}

/* SVG overlay for edges */
.diagram svg {
  position: absolute;
  top: 0; left: 0;
  width: 100%; height: 100%;
  pointer-events: none;
  overflow: visible;
}

/* Package tiers */
.tier {
  position: absolute;
  display: flex;
  gap: 10px;
  left: 0; right: 0;
  justify-content: center;
}
.tier-client     { top: 0; }
.tier-middleware { top: 42%; left: 0; right: auto; }
.tier-api        { top: 42%; left: 50%; transform: translateX(-50%); }
.tier-storage    { bottom: 0; }

/* Package box */
.pkg {
  background: #1a2235;
  border: 1.5px solid #2d3748;
  border-radius: 10px;
  padding: 8px 14px;
  text-align: center;
  cursor: default;
  transition: border-color 0.2s, background 0.2s, box-shadow 0.2s, opacity 0.2s;
  white-space: nowrap;
  flex-shrink: 0;
}
.pkg-name { font-size: 12px; font-weight: 700; color: #94a3b8; transition: color 0.2s; }
.pkg-sub  { font-size: 10px; color: #3d5068; margin-top: 1px; transition: color 0.2s; }

.pkg.state-active {
  border-color: #6366f1;
  background: #1e1b4b;
  box-shadow: 0 0 0 2px rgba(99,102,241,0.2), 0 0 18px rgba(99,102,241,0.12);
}
.pkg.state-active .pkg-name { color: #c7d2fe; }
.pkg.state-active .pkg-sub  { color: #6875d1; }
.pkg.state-dim { opacity: 0.25; }

/* tier-api gets a slightly larger border to denote it as the hub */
.tier-api .pkg { border-width: 2px; }

/* edge label badge */
.edge-badge {
  position: absolute;
  width: 18px; height: 18px;
  border-radius: 50%;
  background: #312e81;
  border: 1.5px solid #6366f1;
  color: #c7d2fe;
  font-size: 9px; font-weight: 800;
  display: flex; align-items: center; justify-content: center;
  pointer-events: none;
  box-shadow: 0 0 8px rgba(99,102,241,0.4);
  z-index: 10;
  transition: opacity 0.15s;
}

/* ── Right panel ── */
.panel {
  width: 300px;
  border-left: 1px solid #1e293b;
  display: flex;
  flex-direction: column;
  flex-shrink: 0;
  background: #0d1117;
  overflow: hidden;
}

.panel-label {
  padding: 11px 16px 5px;
  font-size: 9px;
  font-weight: 700;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: #334155;
  flex-shrink: 0;
}

/* Flow list */
.flow-list {
  overflow-y: auto;
  border-bottom: 1px solid #1e293b;
  max-height: 44%;
  flex-shrink: 0;
}

.flow-item {
  display: flex;
  align-items: flex-start;
  gap: 9px;
  padding: 8px 16px;
  cursor: pointer;
  transition: background 0.12s;
  border-left: 2px solid transparent;
}
.flow-item:hover { background: #161b27; }
.flow-item.selected { background: #1a1f35; border-left-color: #6366f1; }

.flow-icon {
  width: 24px; height: 24px;
  border-radius: 6px;
  background: #1e293b;
  display: flex; align-items: center; justify-content: center;
  font-size: 12px;
  flex-shrink: 0;
  margin-top: 1px;
  transition: background 0.15s;
}
.flow-item.selected .flow-icon { background: #312e81; }

.flow-info { flex: 1; min-width: 0; }
.flow-name { font-size: 12px; font-weight: 600; color: #94a3b8; }
.flow-item.selected .flow-name { color: #c7d2fe; }
.flow-path { font-size: 10px; color: #334155; margin-top: 1px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.flow-item.selected .flow-path { color: #4338ca; }

/* Steps */
.steps-scroll { flex: 1; overflow-y: auto; }
.steps-empty {
  padding: 24px 16px;
  font-size: 11px;
  color: #334155;
  text-align: center;
  line-height: 1.8;
}

.step-row {
  display: flex;
  gap: 10px;
  padding: 9px 16px;
  cursor: pointer;
  transition: background 0.12s;
  position: relative;
}
.step-row:hover { background: #161b27; }
.step-row.active { background: #1a1f35; }

.step-num {
  width: 19px; height: 19px;
  border-radius: 50%;
  border: 1.5px solid #2d3748;
  color: #4a5568;
  font-size: 9px; font-weight: 800;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
  margin-top: 1px;
  transition: border-color 0.15s, background 0.15s, color 0.15s;
}
.step-row.active .step-num { border-color: #6366f1; background: #312e81; color: #c7d2fe; }

.step-body { flex: 1; min-width: 0; }
.step-title { font-size: 11px; font-weight: 600; color: #64748b; }
.step-row.active .step-title { color: #a5b4fc; }
.step-desc { font-size: 10px; color: #334155; line-height: 1.5; margin-top: 2px; }
.step-row.active .step-desc { color: #64748b; }

.step-connector {
  position: absolute;
  left: 24px; top: 30px;
  width: 1px; height: calc(100% - 12px);
  background: #1e293b;
}

/* Error state */
.error-screen {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 100vh;
  gap: 16px;
  padding: 32px;
  text-align: center;
}
.error-screen h2 { font-size: 16px; color: #e2e8f0; }
.error-screen p  { font-size: 12px; color: #64748b; line-height: 1.7; max-width: 400px; }
.error-screen code {
  background: #1e293b;
  border: 1px solid #334155;
  border-radius: 6px;
  padding: 10px 16px;
  font-family: monospace;
  font-size: 12px;
  color: #a5b4fc;
  display: block;
  margin-top: 8px;
}
</style>
</head>
<body>

<div id="app"></div>

<script>
// ── State ──────────────────────────────────────────────────────────────────

var DATA = null;
var selectedFlow = null;
var activeStep = -1;
var pkgEls = {};     // id → DOM element
var svgEl = null;
var badgeEl = null;

// ── Boot ───────────────────────────────────────────────────────────────────

fetch('./flows.json')
  .then(function(r) {
    if (!r.ok) throw new Error('HTTP ' + r.status);
    return r.json();
  })
  .then(function(data) {
    DATA = data;
    renderApp();
  })
  .catch(function(err) {
    renderError(err);
  });

function renderError(err) {
  var app = document.getElementById('app');
  var h2 = document.createElement('h2');
  h2.textContent = 'Could not load flows.json';
  var p = document.createElement('p');
  p.textContent = 'This viewer must be opened through a local HTTP server. Open a terminal in docs/architecture/ and run:';
  var code = document.createElement('code');
  code.textContent = 'python3 -m http.server';
  var p2 = document.createElement('p');
  p2.textContent = 'Then open http://localhost:8000/flows.html';
  var detail = document.createElement('p');
  detail.textContent = 'Error: ' + (err && err.message ? err.message : String(err));
  detail.style.color = '#ef4444';
  detail.style.fontSize = '11px';
  var wrap = document.createElement('div');
  wrap.className = 'error-screen';
  wrap.appendChild(h2);
  wrap.appendChild(p);
  wrap.appendChild(code);
  wrap.appendChild(p2);
  wrap.appendChild(detail);
  app.appendChild(wrap);
}

// ── Render app shell ───────────────────────────────────────────────────────

function renderApp() {
  var app = document.getElementById('app');
  app.style.display = 'contents';

  // Topbar
  var topbar = document.createElement('div');
  topbar.className = 'topbar';
  var title = document.createElement('span');
  title.className = 'topbar-title';
  title.textContent = 'InvDifferent — App Architecture';
  var sub = document.createElement('span');
  sub.className = 'topbar-sub';
  sub.textContent = 'Select a flow to trace execution';
  topbar.appendChild(title);
  topbar.appendChild(sub);
  app.appendChild(topbar);

  // Main area
  var main = document.createElement('div');
  main.className = 'main';

  // Diagram wrap
  var diagramWrap = document.createElement('div');
  diagramWrap.className = 'diagram-wrap';
  var diagram = buildDiagram();
  diagramWrap.appendChild(diagram);
  main.appendChild(diagramWrap);

  // Right panel
  var panel = buildPanel();
  main.appendChild(panel);

  app.appendChild(main);

  // Draw edges after layout
  requestAnimationFrame(function() {
    requestAnimationFrame(function() {
      drawEdges();
    });
  });

  window.addEventListener('resize', function() {
    drawEdges();
  });
}

// ── Diagram ────────────────────────────────────────────────────────────────

function buildDiagram() {
  var diagram = document.createElement('div');
  diagram.className = 'diagram';
  diagram.id = 'diagram';

  // Group packages by tier
  var tiers = { client: [], middleware: [], api: [], storage: [] };
  DATA.packages.forEach(function(pkg) {
    if (tiers[pkg.tier]) tiers[pkg.tier].push(pkg);
  });

  // Render each tier
  Object.keys(tiers).forEach(function(tier) {
    var pkgs = tiers[tier];
    if (!pkgs.length) return;
    var row = document.createElement('div');
    row.className = 'tier tier-' + tier;
    pkgs.forEach(function(pkg) {
      var el = document.createElement('div');
      el.className = 'pkg';
      el.id = 'pkg-' + pkg.id;
      var nameEl = document.createElement('div');
      nameEl.className = 'pkg-name';
      nameEl.textContent = pkg.name;
      var subEl = document.createElement('div');
      subEl.className = 'pkg-sub';
      subEl.textContent = pkg.sub;
      el.appendChild(nameEl);
      el.appendChild(subEl);
      row.appendChild(el);
      pkgEls[pkg.id] = el;
    });
    diagram.appendChild(row);
  });

  // SVG layer for edges
  var ns = 'http://www.w3.org/2000/svg';
  svgEl = document.createElementNS(ns, 'svg');
  svgEl.id = 'diagram-svg';

  // Arrow marker
  var defs = document.createElementNS(ns, 'defs');
  var markerDefault = makeMarker(ns, 'arr-default', '#2d3748');
  var markerActive  = makeMarker(ns, 'arr-active',  '#6366f1');
  defs.appendChild(markerDefault);
  defs.appendChild(markerActive);
  svgEl.appendChild(defs);
  diagram.appendChild(svgEl);

  // Edge label badge
  badgeEl = document.createElement('div');
  badgeEl.className = 'edge-badge';
  badgeEl.style.display = 'none';
  diagram.appendChild(badgeEl);

  return diagram;
}

function makeMarker(ns, id, color) {
  var marker = document.createElementNS(ns, 'marker');
  marker.setAttribute('id', id);
  marker.setAttribute('markerWidth', '7');
  marker.setAttribute('markerHeight', '5');
  marker.setAttribute('refX', '6');
  marker.setAttribute('refY', '2.5');
  marker.setAttribute('orient', 'auto');
  var poly = document.createElementNS(ns, 'polygon');
  poly.setAttribute('points', '0 0, 7 2.5, 0 5');
  poly.setAttribute('fill', color);
  marker.appendChild(poly);
  return marker;
}

function drawEdges() {
  if (!DATA || !svgEl) return;

  // Remove existing edge lines
  var existing = svgEl.querySelectorAll('line.edge');
  existing.forEach(function(el) { el.parentNode.removeChild(el); });

  var diagramEl = document.getElementById('diagram');
  var diagramRect = diagramEl.getBoundingClientRect();

  DATA.edges.forEach(function(edge) {
    var fromEl = pkgEls[edge.from];
    var toEl   = pkgEls[edge.to];
    if (!fromEl || !toEl) return;

    var fr = fromEl.getBoundingClientRect();
    var tr = toEl.getBoundingClientRect();

    // Convert to diagram-relative coordinates
    var fx = fr.left + fr.width / 2  - diagramRect.left;
    var fy = fr.top  + fr.height     - diagramRect.top;
    var tx = tr.left + tr.width / 2  - diagramRect.left;
    var ty = tr.top                  - diagramRect.top;

    // For side-by-side connections (middleware → api), use side edges
    if (Math.abs(fr.top - tr.top) < 30) {
      fx = (fr.left < tr.left) ? fr.right - diagramRect.left : fr.left - diagramRect.left;
      fy = fr.top + fr.height / 2 - diagramRect.top;
      tx = (fr.left < tr.left) ? tr.left - diagramRect.left : tr.right - diagramRect.left;
      ty = tr.top + tr.height / 2 - diagramRect.top;
    }

    var ns = 'http://www.w3.org/2000/svg';
    var line = document.createElementNS(ns, 'line');
    line.setAttribute('id', 'edge-' + edge.id);
    line.setAttribute('class', 'edge');
    line.setAttribute('x1', fx);
    line.setAttribute('y1', fy);
    line.setAttribute('x2', tx);
    line.setAttribute('y2', ty);
    line.setAttribute('stroke', '#2d3748');
    line.setAttribute('stroke-width', '1.5');
    line.setAttribute('marker-end', 'url(#arr-default)');
    svgEl.appendChild(line);
  });

  // Re-apply current highlight state
  applyDiagramState(selectedFlow, activeStep);
}

// ── Diagram state ──────────────────────────────────────────────────────────

function applyDiagramState(flow, stepIdx) {
  // Reset all packages
  DATA.packages.forEach(function(pkg) {
    var el = pkgEls[pkg.id];
    if (!el) return;
    el.classList.remove('state-active', 'state-dim');
  });

  // Reset all edges
  DATA.edges.forEach(function(edge) {
    var el = document.getElementById('edge-' + edge.id);
    if (!el) return;
    el.setAttribute('stroke', '#2d3748');
    el.setAttribute('stroke-width', '1.5');
    el.setAttribute('marker-end', 'url(#arr-default)');
    el.classList.remove('edge-active');
  });

  // Hide badge
  badgeEl.style.display = 'none';

  if (!flow) return;

  // Determine which packages and edges are active
  var activePkgIds, activeEdgeIds;
  if (stepIdx >= 0 && flow.steps[stepIdx]) {
    var step = flow.steps[stepIdx];
    activePkgIds  = step.packages || [];
    activeEdgeIds = step.edges    || [];
  } else {
    // Whole-flow preview: highlight all packages and edges in the flow
    activePkgIds  = flow.steps.reduce(function(acc, s) {
      (s.packages || []).forEach(function(p) { if (acc.indexOf(p) < 0) acc.push(p); });
      return acc;
    }, []);
    activeEdgeIds = flow.steps.reduce(function(acc, s) {
      (s.edges || []).forEach(function(e) { if (acc.indexOf(e) < 0) acc.push(e); });
      return acc;
    }, []);
  }

  // Apply package states
  DATA.packages.forEach(function(pkg) {
    var el = pkgEls[pkg.id];
    if (!el) return;
    var inFlow   = activePkgIds.indexOf(pkg.id) >= 0;
    var inAll    = flow.steps.some(function(s) { return (s.packages || []).indexOf(pkg.id) >= 0; });
    if (inFlow) {
      el.classList.add('state-active');
    } else if (!inAll) {
      el.classList.add('state-dim');
    }
  });

  // Apply edge states
  DATA.edges.forEach(function(edge) {
    var el = document.getElementById('edge-' + edge.id);
    if (!el) return;
    var inFlow = activeEdgeIds.indexOf(edge.id) >= 0;
    var inAll  = flow.steps.some(function(s) { return (s.edges || []).indexOf(edge.id) >= 0; });
    if (inFlow) {
      el.setAttribute('stroke', '#6366f1');
      el.setAttribute('stroke-width', '2.5');
      el.setAttribute('marker-end', 'url(#arr-active)');
    } else if (!inAll) {
      el.setAttribute('stroke', '#1a2235');
    }
  });

  // Show step badge on first active edge midpoint
  if (stepIdx >= 0 && activeEdgeIds.length > 0) {
    var firstEdge = document.getElementById('edge-' + activeEdgeIds[0]);
    if (firstEdge) {
      var x1 = parseFloat(firstEdge.getAttribute('x1'));
      var y1 = parseFloat(firstEdge.getAttribute('y1'));
      var x2 = parseFloat(firstEdge.getAttribute('x2'));
      var y2 = parseFloat(firstEdge.getAttribute('y2'));
      var mx = (x1 + x2) / 2;
      var my = (y1 + y2) / 2;
      badgeEl.style.left    = (mx - 9) + 'px';
      badgeEl.style.top     = (my - 9) + 'px';
      badgeEl.style.display = 'flex';
      badgeEl.textContent   = stepIdx + 1;
    }
  }
}

// ── Right panel ────────────────────────────────────────────────────────────

var stepsScrollEl = null;

function buildPanel() {
  var panel = document.createElement('div');
  panel.className = 'panel';

  var flowLabel = document.createElement('div');
  flowLabel.className = 'panel-label';
  flowLabel.textContent = 'Flows';

  var flowList = document.createElement('div');
  flowList.className = 'flow-list';
  flowList.id = 'flow-list';

  DATA.flows.forEach(function(flow) {
    flowList.appendChild(buildFlowItem(flow));
  });

  var stepsLabel = document.createElement('div');
  stepsLabel.className = 'panel-label';
  stepsLabel.id = 'steps-label';
  stepsLabel.textContent = 'Steps';
  stepsLabel.style.display = 'none';

  var stepsScroll = document.createElement('div');
  stepsScroll.className = 'steps-scroll';
  stepsScroll.id = 'steps-scroll';
  stepsScrollEl = stepsScroll;

  var empty = document.createElement('div');
  empty.className = 'steps-empty';
  empty.id = 'steps-empty';
  empty.textContent = '← Select a flow to trace\nhow data moves through\nthe system';
  stepsScroll.appendChild(empty);

  panel.appendChild(flowLabel);
  panel.appendChild(flowList);
  panel.appendChild(stepsLabel);
  panel.appendChild(stepsScroll);

  return panel;
}

function buildFlowItem(flow) {
  var item = document.createElement('div');
  item.className = 'flow-item';
  item.setAttribute('data-flow-id', flow.id);

  var iconEl = document.createElement('div');
  iconEl.className = 'flow-icon';
  iconEl.textContent = flow.icon;

  var info = document.createElement('div');
  info.className = 'flow-info';

  var name = document.createElement('div');
  name.className = 'flow-name';
  name.textContent = flow.name;

  var path = document.createElement('div');
  path.className = 'flow-path';
  path.textContent = flow.path;

  info.appendChild(name);
  info.appendChild(path);
  item.appendChild(iconEl);
  item.appendChild(info);

  item.addEventListener('mouseenter', function() {
    if (!selectedFlow || selectedFlow.id !== flow.id) {
      applyDiagramState(flow, -1);
    }
  });
  item.addEventListener('mouseleave', function() {
    applyDiagramState(selectedFlow, activeStep);
  });
  item.addEventListener('click', function() {
    selectFlow(flow.id);
  });

  return item;
}

function selectFlow(id) {
  selectedFlow = DATA.flows.find(function(f) { return f.id === id; }) || null;
  activeStep = -1;

  // Update flow list selection state
  document.querySelectorAll('.flow-item').forEach(function(el) {
    var isSelected = el.getAttribute('data-flow-id') === id;
    if (isSelected) {
      el.classList.add('selected');
    } else {
      el.classList.remove('selected');
    }
  });

  renderSteps(selectedFlow);
  applyDiagramState(selectedFlow, activeStep);
}

function renderSteps(flow) {
  var scroll = document.getElementById('steps-scroll');
  var label  = document.getElementById('steps-label');
  var empty  = document.getElementById('steps-empty');

  // Clear existing step rows
  var rows = scroll.querySelectorAll('.step-row');
  rows.forEach(function(r) { r.parentNode.removeChild(r); });

  if (!flow) {
    if (empty) empty.style.display = '';
    if (label) label.style.display = 'none';
    return;
  }

  if (empty) empty.style.display = 'none';
  if (label) label.style.display = '';

  flow.steps.forEach(function(step, i) {
    var row = buildStepRow(step, i, flow.steps.length);
    scroll.appendChild(row);
  });
}

function buildStepRow(step, i, total) {
  var row = document.createElement('div');
  row.className = 'step-row' + (i === activeStep ? ' active' : '');
  row.setAttribute('data-step-index', i);

  if (i < total - 1) {
    var connector = document.createElement('div');
    connector.className = 'step-connector';
    row.appendChild(connector);
  }

  var num = document.createElement('div');
  num.className = 'step-num';
  num.textContent = i + 1;

  var body = document.createElement('div');
  body.className = 'step-body';

  var titleEl = document.createElement('div');
  titleEl.className = 'step-title';
  titleEl.textContent = step.title;

  var descEl = document.createElement('div');
  descEl.className = 'step-desc';
  descEl.textContent = step.desc;

  body.appendChild(titleEl);
  body.appendChild(descEl);
  row.appendChild(num);
  row.appendChild(body);

  row.addEventListener('click', function() {
    var idx = parseInt(row.getAttribute('data-step-index'), 10);
    activeStep = idx;

    // Update active class on all rows
    var allRows = document.querySelectorAll('.step-row');
    allRows.forEach(function(r) {
      if (parseInt(r.getAttribute('data-step-index'), 10) === idx) {
        r.classList.add('active');
      } else {
        r.classList.remove('active');
      }
    });

    applyDiagramState(selectedFlow, activeStep);
  });

  return row;
}
</script>
</body>
</html>
```

- [ ] **Step 2: Verify the file was written**

```bash
wc -l /Users/wottle/Documents/Development/InvDifferent2/docs/architecture/flows.html
```

Expected: output showing 300+ lines.

- [ ] **Step 3: Start a local server and verify it loads**

```bash
cd /Users/wottle/Documents/Development/InvDifferent2/docs/architecture && python3 -m http.server 8765 &
sleep 1 && curl -s http://localhost:8765/flows.json | python3 -m json.tool > /dev/null && echo "flows.json served OK"
```

Expected: `flows.json served OK`

Kill the server when done:
```bash
kill $(lsof -ti :8765) 2>/dev/null || true
```

- [ ] **Step 4: Commit**

```bash
git -C /Users/wottle/Documents/Development/InvDifferent2 add docs/architecture/flows.html
git -C /Users/wottle/Documents/Development/InvDifferent2 commit -m "$(cat <<'EOF'
docs: add flows.html — interactive architecture flow diagram viewer

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Update `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Read the current end of CLAUDE.md to find the insertion point**

Read `CLAUDE.md` and find the last section heading. The new section goes at the end, before any trailing newline.

- [ ] **Step 2: Add the "App Flow Reference" section**

Insert this block at the end of `CLAUDE.md` (after the last existing section):

```markdown
## App Flow Reference

`docs/architecture/flows.json` is the authoritative source for how data moves between packages in this app. **Read it before implementing any feature that touches more than one package.**

### When to update `flows.json`

- **Adding a new user-facing action**: add a new entry to the `flows` array with accurate `steps`, `packages`, and `edges` references.
- **Changing how a feature works** (new endpoint, new package involved, changed data path): update the relevant flow's steps to match the new implementation.
- **Removing a feature**: remove its flow entry.

Updates to `flows.json` must be made in the same commit as the code change — never leave them for later.

### Viewing the diagram

```bash
cd docs/architecture && python3 -m http.server
```

Then open `http://localhost:8000/flows.html` in a browser. Click a flow in the right panel to highlight the packages and edges involved. Click individual steps to trace the exact path.

### JSON schema reference

| Key | Purpose |
|-----|---------|
| `packages[].id` | Unique identifier used in edge `from`/`to` and step `packages` arrays |
| `packages[].tier` | Layout tier: `client` \| `middleware` \| `api` \| `storage` |
| `edges[].id` | Unique identifier used in step `edges` arrays |
| `flows[].steps[].packages` | Package IDs active during this step (highlighted on diagram) |
| `flows[].steps[].edges` | Edge IDs active during this step (glowing arrows on diagram) |
```

- [ ] **Step 3: Commit**

```bash
git -C /Users/wottle/Documents/Development/InvDifferent2 add CLAUDE.md
git -C /Users/wottle/Documents/Development/InvDifferent2 commit -m "$(cat <<'EOF'
docs(claude-md): add App Flow Reference section pointing agents to flows.json

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Notes

- **Spec coverage**: all three files from the spec are created/modified. CLAUDE.md instructions match the spec exactly. flows.json contains all 19 flows listed in the spec's "Initial Flow Coverage" section (some merged where logically one action, e.g. edit/delete note → separate flows could be added later without a schema change).
- **No placeholders**: all steps contain complete file content or complete bash commands with expected output.
- **Type consistency**: `flow.steps[i].packages` and `flow.steps[i].edges` are arrays of strings throughout — consistent across flows.json schema definition and the HTML JS that reads them.
- **file:// limitation**: explicitly handled with a user-facing error screen in flows.html.
