# Photo Editing Feature Design

**Date:** 2026-05-25  
**Status:** Approved

## Problem

Device photos are uploaded and displayed as-is (with auto-rotation via EXIF only). Users need basic non-destructive editing — 90° rotation and free-form crop — to correct orientation and remove unwanted borders without losing the original image.

## Goals

- Rotate (90° increments) and crop (free-form, any aspect ratio) device photos
- Non-destructive: original file always preserved and restorable
- Edits reflected everywhere: admin gallery, thumbnails, storefront, iOS app
- Export/import carries transform metadata; import gracefully handles absent metadata

## Out of Scope

- Arbitrary-angle rotation
- Brightness/contrast/color editing
- Filters

---

## Architecture

### Non-Destructive via Pre-Baked Display Copies

When the user saves edits, the API applies Sharp transforms **once** and writes a "display copy" to `uploads/devices/{deviceId}/display/{uuid}.{ext}`. The `path` field is updated to point to this copy. The original is preserved in a new `originalPath` field.

Static file serving is unchanged — no new serving layer needed.

**Undo:** `resetImageEdits` restores `path = originalPath` and clears all transform fields.

**Why not on-the-fly transforms?** Static serving is simpler, and iOS cache invalidation is natural (new URL = new cache entry). For a personal inventory app, the one-time processing cost on save is negligible.

---

## Data Model

### New fields on `Image` model (Prisma)

| Field | Type | Notes |
|---|---|---|
| `originalPath` | `String?` | Path to untouched original. Null = never edited. Set on first edit. |
| `rotation` | `Int` default `0` | Clockwise degrees: 0, 90, 180, or 270 |
| `cropLeft` | `Float?` | 0.0–1.0 relative x offset of crop rect |
| `cropTop` | `Float?` | 0.0–1.0 relative y offset |
| `cropWidth` | `Float?` | 0.0–1.0 relative width (null = no crop) |
| `cropHeight` | `Float?` | 0.0–1.0 relative height (null = no crop) |

Relative (0–1) coordinates are resolution-independent.

### New GraphQL mutations

```graphql
editImage(id: Int!, rotation: Int!, cropLeft: Float, cropTop: Float, cropWidth: Float, cropHeight: Float): Image!
resetImageEdits(id: Int!): Image!
```

---

## API Transform Logic

### `applyImageTransforms(sourceFile, rotation, crop, outputPath)` helper

1. `sharp(sourceFile).rotate(rotation)` — Sharp's native 90° rotation
2. If crop fields present: `sharp.metadata()` to get pixel dims → `.extract({ left: cropLeft*w, top: cropTop*h, width: cropWidth*w, height: cropHeight*h })`
3. `.toFile(outputPath)`

Rotation is applied before crop (crop coords are in rotated space).

### `editImage` resolver

1. Load image from DB
2. `sourceFile = diskPath(originalPath ?? path)`
3. If `originalPath` is null → set `originalPath = path` (lock in backup on first edit)
4. `displayPath = uploads/devices/{deviceId}/display/{uuid}.{originalExt}`
5. `applyImageTransforms(sourceFile, rotation, crop, displayPath)`
6. Regenerate thumbnail using same transforms + resize/webp pipeline
7. Update DB: `path = displayPath`, store `originalPath`, rotation, crop fields
8. Return updated image

### `resetImageEdits` resolver

1. Load image; require `originalPath`
2. Delete current display copy from disk
3. Regenerate thumbnail from `originalPath` (no transforms)
4. Update DB: `path = originalPath`, `originalPath = null`, `rotation = 0`, crop fields = null
5. Return updated image

### Export/import

**Export:** When `originalPath` is set, include the original file in the ZIP at `devices/{deviceId}/originals/{filename}`. Add transform metadata to each image entry in the manifest JSON.

**Import:** If transform metadata present in manifest → restore `originalPath`, call `applyImageTransforms` to reconstruct display copy. If absent → import as-is (backwards-compatible).

---

## Web UI

### `ImageGallery.tsx`

Add a centered "Edit" button (pencil/crop icon) to the thumbnail hover overlay (alongside the four existing corner action buttons). Clicking opens `EditImageModal`.

### `EditImageModal.tsx` (new component)

- Loads source image from `originalPath ?? path` (always edits from original)
- **Rotate:** "Rotate Left" / "Rotate Right" buttons (lucide-react `RotateCcw`/`RotateCw`); shows current angle
- **Crop:** `react-image-crop` library in percentage mode (maps directly to 0–1 fields)
- **Buttons:**
  - "Save Edits" → `editImage` mutation → close → gallery refetch
  - "Reset to Original" → `resetImageEdits` → only shown when `originalPath` is non-null
  - "Cancel" → no API call
- All strings through i18n (en/de/fr/es)

### New i18n keys (section: `images`)

```
editPhoto, rotateLeft, rotateRight, saveEdits, resetToOriginal, editPhotoTitle
```

### Dependency

```
npm install react-image-crop   (in web/)
```

---

## iOS UI

### `ImageManagementView.swift`

Add "Edit Photo" button navigating to `EditPhotoView`.

### `EditPhotoView.swift` (new view)

- Loads source image from `originalPath ?? path` via `ImageCacheService`
- **Rotate:** "Rotate Left" / "Rotate Right" buttons → in-memory `rotation: Int` → SwiftUI `.rotationEffect` preview
- **Crop:** Custom SwiftUI crop view:
  - `GeometryReader` + `ZStack` with image underneath
  - Semi-transparent overlay with clear `Rectangle` crop rect
  - Four corner handles via `DragGesture`, clamped to image bounds
- **Actions:**
  - "Save" → `editImage` mutation → `ImageCacheService.removeImage(for: oldURL)` → dismiss + reload
  - "Reset to Original" → `resetImageEdits` → remove old URL from cache → dismiss
  - "Cancel" → dismiss, no API call

**Cache invalidation:** `path` changes to a new filename on save → iOS naturally fetches fresh. Old path explicitly removed from `ImageCacheService`.

### New translation keys

```
editPhoto, rotateLeft, rotateRight, saveEdits, resetToOriginal
```
(Add to `Translations.swift`, `Translations+en.swift`, `Translations+de.swift`, `Translations+fr.swift`)

---

## Files to Create

| File | Purpose |
|---|---|
| `web/src/components/EditImageModal.tsx` | Crop/rotate editor modal |
| `ios/.../Views/EditPhotoView.swift` | iOS crop/rotate editor |

## Files to Modify

| File | Change |
|---|---|
| `api/prisma/schema.prisma` | Add 6 fields to Image model |
| `api/src/typeDefs.ts` | Extend Image type, add 2 mutations |
| `api/src/resolvers.ts` | Add `applyImageTransforms`, `editImage`, `resetImageEdits` |
| `api/src/index.ts` | Export: include originalPath + transform metadata; Import: re-apply transforms |
| `web/src/components/ImageGallery.tsx` | Add centered Edit button to hover overlay |
| `web/src/i18n/translations/en.ts` + `de.ts` + `fr.ts` + `es.ts` | Add image editing strings |
| `ios/.../Views/ImageManagementView.swift` | Add "Edit Photo" navigation button |
| `ios/.../i18n/Translations.swift` + `+en` + `+de` + `+fr` | Add edit translation keys |
| `web/src/lib/releaseNotes.ts` + `CHANGELOG.md` | Unreleased entry |
| `docs/architecture/flows.html` | Add photo editing flow |

---

## Verification Checklist

1. Upload image → `originalPath` is null
2. Edit (rotate + crop) → `originalPath` set, `path` points to `display/` copy, thumbnail updated
3. Re-open editor → shows *original* image
4. Reset to Original → `path = originalPath`, transforms cleared, thumbnail regenerated
5. Export to ZIP → manifest has transform fields, both files present
6. Import ZIP on clean device → display copy reconstructed correctly
7. iOS: full flow, cache invalidation works
8. Storefront: edited image displayed correctly
