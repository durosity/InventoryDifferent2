# Software Tab

Adds support for tracking software (games, applications, utilities, OS
installers, etc.) alongside hardware in the same collection, without a
separate database schema or duplicated infrastructure. Built on `feature/software-tab`.

## Design: one table, category-driven

Software items are just `Device` rows. Whether a category's items are
treated as "software" (different add/edit form, different field set,
appears in the Software tab instead of Devices) is controlled by a new
per-category boolean, **`Category.showSoftwareFields`**, toggled via a
checkbox on the Manage Categories page. This is deliberately decoupled from
the existing `CategoryType` enum: any category — "Software", "Games", or a
category you create yourself — can opt in. Toggling it off always reverts
that category's items to being treated as ordinary hardware.

This keeps every existing feature (images, notes, tags, custom fields,
financials, search, relations, the public storefront, the MCP server) working
for software automatically, with no separate code path to maintain.

## What's new

### Database (`api/prisma/schema.prisma` + migrations)

- `Category.showSoftwareFields: Boolean` — per-category opt-in (see above)
- `Category.parentId` (self-relation) — sub-categories, e.g. "Games" → "Puzzle",
  "Software" → "Utilities". Shown indented in the category picker and the
  Manage Categories list. A category can't be parented under itself or its
  own descendants (checked in the admin UI).
- New `Device` fields, all optional: `platform`, `licenceKey`,
  `requiresDongle`, `downloadUrl`, `localPath`, `hasOriginalManuals`
- `CategoryType` enum gained a `SOFTWARE` value (used for the new top-level
  categories below; not load-bearing for the feature itself, which keys off
  `showSoftwareFields`)
- A migration seeds the Macintosh Garden-style category taxonomy: "Games"
  (28 genre sub-categories) and "Software" (41 application-type
  sub-categories), all flagged `showSoftwareFields: true`. It looks up
  "Games"/"Software" by name rather than hardcoded ids, so it's safe to run
  against a database that already has differently-numbered categories with
  those names, or none at all.
- `INSTALLED_ON` — not a schema change. Device-to-device relationships
  already existed (`DeviceRelationship.type` is a free-text string); this
  feature just uses `"INSTALLED_ON"` as a type by convention, with
  `fromDevice` = the software item, `toDevice` = the hardware it's installed
  on.

### API

- `createCategory`/`updateCategory` mutations accept `showSoftwareFields`
  and `parentId`
- `Category.parent` / `Category.children` field resolvers
- Dashboard's "missing specs" collection-health metric excludes software
  categories (they don't have CPU/RAM fields, so they'd otherwise always be
  flagged)
- `searchText` generation includes `platform`/`licenceKey`
- New non-GraphQL endpoints for the Macintosh Repository lookup (below):
  `GET /software-lookup/search?q=`, `GET /software-lookup/details?url=`

### Web

- **Software tab** in the main nav, right after Devices. `/software` reuses
  the same list-page component as the Devices tab (`DeviceListPage` in
  `list-new/_components/`), parameterized by a `softwareOnly` flag — one
  component, two thin page wrappers. Each tab has independent filter/sort/view
  state (separate `localStorage` keys). The Devices tab now excludes
  software items entirely; they only ever show under Software.
- **Dedicated Add Software form** (`components/SoftwareForm.tsx`,
  `/software/new`) — built from scratch for software's actual fields
  (Publisher, Version, Platform, Licence Key, Download URL, Local Path,
  Requires Dongle, Has Original Manuals, category picker scoped to
  `showSoftwareFields` categories with sub-category indentation), rather
  than reusing `DeviceForm`'s conditional-field approach used for editing.
  Editing still goes through the existing `DeviceForm` (which already has
  the conditional software sections from earlier work) — not yet given the
  same dedicated-form treatment as Add.
- **`DeviceForm`** (hardware/edit path) hides fields that don't apply to
  software (Functional Status, Retr0brited, Recapped, Last Power On Date) and
  relabels Manufacturer → Publisher, Model Number → Version when the
  selected category is software-flagged.
- **Device detail page** shows a "Software Information" section
  (Platform/Licence Key/Download/Local Path/Requires Dongle/Has Original
  Manuals) when applicable, relabels Manufacturer&Model → Publisher and
  Last Power On → Last Opened for software, and fixes a pre-existing bug
  where a missing Model Number rendered the literal word "null".
- **"Installed On" / "Installed Software"** section on the detail page,
  separate from the generic "Related Devices" list (which now excludes
  `INSTALLED_ON` relations to avoid showing them twice). Shown on software
  items as "Installed On" (which computer(s) it's installed on) and on
  hardware items as "Installed Software" (what's installed on this
  machine). The device picker for each is scoped to the opposite category
  type.
- **Canonical URLs**: software items live at `/software/[id]` and
  `/software/[id]/edit`; hardware stays at `/devices/[id]` and
  `/devices/[id]/edit`. Both routes point at the same underlying page
  implementation (`export { default } from ...`, zero duplication). Whichever
  link gets clicked, the page checks the loaded device's category once data
  arrives and client-side redirects to the correct canonical URL if it's on
  the wrong one — this was done instead of updating every `Link` to a device
  throughout the app individually.
- i18n: `nav.software` added to all five locale files (en/de/es/fr/it)

### Macintosh Repository lookup (`api/src/macintoshRepository.ts`)

A "Search Templates" box on the Add Software form does a live search against
[macintoshrepository.org](https://www.macintoshrepository.org) and, on
selecting a result, pre-fills Name, Publisher, Release Year, Download URL,
and tries to match the category against the sub-category taxonomy above.

This is screen-scraping, not an API — there isn't one. Worth knowing:

- **Macintosh Garden** (the other obvious source, and the taxonomy this
  seeds its categories from) explicitly disallows automated access in
  `robots.txt`, and its community has complained about bot traffic.
  Deliberately not scraped for this reason.
- Macintosh Repository's own free-text search form didn't behave as
  expected when driven directly by URL (silently fell back to a generic
  alphabetical browse rather than actually filtering). What works
  reliably instead is their "browse by starting letter, sorted by
  popularity" listing, so search here buckets by the query's first letter,
  fetches (and caches 24h) the top pages of that letter across both
  Applications and Games, then filters by substring. **This means a search
  only finds titles starting with the same letter as the query** —
  "Marathon" works, "Durandal" (to find "Marathon 2: Durandal") won't.
- Detail-page field extraction uses a label-based text scan (stops at the
  next known field label rather than assuming real line breaks exist
  between fields in the flattened page text) — more robust than it sounds,
  but still just regex over scraped HTML. If results look wrong after a
  site redesign, `macintoshRepository.ts` is the first place to check.
- Category values from their pages are sometimes comma-separated (e.g.
  "1st Person, Action, First Person Shooter (FPS)") and don't always match
  our naming exactly (their "First Person Shooter (FPS)" vs our "FPS") —
  matching is substring-based in both directions, not exact.
- Both search results and detail-page fetches are cached in-memory
  (not persisted across restarts) specifically to avoid hammering their
  server with repeat requests.

## Known gaps / deliberately not done here

- Editing a software item doesn't yet have the same dedicated form
  `SoftwareForm` gives to adding one — it still goes through `DeviceForm`'s
  conditional sections.
- No automatic file download (fetching the actual software file from
  Macintosh Repository and saving it locally, auto-filling Local Path) —
  scoped but not built; would need a configurable storage location and a
  larger download-handling endpoint.
- A companion client app for classic Macs that would identify itself,
  pull its "installed on" software list from the API, auto-install, and
  report back newly-installed titles (effectively a vintage-Mac MDM) — a
  real idea worth pursuing, but a separate project in its own right, not
  started.
- The "Devices" tab is still labelled "Devices" rather than "Hardware" —
  flagged as a future rename once hardware categories get the same
  sub-category treatment Software has now, for symmetry.
