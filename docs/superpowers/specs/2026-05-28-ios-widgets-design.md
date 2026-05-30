# iOS Widgets — Design Spec
**Date:** 2026-05-28

## Context

Users who open the app less frequently (or who use widgets to *replace* some app opens) need a way to see their collection at a glance from the home screen. Three widget types address the main motivations: tracking collection size/value (Stats), enjoying the collection passively (Spotlight), and following new acquisitions (Recent).

---

## Widget Family

| Widget | Sizes | Tap action | Refresh |
|---|---|---|---|
| **Stats** | Small, Medium, Large | `inventorydifferent://stats` | Every 30 min |
| **Spotlight** | Small, Medium, Large | `inventorydifferent://devices/{id}` | Daily at midnight |
| **Recent Additions** | Medium | `inventorydifferent://devices/{id}` per row (via `Link`) | Every 30 min |

### Stats widget content
- **Small**: total device count + estimated value
- **Medium**: 4 stats — total devices, estimated value, working %, for sale count
- **Large**: 6 stats (+ total spent, in-repair count) + horizontal status breakdown bars (Collection / For Sale / Sold / In Repair)

### Spotlight widget content
- Picks one device per day at midnight; random weighted selection — favorites have 3× weight vs. non-favorites
- Eligible pool: devices with status `COLLECTION`, `FOR_SALE`, `PENDING_SALE`, or `IN_REPAIR` (exclude `SOLD`, `DONATED`, `RETURNED`)
- Falls back to full eligible pool if user has no favorites
- **Small**: thumbnail fills widget, name + year text overlay
- **Medium**: thumbnail fills widget, overlay shows "Today's Highlight" label, name, manufacturer · year · CPU, estimated value
- **Large**: top 62% image, bottom panel with name, manufacturer · year, spec chips, estimated value

### Recent Additions widget content
- **Medium**: 3 most recently added devices — thumbnail emoji placeholder (or actual thumbnail if available), name, manufacturer · year, relative age ("today", "3d", "1w")
- Each row is an individual `Link` deep-linking to that device

### Typography — Spotlight widget
Wide-spaced minimal style:
- Label ("Today's Highlight"): `font-weight: .light`, letter spacing +0.22em, uppercase, 35% opacity white
- Device name: `font-weight: .light`, letter spacing +0.04em, ~19–20pt
- Manufacturer/year: uppercase, letter spacing +0.12em, 35% opacity, ~10–11pt
- Estimated value: letter spacing +0.04em, `Color(.green)`, medium weight, ~11pt

---

## Architecture

### App Group
Identifier: `group.com.wottle.InventoryDifferent`

Add this entitlement to both the main app target and the widget extension target in `InventoryDifferent.xcodeproj`.

### Shared data between app and widget

| Data | Current storage | Change needed |
|---|---|---|
| Server URL | `UserDefaults.standard` key `serverURL` | Migrate to `UserDefaults(suiteName: "group.com.wottle.InventoryDifferent")` in `AppSettings.swift` |
| `isConfigured` flag | `UserDefaults.standard` | Same migration |
| JWT access token | Keychain key `inv_access_token` | Add `kSecAttrAccessGroup` to all Keychain read/write calls in `AuthService.swift`. The access group value uses the team ID prefix: `$(AppIdentifierPrefix)group.com.wottle.InventoryDifferent` — configure via the Keychain Sharing capability, not hardcoded. |
| JWT refresh token | Keychain key `inv_refresh_token` | Same |
| Token expiry | Keychain key `inv_token_expiry` | Same |

### Widget data fetching
The widget extension contains a lightweight `WidgetAPIService` (mirrors the existing `APIService.swift` pattern) that:
1. Reads server URL from shared `UserDefaults` suite
2. Reads access token from shared Keychain access group
3. Makes a GraphQL POST to `{serverURL}/graphql`
4. On 401, attempts a token refresh via `POST {serverURL}/auth/refresh` using the shared refresh token, stores the new access token back to shared Keychain, then retries
5. On continued failure, returns the last cached response (stored in shared `UserDefaults` as JSON) with a `lastUpdated` timestamp

`WidgetAuthService` encapsulates steps 2–4.

### Offline / error state
Each widget caches its last successful API response as JSON in shared `UserDefaults`. If the API is unreachable, the widget renders the cached data with a "Last updated X ago" footer. First-launch with no cache shows a placeholder skeleton with the app name and a "Open app to connect" message.

---

## GraphQL Queries

**Stats widget** — reuse existing `collectionStats` query plus `financialOverview` for total-spent:
```graphql
query WidgetStats {
  collectionStats { totalDevices workingPercentage byStatus { status count } }
  financialOverview { totalSpent estimatedValueOwned }
  devices(where: { status: FOR_SALE }) { id }
  devices(where: { status: IN_REPAIR }) { id }
}
```
*(Aggregate counts client-side from the status breakdown if collectionStats already provides them.)*

**Spotlight widget** — fetch eligible device pool (IDs + name + images + flags), pick random weighted on-device:
```graphql
query WidgetSpotlight {
  devices(where: { status_in: [COLLECTION, FOR_SALE, PENDING_SALE, IN_REPAIR] }) {
    id name additionalName manufacturer releaseYear estimatedValue
    functionalStatus isFavorite
    images(where: { isThumbnail: true }) { thumbnailPath }
    cpu ram
  }
}
```

**Recent Additions widget**:
```graphql
query WidgetRecent {
  devices(orderBy: { dateAcquired: desc }, take: 5) {
    id name manufacturer releaseYear dateAcquired
    images(where: { isThumbnail: true }) { thumbnailPath }
  }
}
```

---

## Deep Linking

The URL scheme `inventorydifferent://` already exists. One new route is needed:

In `InventoryDifferentApp.swift`, add handling for `inventorydifferent://stats` in the existing `onOpenURL` block — navigate to `StatsView`.

Existing `inventorydifferent://devices/{id}` routing covers Spotlight and Recent item taps with no changes.

---

## Files

### New — widget extension target (`InventoryDifferentWidgets/`)
```
ios/InventoryDifferent/InventoryDifferentWidgets/
  InventoryDifferentWidgets.swift      # @main WidgetBundle
  StatsWidget.swift                    # Provider + Entry + Views (sm/md/lg)
  SpotlightWidget.swift                # Provider + Entry + Views (sm/md/lg)
  RecentWidget.swift                   # Provider + Entry + View (md)
  WidgetAPIService.swift               # URLSession GraphQL client for widget
  WidgetAuthService.swift              # Shared Keychain token read + refresh
  Models/WidgetData.swift              # Codable structs: WidgetStatsData, WidgetSpotlightData, WidgetRecentData
```

### Modified — main app
| File | Change |
|---|---|
| `Services/AppSettings.swift` | Migrate `serverURL` + `isConfigured` to `UserDefaults(suiteName:)` |
| `Services/AuthService.swift` | Add `kSecAttrAccessGroup` to all Keychain queries |
| `InventoryDifferentApp.swift` | Add `inventorydifferent://stats` deep-link route |
| `InventoryDifferent.xcodeproj` | Add widget extension target, App Group entitlement to both targets |

### i18n note
Widget views cannot use the app's `LocalizationManager` (different process). Use `String(localized:)` with a `Localizable.strings` file inside the widget extension target. Labels needed: "Today's Highlight", "Recent Additions", "Devices", "Est. Value", "Working", "For Sale", "In Repair", "Total Spent", "Last updated", "Open app to connect".

---

## Verification

1. Build the widget extension target — confirm it compiles with no errors
2. Run on an iOS 16+ simulator; long-press the home screen → add widget → confirm all 3 widget types appear with all size options
3. **Stats**: add medium widget, verify counts match what's in the app
4. **Spotlight**: add medium widget, verify it shows a device from the eligible pool; verify it changes the next day (advance simulator clock)
5. **Recent**: add medium widget, add a new device in the app, background the app, verify widget updates within 30 minutes (or force-refresh via Xcode's widget debug menu)
6. **Offline**: disable network, verify cached data renders with "Last updated" timestamp
7. **Deep links**: tap Stats widget → lands on StatsView; tap Spotlight → lands on correct device detail; tap a Recent row → lands on that device detail
8. **Auth migration**: delete and reinstall app; log in; confirm widget can still fetch (shared Keychain working)
9. Run `xcodebuild` for both app and widget targets — confirm BUILD SUCCEEDED
