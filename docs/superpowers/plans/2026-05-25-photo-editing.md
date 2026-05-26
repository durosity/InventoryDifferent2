# Photo Editing Feature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add non-destructive rotate (90° increments) and free-form crop to device images, on both web admin and iOS, with edits stored as metadata and pre-baked to a display copy via Sharp.

**Architecture:** When the user saves edits, the API applies Sharp transforms once (rotate then crop) to generate a display copy under `uploads/devices/{id}/display/`. The original is preserved in `originalPath`. Clients always load `path` (which becomes the display copy after editing). Undo is a `resetImageEdits` mutation that restores `path = originalPath`.

**Tech Stack:** Prisma/PostgreSQL (schema), Sharp (transform), GraphQL (mutations), React + `react-image-crop` (web editor), SwiftUI + Canvas API (iOS editor), express-static (unchanged file serving).

---

## File Map

| Status | Path | Purpose |
|---|---|---|
| Modify | `api/prisma/schema.prisma` | Add 6 fields to Image model |
| Modify | `api/src/typeDefs.ts` | Extend Image type + 2 mutations |
| Modify | `api/src/resolvers.ts` | Add `applyImageTransforms`, `editImage`, `resetImageEdits` |
| Modify | `api/src/index.ts` | ZIP export/import: originalPath + transform metadata |
| Create | `web/src/components/EditImageModal.tsx` | Crop/rotate editor modal |
| Modify | `web/src/components/ImageGallery.tsx` | Add centered Edit button to hover overlay; extend Image interface |
| Modify | `web/src/app/devices/[id]/photos/page.tsx` | Add new fields to GQL query |
| Modify | `web/src/i18n/translations/en.ts` + `de.ts` + `fr.ts` + `es.ts` | Image editing strings in `detail` section |
| Create | `ios/.../Views/EditPhotoView.swift` | SwiftUI crop/rotate editor |
| Modify | `ios/.../Views/ImageManagementView.swift` | Add "Edit Photo" button |
| Modify | `ios/.../Models/Device.swift` | Add optional fields to `DeviceImage` |
| Modify | `ios/.../Services/DeviceService.swift` | Add image fields to queries; add `editImage`/`resetImageEdits` methods |
| Modify | `ios/.../i18n/Translations.swift` | Add keys to `ImageManagementT` |
| Modify | `ios/.../i18n/Translations+en.swift` + `+de.swift` + `+fr.swift` | Values |
| Modify | `web/src/lib/releaseNotes.ts` + `CHANGELOG.md` | Unreleased entry |
| Modify | `docs/architecture/flows.html` | Add photo editing flow |

---

## Task 1: Prisma Schema + GraphQL Types

**Files:**
- Modify: `api/prisma/schema.prisma`
- Modify: `api/src/typeDefs.ts`

- [ ] **Step 1.1: Add fields to Image model in schema.prisma**

In `api/prisma/schema.prisma`, extend the `Image` model (after `duration Int?` on line 170):

```prisma
  originalPath  String?
  rotation      Int     @default(0)
  cropLeft      Float?
  cropTop       Float?
  cropWidth     Float?
  cropHeight    Float?
```

- [ ] **Step 1.2: Run migration**

```bash
cd api && npx prisma migrate dev --name add_image_edit_transforms
```

Expected: migration file created and applied, `npx prisma generate` runs automatically.

If you see "drift detected" warnings, run `npx prisma migrate reset --force` in a dev environment (do NOT do this in production).

- [ ] **Step 1.3: Add fields to Image type in typeDefs.ts**

In `api/src/typeDefs.ts`, find `type Image {` (line 157) and add after `duration: Int`:

```graphql
    originalPath: String
    rotation: Int!
    cropLeft: Float
    cropTop: Float
    cropWidth: Float
    cropHeight: Float
```

- [ ] **Step 1.4: Add new mutations to typeDefs.ts**

Find the `Mutation` type in `typeDefs.ts`. Add after the `deleteImage` mutation (around line 851):

```graphql
    editImage(id: Int!, rotation: Int!, cropLeft: Float, cropTop: Float, cropWidth: Float, cropHeight: Float): Image!
    resetImageEdits(id: Int!): Image!
```

- [ ] **Step 1.5: Build API to verify types compile**

```bash
cd api && npm run build 2>&1 | tail -5
```

Expected: `Found 0 errors.`

- [ ] **Step 1.6: Commit**

```bash
git add api/prisma/schema.prisma api/prisma/migrations/ api/src/typeDefs.ts
git commit -m "$(cat <<'EOF'
feat: add image edit transform fields to schema and GraphQL types

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `applyImageTransforms` Helper

**Files:**
- Modify: `api/src/resolvers.ts`

- [ ] **Step 2.1: Add helper function in resolvers.ts**

Add this function in `api/src/resolvers.ts` directly after the `generateVideoThumbnail` function (after line ~223, before `export const resolvers = {`):

```typescript
export async function applyImageTransforms(
    sourceFile: string,
    rotation: number,
    crop: { left: number; top: number; width: number; height: number } | null,
    outputPath: string
): Promise<void> {
    await fs.promises.mkdir(path.dirname(outputPath), { recursive: true });

    if (crop) {
        // Determine post-rotation dimensions without decoding pixels.
        // Sharp's metadata() returns original dimensions; EXIF orientations 5-8
        // swap width/height, as does 90° or 270° user rotation.
        const meta = await sharp(sourceFile).metadata();
        const exifSwaps = meta.orientation !== undefined && meta.orientation >= 5;
        let imgW = meta.width ?? 0;
        let imgH = meta.height ?? 0;
        if (exifSwaps) [imgW, imgH] = [imgH, imgW];
        if (rotation === 90 || rotation === 270) [imgW, imgH] = [imgH, imgW];

        let pipeline = sharp(sourceFile).rotate(); // EXIF auto-orient
        if (rotation !== 0) pipeline = pipeline.rotate(rotation);
        await pipeline
            .extract({
                left:   Math.max(0, Math.round(crop.left   * imgW)),
                top:    Math.max(0, Math.round(crop.top    * imgH)),
                width:  Math.max(1, Math.round(crop.width  * imgW)),
                height: Math.max(1, Math.round(crop.height * imgH)),
            })
            .toFile(outputPath);
    } else {
        let pipeline = sharp(sourceFile).rotate();
        if (rotation !== 0) pipeline = pipeline.rotate(rotation);
        await pipeline.toFile(outputPath);
    }
}
```

- [ ] **Step 2.2: Build API to verify no TypeScript errors**

```bash
cd api && npm run build 2>&1 | tail -5
```

Expected: `Found 0 errors.`

---

## Task 3: `editImage` Resolver

**Files:**
- Modify: `api/src/resolvers.ts`

- [ ] **Step 3.1: Add editImage to the Mutation resolvers**

Find `Mutation: {` in `api/src/resolvers.ts`. After the `deleteImage` resolver, add:

```typescript
        editImage: async (_parent: any, args: any, context: Context) => {
            if (!context.isAuthenticated) throw new Error('Not authenticated');

            const { id, rotation, cropLeft, cropTop, cropWidth, cropHeight } = args;
            const image = await context.prisma.image.findUniqueOrThrow({ where: { id } });

            // Determine source: always the untouched original
            const sourceApiPath: string = image.originalPath ?? image.path;
            const sourceDiskPath = path.join('/app/uploads', sourceApiPath.replace('/uploads/', ''));

            if (!sourceDiskPath.startsWith('/app/uploads') || !fs.existsSync(sourceDiskPath)) {
                throw new Error('Source image not found on disk');
            }

            // Lock in originalPath on first edit
            const originalApiPath: string = image.originalPath ?? image.path;

            // Build display copy path
            const ext = path.posix.extname(sourceApiPath) || '.jpg';
            const displayDir = `/uploads/devices/${image.deviceId}/display`;
            const displayBasename = require('crypto').randomUUID();
            const displayApiPath = `${displayDir}/${displayBasename}${ext}`;
            const displayDiskPath = path.join('/app/uploads', displayDir.replace('/uploads/', ''), `${displayBasename}${ext}`);

            // Crop object (null if no crop specified)
            const hasCrop = cropLeft != null && cropTop != null && cropWidth != null && cropHeight != null;
            const cropArg = hasCrop ? { left: cropLeft, top: cropTop, width: cropWidth, height: cropHeight } : null;

            // Apply transforms to display copy
            await applyImageTransforms(sourceDiskPath, rotation ?? 0, cropArg, displayDiskPath);

            // Regenerate thumbnail from display copy at standard thumbs location
            const thumbDir = `/app/uploads/devices/${image.deviceId}/thumbs`;
            fs.mkdirSync(thumbDir, { recursive: true });
            const thumbDiskPath = path.join(thumbDir, `${displayBasename}.webp`);
            const thumbApiPath = `/uploads/devices/${image.deviceId}/thumbs/${displayBasename}.webp`;
            await sharp(displayDiskPath)
                .rotate()
                .resize({ width: 320, height: 320, fit: 'inside', withoutEnlargement: true })
                .webp({ quality: 70 })
                .toFile(thumbDiskPath);

            // Update DB
            return context.prisma.image.update({
                where: { id },
                data: {
                    path: displayApiPath,
                    thumbnailPath: thumbApiPath,
                    originalPath: originalApiPath,
                    rotation: rotation ?? 0,
                    cropLeft:   hasCrop ? cropLeft   : null,
                    cropTop:    hasCrop ? cropTop    : null,
                    cropWidth:  hasCrop ? cropWidth  : null,
                    cropHeight: hasCrop ? cropHeight : null,
                },
            });
        },
```

- [ ] **Step 3.2: Build and verify**

```bash
cd api && npm run build 2>&1 | tail -5
```

Expected: `Found 0 errors.`

- [ ] **Step 3.3: Commit**

```bash
git add api/src/resolvers.ts
git commit -m "$(cat <<'EOF'
feat(api): add editImage mutation with Sharp transform pipeline

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `resetImageEdits` Resolver

**Files:**
- Modify: `api/src/resolvers.ts`

- [ ] **Step 4.1: Add resetImageEdits resolver**

After the `editImage` resolver (still inside `Mutation: {`), add:

```typescript
        resetImageEdits: async (_parent: any, args: any, context: Context) => {
            if (!context.isAuthenticated) throw new Error('Not authenticated');

            const { id } = args;
            const image = await context.prisma.image.findUniqueOrThrow({ where: { id } });

            if (!image.originalPath) throw new Error('Image has no edits to reset');

            // Delete current display copy
            const displayDiskPath = path.join('/app/uploads', image.path.replace('/uploads/', ''));
            if (displayDiskPath.startsWith('/app/uploads') && fs.existsSync(displayDiskPath)) {
                try { fs.unlinkSync(displayDiskPath); } catch {}
            }

            // Delete current thumbnail
            if (image.thumbnailPath) {
                const thumbDiskPath = path.join('/app/uploads', image.thumbnailPath.replace('/uploads/', ''));
                if (thumbDiskPath.startsWith('/app/uploads') && fs.existsSync(thumbDiskPath)) {
                    try { fs.unlinkSync(thumbDiskPath); } catch {}
                }
            }

            // Regenerate thumbnail from original using existing helper
            const newThumbPath = await generateThumbnailForUpload(image.originalPath);

            // Restore original path, clear all transform fields
            return context.prisma.image.update({
                where: { id },
                data: {
                    path: image.originalPath,
                    thumbnailPath: newThumbPath,
                    originalPath: null,
                    rotation: 0,
                    cropLeft: null,
                    cropTop: null,
                    cropWidth: null,
                    cropHeight: null,
                },
            });
        },
```

- [ ] **Step 4.2: Build and verify**

```bash
cd api && npm run build 2>&1 | tail -5
```

Expected: `Found 0 errors.`

- [ ] **Step 4.3: Commit**

```bash
git add api/src/resolvers.ts
git commit -m "$(cat <<'EOF'
feat(api): add resetImageEdits mutation to restore original

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Export/Import Changes

**Files:**
- Modify: `api/src/index.ts`

The ZIP export serialises image metadata to a manifest JSON. The import reads that manifest. Both need to carry `originalPath` and transform fields.

- [ ] **Step 5.1: Find the export manifest image serialization**

Search for where image metadata is written to the manifest during export:

```bash
grep -n "originalPath\|thumbnailPath\|isShopImage" /Users/wottle/Documents/Development/InvDifferent2/api/src/index.ts | head -20
```

Locate the object where image fields are written to the manifest (will look like `{ id, path, thumbnailPath, ... }`).

- [ ] **Step 5.2: Add transform fields to export manifest**

In the export manifest image serialization, add the new fields:

```typescript
// Add these fields to the existing image manifest object:
originalPath: image.originalPath ?? null,
rotation: image.rotation,
cropLeft: image.cropLeft ?? null,
cropTop: image.cropTop ?? null,
cropWidth: image.cropWidth ?? null,
cropHeight: image.cropHeight ?? null,
```

- [ ] **Step 5.3: Add originalPath file to ZIP export**

Find where images are added to the ZIP archive during export. After adding the current `path` file, add the original file if it exists:

```typescript
// After the existing code that adds image.path to the ZIP:
if (image.originalPath) {
    const origDisk = path.join('/app/uploads', image.originalPath.replace('/uploads/', ''));
    if (fs.existsSync(origDisk)) {
        const origInZip = `devices/${device.id}/originals/${path.basename(image.originalPath)}`;
        zip.addLocalFile(origDisk, path.dirname(origInZip), path.basename(origInZip));
    }
}
```

- [ ] **Step 5.4: Find the import image restore section**

```bash
grep -n "thumbnailPath\|createImage\|image\.path" /Users/wottle/Documents/Development/InvDifferent2/api/src/index.ts | grep -v "\/\/" | head -30
```

Locate where images are restored from the manifest and written to the DB during import.

- [ ] **Step 5.5: Apply transforms on import if metadata present**

After an image record is created/updated during import, add transform re-application:

```typescript
// After the image record is created (prisma.image.create/update call):
const imgManifest = manifestImage; // the manifest object for this image
if (imgManifest.originalPath && imgManifest.rotation != null) {
    // Restore original file if it was included in the ZIP
    const origInZip = `devices/${device.id}/originals/${path.basename(imgManifest.originalPath)}`;
    const origZipEntry = zip.getEntry(origInZip);
    if (origZipEntry) {
        const origApiPath = `/uploads/devices/${device.id}/${path.basename(imgManifest.originalPath)}`;
        const origDiskPath = path.join('/app/uploads', `devices/${device.id}`, path.basename(imgManifest.originalPath));
        fs.mkdirSync(path.dirname(origDiskPath), { recursive: true });
        fs.writeFileSync(origDiskPath, origZipEntry.getData());

        // Reconstruct display copy via transforms
        const hasCrop = imgManifest.cropWidth != null;
        const cropArg = hasCrop
            ? { left: imgManifest.cropLeft, top: imgManifest.cropTop, width: imgManifest.cropWidth, height: imgManifest.cropHeight }
            : null;
        const ext = path.posix.extname(origApiPath) || '.jpg';
        const displayDir = `/uploads/devices/${device.id}/display`;
        const displayBasename = require('crypto').randomUUID();
        const displayApiPath = `${displayDir}/${displayBasename}${ext}`;
        const displayDiskPath = path.join('/app/uploads', `devices/${device.id}/display`, `${displayBasename}${ext}`);
        await applyImageTransforms(origDiskPath, imgManifest.rotation, cropArg, displayDiskPath);

        // Regenerate thumbnail
        const thumbDiskDir = `/app/uploads/devices/${device.id}/thumbs`;
        fs.mkdirSync(thumbDiskDir, { recursive: true });
        const thumbDiskPath = path.join(thumbDiskDir, `${displayBasename}.webp`);
        const thumbApiPath = `/uploads/devices/${device.id}/thumbs/${displayBasename}.webp`;
        await sharp(displayDiskPath)
            .rotate()
            .resize({ width: 320, height: 320, fit: 'inside', withoutEnlargement: true })
            .webp({ quality: 70 })
            .toFile(thumbDiskPath);

        // Update the image record with display copy + original
        await context.prisma.image.update({
            where: { id: createdImage.id },
            data: {
                path: displayApiPath,
                thumbnailPath: thumbApiPath,
                originalPath: origApiPath,
                rotation: imgManifest.rotation,
                cropLeft: imgManifest.cropLeft ?? null,
                cropTop: imgManifest.cropTop ?? null,
                cropWidth: imgManifest.cropWidth ?? null,
                cropHeight: imgManifest.cropHeight ?? null,
            },
        });
    }
}
```

Note: `applyImageTransforms` is exported from `resolvers.ts` — import it in `index.ts` if not already done (check existing imports at top of `index.ts`).

- [ ] **Step 5.6: Import applyImageTransforms in index.ts if needed**

```bash
grep -n "from.*resolvers" /Users/wottle/Documents/Development/InvDifferent2/api/src/index.ts | head -5
```

If `applyImageTransforms` is not in the existing import, add it:

```typescript
import { resolvers, generateThumbnailForUpload, applyImageTransforms } from './resolvers.js';
```

- [ ] **Step 5.7: Build and verify**

```bash
cd api && npm run build 2>&1 | tail -5
```

Expected: `Found 0 errors.`

- [ ] **Step 5.8: Commit**

```bash
git add api/src/index.ts
git commit -m "$(cat <<'EOF'
feat(api): include original file and transform metadata in ZIP export/import

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Web `EditImageModal` Component

**Files:**
- Create: `web/src/components/EditImageModal.tsx`

- [ ] **Step 6.1: Install react-image-crop**

```bash
cd web && npm install react-image-crop
```

Expected: package added to `package.json`.

- [ ] **Step 6.2: Create EditImageModal.tsx**

Create `web/src/components/EditImageModal.tsx`:

```tsx
"use client";

import { useMutation } from "@apollo/client";
import gql from "graphql-tag";
import { useState, useRef, useCallback, useEffect } from "react";
import ReactCrop, { type PercentCrop } from "react-image-crop";
import "react-image-crop/dist/ReactCrop.css";
import { RotateCcw, RotateCw, X } from "lucide-react";
import { API_BASE_URL } from "../lib/config";
import { useT } from "../i18n/context";

const EDIT_IMAGE = gql`
  mutation EditImage(
    $id: Int!, $rotation: Int!,
    $cropLeft: Float, $cropTop: Float, $cropWidth: Float, $cropHeight: Float
  ) {
    editImage(id: $id, rotation: $rotation, cropLeft: $cropLeft, cropTop: $cropTop, cropWidth: $cropWidth, cropHeight: $cropHeight) {
      id path thumbnailPath originalPath rotation cropLeft cropTop cropWidth cropHeight
    }
  }
`;

const RESET_IMAGE_EDITS = gql`
  mutation ResetImageEdits($id: Int!) {
    resetImageEdits(id: $id) {
      id path thumbnailPath originalPath rotation cropLeft cropTop cropWidth cropHeight
    }
  }
`;

export interface EditableImage {
  id: number;
  path: string;
  originalPath?: string | null;
  rotation?: number | null;
  cropLeft?: number | null;
  cropTop?: number | null;
  cropWidth?: number | null;
  cropHeight?: number | null;
}

interface Props {
  image: EditableImage;
  onClose: () => void;
  onSaved: () => void;
}

export function EditImageModal({ image, onClose, onSaved }: Props) {
  const t = useT();

  // Always edit from the original source image
  const sourceUrl = `${API_BASE_URL}${image.originalPath ?? image.path}`;

  const [rotation, setRotation] = useState<number>(image.rotation ?? 0);
  const [crop, setCrop] = useState<PercentCrop | undefined>(
    image.cropLeft != null && image.cropWidth != null
      ? { unit: "%", x: (image.cropLeft ?? 0) * 100, y: (image.cropTop ?? 0) * 100,
          width: (image.cropWidth ?? 1) * 100, height: (image.cropHeight ?? 1) * 100 }
      : undefined
  );
  // previewUrl is a canvas-rotated version of the source; used in the crop editor
  const [previewUrl, setPreviewUrl] = useState<string>(sourceUrl);
  const hiddenImgRef = useRef<HTMLImageElement>(null);

  const generatePreview = useCallback((deg: number) => {
    const img = hiddenImgRef.current;
    if (!img || !img.complete || img.naturalWidth === 0) return;
    if (deg === 0) { setPreviewUrl(sourceUrl); return; }
    const swap = deg === 90 || deg === 270;
    const canvas = document.createElement("canvas");
    canvas.width  = swap ? img.naturalHeight : img.naturalWidth;
    canvas.height = swap ? img.naturalWidth  : img.naturalHeight;
    const ctx = canvas.getContext("2d")!;
    ctx.translate(canvas.width / 2, canvas.height / 2);
    ctx.rotate((deg * Math.PI) / 180);
    ctx.drawImage(img, -img.naturalWidth / 2, -img.naturalHeight / 2);
    setPreviewUrl(canvas.toDataURL());
  }, [sourceUrl]);

  // Re-generate preview whenever rotation changes (after image is loaded)
  useEffect(() => { generatePreview(rotation); }, [rotation, generatePreview]);

  const handleRotate = (delta: number) => {
    const next = (rotation + delta + 360) % 360;
    setRotation(next);
    setCrop(undefined); // reset crop: coordinates are in the rotated space
  };

  const [editImage, { loading: saving }] = useMutation(EDIT_IMAGE);
  const [resetImageEdits, { loading: resetting }] = useMutation(RESET_IMAGE_EDITS);

  const handleSave = async () => {
    const hasCrop = crop && crop.width > 0 && crop.height > 0;
    await editImage({
      variables: {
        id: image.id,
        rotation,
        cropLeft:   hasCrop ? crop!.x      / 100 : null,
        cropTop:    hasCrop ? crop!.y      / 100 : null,
        cropWidth:  hasCrop ? crop!.width  / 100 : null,
        cropHeight: hasCrop ? crop!.height / 100 : null,
      },
    });
    onSaved();
    onClose();
  };

  const handleReset = async () => {
    await resetImageEdits({ variables: { id: image.id } });
    onSaved();
    onClose();
  };

  const busy = saving || resetting;
  const isEdited = !!image.originalPath;

  return (
    <div
      className="fixed inset-0 bg-black/80 flex items-center justify-center z-50 p-4"
      onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
    >
      {/* Hidden reference image — loaded once for canvas rotation */}
      <img ref={hiddenImgRef} src={sourceUrl} alt="" style={{ display: "none" }}
        onLoad={() => generatePreview(rotation)} />

      <div className="bg-white dark:bg-gray-900 rounded-xl w-full max-w-2xl flex flex-col gap-4 p-6 max-h-[90vh] overflow-y-auto">
        {/* Header */}
        <div className="flex items-center justify-between">
          <h2 className="text-lg font-semibold dark:text-white">{t.detail.editPhotoTitle}</h2>
          <button onClick={onClose} disabled={busy}
            className="p-1 rounded text-gray-400 hover:text-gray-600 dark:hover:text-gray-200">
            <X size={20} />
          </button>
        </div>

        {/* Rotate controls */}
        <div className="flex items-center gap-2">
          <button onClick={() => handleRotate(270)} disabled={busy}
            className="flex items-center gap-1.5 px-3 py-2 text-sm bg-gray-100 dark:bg-gray-800 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 disabled:opacity-50">
            <RotateCcw size={15} /> {t.detail.rotateLeft}
          </button>
          <button onClick={() => handleRotate(90)} disabled={busy}
            className="flex items-center gap-1.5 px-3 py-2 text-sm bg-gray-100 dark:bg-gray-800 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 disabled:opacity-50">
            <RotateCw size={15} /> {t.detail.rotateRight}
          </button>
          <span className="ml-auto text-sm text-gray-400">{rotation}°</span>
        </div>

        {/* Crop editor */}
        <div className="flex justify-center">
          <ReactCrop crop={crop} onChange={(_, pc) => setCrop(pc)} style={{ maxHeight: "50vh" }}>
            <img src={previewUrl} alt="Edit"
              style={{ maxHeight: "50vh", maxWidth: "100%", display: "block" }} />
          </ReactCrop>
        </div>

        {/* Actions */}
        <div className="flex items-center gap-2 justify-end pt-2 border-t border-gray-200 dark:border-gray-700">
          {isEdited && (
            <button onClick={handleReset} disabled={busy}
              className="px-3 py-2 text-sm text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg disabled:opacity-50 mr-auto">
              {t.detail.resetToOriginal}
            </button>
          )}
          <button onClick={onClose} disabled={busy}
            className="px-4 py-2 text-sm bg-gray-100 dark:bg-gray-800 rounded-lg hover:bg-gray-200 disabled:opacity-50">
            {t.common.cancel}
          </button>
          <button onClick={handleSave} disabled={busy}
            className="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50">
            {saving ? "…" : t.detail.saveEdits}
          </button>
        </div>
      </div>
    </div>
  );
}
```

- [ ] **Step 6.3: Build web to verify**

```bash
cd web && npm run build 2>&1 | tail -10
```

Expected: build succeeds (may have warnings; errors are failures).

- [ ] **Step 6.4: Commit**

```bash
git add web/src/components/EditImageModal.tsx web/package.json web/package-lock.json
git commit -m "$(cat <<'EOF'
feat(web): add EditImageModal with rotate and crop editor

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Web ImageGallery + i18n + Photos Query

**Files:**
- Modify: `web/src/components/ImageGallery.tsx`
- Modify: `web/src/app/devices/[id]/photos/page.tsx`
- Modify: `web/src/i18n/translations/en.ts`, `de.ts`, `fr.ts`, `es.ts`

- [ ] **Step 7.1: Add i18n keys to all 4 translation files**

In `web/src/i18n/translations/en.ts`, find the `detail:` section type block (line ~230). Add these keys to the `detail` type definition block:

```typescript
    editPhotoTitle: string;
    rotateLeft: string;
    rotateRight: string;
    saveEdits: string;
    resetToOriginal: string;
```

Find the `detail:` values block (around line 1200+, the second instance after the type definitions). Add the English values:

```typescript
    editPhotoTitle: "Edit Photo",
    rotateLeft: "Rotate Left",
    rotateRight: "Rotate Right",
    saveEdits: "Save Edits",
    resetToOriginal: "Reset to Original",
```

In `web/src/i18n/translations/de.ts`, add to the `detail` values section:

```typescript
    editPhotoTitle: "Foto bearbeiten",
    rotateLeft: "Links drehen",
    rotateRight: "Rechts drehen",
    saveEdits: "Änderungen speichern",
    resetToOriginal: "Zum Original zurücksetzen",
```

In `web/src/i18n/translations/fr.ts`, add to the `detail` values section:

```typescript
    editPhotoTitle: "Modifier la photo",
    rotateLeft: "Tourner à gauche",
    rotateRight: "Tourner à droite",
    saveEdits: "Enregistrer",
    resetToOriginal: "Restaurer l'original",
```

In `web/src/i18n/translations/es.ts`, add to the `detail` values section:

```typescript
    editPhotoTitle: "Editar foto",
    rotateLeft: "Girar a la izquierda",
    rotateRight: "Girar a la derecha",
    saveEdits: "Guardar cambios",
    resetToOriginal: "Restaurar original",
```

- [ ] **Step 7.2: Extend Image interface in ImageGallery.tsx**

In `web/src/components/ImageGallery.tsx`, extend the `Image` interface (around line 26):

```typescript
interface Image {
    id: number;
    path: string;
    thumbnailPath?: string | null;
    caption: string | null;
    isThumbnail: boolean;
    thumbnailMode?: string | null;
    isShopImage: boolean;
    isListingImage: boolean;
    mediaType?: string | null;
    duration?: number | null;
    // Edit fields
    originalPath?: string | null;
    rotation?: number | null;
    cropLeft?: number | null;
    cropTop?: number | null;
    cropWidth?: number | null;
    cropHeight?: number | null;
}
```

- [ ] **Step 7.3: Add editImageId state and EditImageModal import to ImageGallery.tsx**

At the top of `ImageGallery.tsx`, add the import:

```typescript
import { EditImageModal, type EditableImage } from "./EditImageModal";
```

Inside `export function ImageGallery(...)`, add state:

```typescript
const [editImageId, setEditImageId] = useState<number | null>(null);
const editTarget = editImageId !== null ? images.find(i => i.id === editImageId) ?? null : null;
```

- [ ] **Step 7.4: Add centered Edit button to hover overlay**

In `ImageGallery.tsx`, find the hover overlay div with class `grid grid-cols-2 grid-rows-2` (around line 216). The grid has 4 corner cells. Add a centered button using absolute positioning within the overlay div (the `absolute inset-0` div):

Replace the hover overlay opening div (currently `<div className="absolute inset-0 bg-black/0 group-hover:bg-black/40 ...">`) to include a relative position, and add the centered edit button inside it, before the `grid`:

```tsx
{/* Hover overlay with actions */}
<div className="absolute inset-0 bg-black/0 group-hover:bg-black/40 transition-colors opacity-0 group-hover:opacity-100 p-2 relative">
    {/* Centered edit button */}
    {image.mediaType !== 'VIDEO' && (
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
            <button
                onClick={(e) => { e.stopPropagation(); setEditImageId(image.id); }}
                className="pointer-events-auto p-2 bg-white/90 rounded-full text-gray-700 hover:bg-white transition-colors shadow-sm"
                title="Edit photo"
            >
                <svg width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2}
                        d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                </svg>
            </button>
        </div>
    )}
    <div className="w-full h-full grid grid-cols-2 grid-rows-2">
        {/* ... existing 4 corner buttons unchanged ... */}
    </div>
</div>
```

- [ ] **Step 7.5: Add EditImageModal to ImageGallery render**

At the bottom of the ImageGallery return statement (before the final closing `</div>`), add:

```tsx
{/* Edit image modal */}
{editTarget && (
    <EditImageModal
        image={editTarget}
        onClose={() => setEditImageId(null)}
        onSaved={() => { setEditImageId(null); onImagesChanged(); }}
    />
)}
```

- [ ] **Step 7.6: Update photos page GraphQL query**

In `web/src/app/devices/[id]/photos/page.tsx`, update the `GET_DEVICE_PHOTOS` query (line 16) to include new fields:

```graphql
const GET_DEVICE_PHOTOS = gql`
  query GetDevicePhotos($where: DeviceWhereInput!) {
    device(where: $where) {
      id
      name
      images {
        id
        path
        thumbnailPath
        originalPath
        rotation
        cropLeft
        cropTop
        cropWidth
        cropHeight
        caption
        dateTaken
        isThumbnail
        thumbnailMode
        isShopImage
        isListingImage
        mediaType
        duration
      }
    }
  }
`;
```

- [ ] **Step 7.7: Build web to verify**

```bash
cd web && npm run build 2>&1 | tail -10
```

Expected: succeeds.

- [ ] **Step 7.8: Commit**

```bash
git add web/src/components/ImageGallery.tsx web/src/app/devices/[id]/photos/page.tsx \
  web/src/i18n/translations/en.ts web/src/i18n/translations/de.ts \
  web/src/i18n/translations/fr.ts web/src/i18n/translations/es.ts
git commit -m "$(cat <<'EOF'
feat(web): wire edit button in image gallery and add i18n strings

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: iOS Model + Service

**Files:**
- Modify: `ios/.../Models/Device.swift`
- Modify: `ios/.../Services/DeviceService.swift`

- [ ] **Step 8.1: Extend DeviceImage struct**

In `ios/.../Models/Device.swift`, extend `DeviceImage` (line 177) to add optional fields:

```swift
struct DeviceImage: Codable, Identifiable {
    let id: Int
    let path: String
    let thumbnailPath: String?
    let dateTaken: String?
    let caption: String?
    let isShopImage: Bool
    let isThumbnail: Bool
    let thumbnailMode: String?
    let isListingImage: Bool
    let mediaType: String
    let duration: Int?
    // Edit fields — all optional so compact queries (omitting these fields) still decode
    let originalPath: String?
    let rotation: Int?
    let cropLeft: Double?
    let cropTop: Double?
    let cropWidth: Double?
    let cropHeight: Double?
}
```

- [ ] **Step 8.2: Add new fields to the device detail image query**

In `ios/.../Services/DeviceService.swift`, find every `images {` block that lists `duration` (full image queries, not compact ones). Add the 6 new fields after `duration`:

```graphql
                    originalPath
                    rotation
                    cropLeft
                    cropTop
                    cropWidth
                    cropHeight
```

Use this command to find the locations:
```bash
grep -n "duration" /Users/wottle/Documents/Development/InvDifferent2/ios/InventoryDifferent/InventoryDifferent/Services/DeviceService.swift
```

Update all occurrences where `duration` appears inside an `images {}` block (not compact `{ id thumbnailPath isThumbnail }` blocks — skip those).

- [ ] **Step 8.3: Add editImage service method**

In `ios/.../Services/DeviceService.swift`, after the `deleteImage` method, add:

```swift
    func editImage(id: Int, rotation: Int, cropLeft: Double?, cropTop: Double?, cropWidth: Double?, cropHeight: Double?) async throws -> DeviceImage {
        let mutation = """
        mutation EditImage($id: Int!, $rotation: Int!, $cropLeft: Float, $cropTop: Float, $cropWidth: Float, $cropHeight: Float) {
            editImage(id: $id, rotation: $rotation, cropLeft: $cropLeft, cropTop: $cropTop, cropWidth: $cropWidth, cropHeight: $cropHeight) {
                id
                path
                thumbnailPath
                originalPath
                rotation
                cropLeft
                cropTop
                cropWidth
                cropHeight
                dateTaken
                caption
                isShopImage
                isThumbnail
                thumbnailMode
                isListingImage
                mediaType
                duration
            }
        }
        """
        var variables: [String: Any] = ["id": id, "rotation": rotation]
        if let cropLeft   { variables["cropLeft"]   = cropLeft }
        if let cropTop    { variables["cropTop"]    = cropTop }
        if let cropWidth  { variables["cropWidth"]  = cropWidth }
        if let cropHeight { variables["cropHeight"] = cropHeight }

        struct Response: Codable { let editImage: DeviceImage }
        let response: Response = try await api.execute(query: mutation, variables: variables)
        return response.editImage
    }

    func resetImageEdits(id: Int) async throws -> DeviceImage {
        let mutation = """
        mutation ResetImageEdits($id: Int!) {
            resetImageEdits(id: $id) {
                id
                path
                thumbnailPath
                originalPath
                rotation
                cropLeft
                cropTop
                cropWidth
                cropHeight
                dateTaken
                caption
                isShopImage
                isThumbnail
                thumbnailMode
                isListingImage
                mediaType
                duration
            }
        }
        """
        struct Response: Codable { let resetImageEdits: DeviceImage }
        let response: Response = try await api.execute(query: mutation, variables: ["id": id])
        return response.resetImageEdits
    }
```

- [ ] **Step 8.4: Build iOS to verify**

```bash
xcodebuild -scheme InventoryDifferent \
  -destination 'platform=iOS Simulator,id=9116C8FB-2461-4260-B7DD-FE254FD202DE' \
  build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 8.5: Commit**

```bash
git add ios/InventoryDifferent/InventoryDifferent/Models/Device.swift \
  ios/InventoryDifferent/InventoryDifferent/Services/DeviceService.swift
git commit -m "$(cat <<'EOF'
feat(ios): extend DeviceImage with edit fields and add editImage/resetImageEdits service methods

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: iOS `EditPhotoView` + `ImageManagementView` Wiring

**Files:**
- Create: `ios/.../Views/EditPhotoView.swift`
- Modify: `ios/.../Views/ImageManagementView.swift`

- [ ] **Step 9.1: Create EditPhotoView.swift**

Create `ios/InventoryDifferent/InventoryDifferent/Views/EditPhotoView.swift`:

```swift
import SwiftUI

struct EditPhotoView: View {
    let image: DeviceImage
    let deviceId: Int
    let onSaved: (DeviceImage) -> Void

    @StateObject private var deviceService = DeviceService()
    @EnvironmentObject var lm: LocalizationManager
    @Environment(\.dismiss) var dismiss

    // Editing state
    @State private var rotation: Int = 0
    @State private var cropRect = CGRect(x: 0, y: 0, width: 1, height: 1) // normalized 0-1
    @State private var isSaving = false
    @State private var isResetting = false
    @State private var showResetConfirm = false
    @State private var errorMessage: String? = nil

    var t: Translations { lm.t }

    // Source to edit from: always the original
    var sourceURL: URL? {
        let p = image.originalPath ?? image.path
        return URL(string: APIService.shared.baseURL + p)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Rotate toolbar
                HStack(spacing: 16) {
                    Button {
                        rotation = (rotation + 270) % 360
                        // CropEditorView.onChange resets cropRect when rotation changes
                    } label: {
                        Label(t.imageManagement.rotateLeft, systemImage: "rotate.left")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        rotation = (rotation + 90) % 360
                    } label: {
                        Label(t.imageManagement.rotateRight, systemImage: "rotate.right")
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                    Text("\(rotation)°")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()

                Divider()

                // Crop editor
                if let url = sourceURL {
                    CropEditorView(imageURL: url, rotation: rotation, cropRect: $cropRect)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if let err = errorMessage {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
            }
            .navigationTitle(t.imageManagement.editPhoto)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.common.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t.imageManagement.saveEdits) {
                        Task { await save() }
                    }
                    .disabled(isSaving || isResetting)
                }
                if image.originalPath != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button(t.imageManagement.resetToOriginal, role: .destructive) {
                            showResetConfirm = true
                        }
                        .disabled(isSaving || isResetting)
                    }
                }
            }
            .confirmationDialog(t.imageManagement.resetToOriginal, isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button(t.imageManagement.resetToOriginal, role: .destructive) {
                    Task { await reset() }
                }
                Button(t.common.cancel, role: .cancel) {}
            }
        }
        .onAppear { loadExistingEdits() }
    }

    private func loadExistingEdits() {
        rotation = image.rotation ?? 0
        if let l = image.cropLeft, let tp = image.cropTop, let w = image.cropWidth, let h = image.cropHeight {
            cropRect = CGRect(x: l, y: tp, width: w, height: h)
        }
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        do {
            let hasCrop = cropRect.width < 0.99 || cropRect.height < 0.99 || cropRect.minX > 0.01 || cropRect.minY > 0.01
            let updated = try await deviceService.editImage(
                id: image.id,
                rotation: rotation,
                cropLeft:   hasCrop ? cropRect.minX   : nil,
                cropTop:    hasCrop ? cropRect.minY   : nil,
                cropWidth:  hasCrop ? cropRect.width  : nil,
                cropHeight: hasCrop ? cropRect.height : nil
            )
            // Invalidate caches for the old paths
            if let oldURL = URL(string: APIService.shared.baseURL + image.path) {
                await ImageCacheService.shared.removeImage(for: oldURL)
            }
            if let thumbPath = image.thumbnailPath,
               let oldThumbURL = URL(string: APIService.shared.baseURL + thumbPath) {
                await ImageCacheService.shared.removeImage(for: oldThumbURL)
            }
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func reset() async {
        isResetting = true
        errorMessage = nil
        do {
            let updated = try await deviceService.resetImageEdits(id: image.id)
            if let oldURL = URL(string: APIService.shared.baseURL + image.path) {
                await ImageCacheService.shared.removeImage(for: oldURL)
            }
            if let thumbPath = image.thumbnailPath,
               let oldThumbURL = URL(string: APIService.shared.baseURL + thumbPath) {
                await ImageCacheService.shared.removeImage(for: oldThumbURL)
            }
            onSaved(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isResetting = false
    }
}

// MARK: - Crop Editor

struct CropEditorView: View {
    let imageURL: URL
    let rotation: Int
    @Binding var cropRect: CGRect  // normalized 0-1

    // Pre-rotating the UIImage via Core Graphics (not SwiftUI .rotationEffect) is required
    // so that the crop-handle coordinate math stays correct when width and height swap at 90°/270°.
    @State private var originalImage: UIImage? = nil
    @State private var displayImage: UIImage? = nil
    @State private var imageFrame: CGRect = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let img = displayImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .background(GeometryReader { imgGeo in
                            Color.clear.preference(key: ImageFrameKey.self, value: imgGeo.frame(in: .named("editor")))
                        })
                } else {
                    ProgressView()
                }
                if imageFrame != .zero, displayImage != nil {
                    CropDimmingOverlay(cropRect: displayCropRect, totalSize: geo.size)
                    CropHandlesView(cropRect: $cropRect, imageFrame: imageFrame)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .coordinateSpace(name: "editor")
            .onPreferenceChange(ImageFrameKey.self) { imageFrame = $0 }
        }
        .task {
            // URLSession for async download — Data(contentsOf:) blocks the thread
            guard let (data, _) = try? await URLSession.shared.data(from: imageURL),
                  let img = UIImage(data: data) else { return }
            originalImage = img
            displayImage = rotatedImage(img, degrees: rotation)
        }
        .onChange(of: rotation) { _, newRot in
            guard let original = originalImage else { return }
            displayImage = rotatedImage(original, degrees: newRot)
            cropRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        }
    }

    var displayCropRect: CGRect {
        CGRect(
            x: imageFrame.minX + cropRect.minX * imageFrame.width,
            y: imageFrame.minY + cropRect.minY * imageFrame.height,
            width: cropRect.width * imageFrame.width,
            height: cropRect.height * imageFrame.height
        )
    }

    private func rotatedImage(_ image: UIImage, degrees: Int) -> UIImage {
        guard degrees != 0 else { return image }
        let radians = CGFloat(degrees) * .pi / 180
        let swap = degrees == 90 || degrees == 270
        let newSize = swap
            ? CGSize(width: image.size.height, height: image.size.width)
            : image.size
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        guard let ctx = UIGraphicsGetCurrentContext() else { return image }
        ctx.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        ctx.rotate(by: radians)
        image.draw(in: CGRect(
            x: -image.size.width / 2, y: -image.size.height / 2,
            width: image.size.width, height: image.size.height
        ))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
}

// MARK: - Supporting Views

struct ImageFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

struct CropDimmingOverlay: View {
    let cropRect: CGRect
    let totalSize: CGSize

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.5)))
            ctx.blendMode = .destinationOut
            ctx.fill(Path(cropRect), with: .color(.white))
        }
        .allowsHitTesting(false)
    }
}

enum CropCorner { case topLeft, topRight, bottomLeft, bottomRight }

struct CropHandlesView: View {
    @Binding var cropRect: CGRect  // normalized 0-1
    let imageFrame: CGRect
    private let handleSize: CGFloat = 22

    var body: some View {
        ZStack {
            // Crop border
            Rectangle()
                .stroke(Color.white, lineWidth: 1)
                .frame(
                    width: cropRect.width  * imageFrame.width,
                    height: cropRect.height * imageFrame.height
                )
                .position(
                    x: imageFrame.minX + (cropRect.minX + cropRect.width  / 2) * imageFrame.width,
                    y: imageFrame.minY + (cropRect.minY + cropRect.height / 2) * imageFrame.height
                )

            // Four corner handles
            ForEach([CropCorner.topLeft, .topRight, .bottomLeft, .bottomRight], id: \.self.hashValue) { corner in
                Circle()
                    .fill(Color.white)
                    .shadow(radius: 1)
                    .frame(width: handleSize, height: handleSize)
                    .position(handlePosition(corner))
                    .gesture(DragGesture(coordinateSpace: .named("editor"))
                        .onChanged { v in moveHandle(corner, to: v.location) }
                    )
            }
        }
    }

    private func handlePosition(_ corner: CropCorner) -> CGPoint {
        let x: CGFloat
        let y: CGFloat
        switch corner {
        case .topLeft:     x = cropRect.minX; y = cropRect.minY
        case .topRight:    x = cropRect.maxX; y = cropRect.minY
        case .bottomLeft:  x = cropRect.minX; y = cropRect.maxY
        case .bottomRight: x = cropRect.maxX; y = cropRect.maxY
        }
        return CGPoint(
            x: imageFrame.minX + x * imageFrame.width,
            y: imageFrame.minY + y * imageFrame.height
        )
    }

    private func moveHandle(_ corner: CropCorner, to point: CGPoint) {
        let nx = max(0, min(1, (point.x - imageFrame.minX) / imageFrame.width))
        let ny = max(0, min(1, (point.y - imageFrame.minY) / imageFrame.height))
        var r = cropRect
        let minSize: CGFloat = 0.05
        switch corner {
        case .topLeft:
            r.origin.x = min(nx, r.maxX - minSize)
            r.size.width  = r.maxX - r.origin.x
            r.origin.y = min(ny, r.maxY - minSize)
            r.size.height = r.maxY - r.origin.y
        case .topRight:
            r.size.width  = max(minSize, nx - r.origin.x)
            r.origin.y = min(ny, r.maxY - minSize)
            r.size.height = r.maxY - r.origin.y
        case .bottomLeft:
            r.origin.x = min(nx, r.maxX - minSize)
            r.size.width  = r.maxX - r.origin.x
            r.size.height = max(minSize, ny - r.origin.y)
        case .bottomRight:
            r.size.width  = max(minSize, nx - r.origin.x)
            r.size.height = max(minSize, ny - r.origin.y)
        }
        cropRect = r
    }
}
```

Note: `DragGesture` uses `.named("editor")` coordinate space which must match the `.coordinateSpace(name: "editor")` on the parent ZStack in `CropEditorView`.

Note: `ImageCacheService.shared.removeImage(for:)` — verify the exact method signature in `ImageCacheService.swift`; it may be `removeImage(for url: URL)` as an `actor` method (requiring `await`).

- [ ] **Step 9.2: Add "Edit Photo" button to ImageManagementView**

In `ios/.../Views/ImageManagementView.swift`, find the section inside the `if image.mediaType != "VIDEO"` block (around line 57). Before the first button or after the last existing button in the `VStack`, add:

```swift
                        NavigationLink {
                            EditPhotoView(image: image, deviceId: deviceId) { updatedImage in
                                // Propagate the updated image upward via the same callback pattern used for other updates
                                onImageUpdated?(updatedImage)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "crop")
                                Text(t.imageManagement.editPhoto)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(.primary)
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
```

Check the actual signature of `ImageManagementView` to understand how `deviceId` and `onImageUpdated` are passed — adjust as needed to fit the existing patterns (the view may receive `image` and a callback via its init).

- [ ] **Step 9.3: Build iOS to verify**

```bash
xcodebuild -scheme InventoryDifferent \
  -destination 'platform=iOS Simulator,id=9116C8FB-2461-4260-B7DD-FE254FD202DE' \
  build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)"
```

Expected: `BUILD SUCCEEDED`. SourceKit "Cannot find type" errors in the IDE are indexing artifacts — always trust `xcodebuild`.

- [ ] **Step 9.4: Commit**

```bash
git add ios/InventoryDifferent/InventoryDifferent/Views/EditPhotoView.swift \
  ios/InventoryDifferent/InventoryDifferent/Views/ImageManagementView.swift
git commit -m "$(cat <<'EOF'
feat(ios): add EditPhotoView with crop/rotate UI and wire into ImageManagementView

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: iOS Translations

**Files:**
- Modify: `ios/.../i18n/Translations.swift`
- Modify: `ios/.../i18n/Translations+en.swift`
- Modify: `ios/.../i18n/Translations+de.swift`
- Modify: `ios/.../i18n/Translations+fr.swift`

- [ ] **Step 10.1: Add keys to ImageManagementT struct**

In `ios/.../i18n/Translations.swift`, extend `ImageManagementT` (line 227):

```swift
    struct ImageManagementT {
        let title, done, imageSettings: String
        let setThumbnail, removeFromShop, addToShop, setListingImage: String
        let deleteImage, deleteTitle, deleteMessage: String
        // Edit
        let editPhoto, rotateLeft, rotateRight, saveEdits, resetToOriginal: String
    }
```

- [ ] **Step 10.2: Add English values**

In `ios/.../i18n/Translations+en.swift`, find the `ImageManagementT(...)` initializer. Add the new keys (maintain the order matching the struct):

```swift
            editPhoto: "Edit Photo",
            rotateLeft: "Rotate Left",
            rotateRight: "Rotate Right",
            saveEdits: "Save Edits",
            resetToOriginal: "Reset to Original"
```

- [ ] **Step 10.3: Add German values**

In `ios/.../i18n/Translations+de.swift`, same location:

```swift
            editPhoto: "Foto bearbeiten",
            rotateLeft: "Links drehen",
            rotateRight: "Rechts drehen",
            saveEdits: "Änderungen speichern",
            resetToOriginal: "Zum Original zurücksetzen"
```

- [ ] **Step 10.4: Add French values**

In `ios/.../i18n/Translations+fr.swift`:

```swift
            editPhoto: "Modifier la photo",
            rotateLeft: "Tourner à gauche",
            rotateRight: "Tourner à droite",
            saveEdits: "Enregistrer",
            resetToOriginal: "Restaurer l'original"
```

- [ ] **Step 10.5: Build iOS to verify**

```bash
xcodebuild -scheme InventoryDifferent \
  -destination 'platform=iOS Simulator,id=9116C8FB-2461-4260-B7DD-FE254FD202DE' \
  build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 10.6: Commit**

```bash
git add ios/InventoryDifferent/InventoryDifferent/i18n/
git commit -m "$(cat <<'EOF'
feat(ios): add image edit translation keys for en/de/fr

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Release Notes + Changelog + Flows

**Files:**
- Modify: `web/src/lib/releaseNotes.ts`
- Modify: `CHANGELOG.md`
- Modify: `docs/architecture/flows.html`

- [ ] **Step 11.1: Update releaseNotes.ts**

In `web/src/lib/releaseNotes.ts`, find the `Unreleased` entry and add to the `added` array:

```typescript
"Non-destructive photo editing — rotate (90° increments) and free-form crop for device images, with original always preserved and restorable"
```

- [ ] **Step 11.2: Update CHANGELOG.md**

Under `## [Unreleased]`, add:

```markdown
### Added
- Non-destructive photo editing: rotate (90° increments) and free-form crop on web and iOS; original file always preserved and restorable
```

- [ ] **Step 11.3: Add photo editing flow to flows.html**

Open `docs/architecture/flows.html`. In the `DATA.flows` array, add a new flow entry:

```javascript
{
  id: "photo-editing",
  name: "Photo Editing (Rotate/Crop)",
  description: "User rotates or crops a device photo; original is preserved; display copy generated via Sharp",
  steps: [
    {
      id: "edit-ui",
      label: "User sets rotation + crop in editor",
      packages: ["web", "ios"],
      edges: []
    },
    {
      id: "edit-mutation",
      label: "editImage GraphQL mutation sent",
      packages: ["web", "ios", "api"],
      edges: ["web-api", "ios-api"]
    },
    {
      id: "sharp-transform",
      label: "API applies Sharp transforms, writes display copy + thumbnail",
      packages: ["api", "storage"],
      edges: ["api-storage"]
    },
    {
      id: "db-update",
      label: "DB updated: path → display copy, originalPath preserved",
      packages: ["api", "db"],
      edges: ["api-db"]
    },
    {
      id: "client-reload",
      label: "Client reloads images; new path fetched, old cache invalidated",
      packages: ["web", "ios", "storage"],
      edges: ["web-api", "ios-api"]
    }
  ]
}
```

Adjust `packages` and `edges` IDs to match the actual IDs in the `DATA` object at the top of `flows.html`.

- [ ] **Step 11.4: Final build verification — all platforms**

```bash
cd api && npm run build 2>&1 | tail -3
cd ../web && npm run build 2>&1 | tail -3
```

```bash
xcodebuild -scheme InventoryDifferent \
  -destination 'platform=iOS Simulator,id=9116C8FB-2461-4260-B7DD-FE254FD202DE' \
  build 2>&1 | grep -E "(BUILD SUCCEEDED|BUILD FAILED|error:)"
```

All three expected: success.

- [ ] **Step 11.5: Commit**

```bash
git add web/src/lib/releaseNotes.ts CHANGELOG.md docs/architecture/flows.html
git commit -m "$(cat <<'EOF'
docs: add photo editing to release notes, changelog, and architecture flows

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## End-to-End Verification Checklist

After completing all tasks, verify manually:

1. **No edits baseline**: Upload a new image → confirm `originalPath` is null, display is normal
2. **Rotate only**: Open Edit → rotate 90° → Save → thumbnail and gallery image both rotated
3. **Crop only**: Open Edit → draw crop → Save → thumbnail and gallery image both cropped
4. **Rotate + crop**: Open Edit → rotate 180° → crop top-left quadrant → Save → result is correct
5. **Re-edit preserves original**: Open Edit on an already-edited image → confirm source shown is the original (not the display copy)
6. **Reset**: Click "Reset to Original" → image and thumbnail revert, `originalPath` cleared
7. **Export/import**: Export device to ZIP → open ZIP and verify `originals/` folder present and manifest has transform fields → import on a fresh device → display copy reconstructed
8. **iOS rotate**: Open ImageManagementView → Edit Photo → rotate → save → image updates in gallery
9. **iOS crop**: Edit Photo → drag corner handles → save → image crops correctly
10. **iOS reset**: Edit Photo → "Reset to Original" → confirm revert
11. **Storefront**: For a FOR_SALE device, verify edited images display correctly on the public shop
