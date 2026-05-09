# Photos Page Lightbox — Design Spec

**Date:** 2026-05-09  
**Status:** Approved

## Problem

The device photos page (`/devices/[id]/photos`) shows images as small thumbnails in a grid. There is no way to view an image at full size — users who click a thumbnail get no response. Videos already have a full-screen player modal; images need equivalent treatment.

## Solution

Add a lightbox overlay to `ImageGallery`. Clicking any thumbnail (image or video) opens a full-screen dark overlay showing the media at maximum size, with prev/next navigation to browse the full set without closing.

Manage-mode buttons (thumbnail, delete, listing, shop) remain on hover as they do now and use `stopPropagation` so they don't trigger the lightbox.

## Lightbox Behaviour

- **Trigger:** Click anywhere on a thumbnail card (image area). Manage buttons call `e.stopPropagation()` so they don't open the lightbox.
- **Navigation:** Prev/next arrow buttons on left and right sides of the overlay. Left/right keyboard arrows also navigate. Wraps around (last → first, first → last).
- **Counter:** Position indicator at top center ("3 / 12").
- **Close:** ✕ button (top-right), Escape key, or click the dark backdrop. Clicking the media itself does not close (to avoid accidental dismissal).
- **Caption:** Shown below the media if the image has one.
- **Videos:** Rendered as a `<video controls autoPlay>` element inside the lightbox (same as the existing standalone video modal). Navigating away from a video pauses it.
- **Images:** `<img>` with `max-width: 90vw; max-height: 80vh; object-fit: contain`.

## Component Design

All lightbox state and rendering lives inside `ImageGallery` — no new files needed.

New state:
```ts
const [lightboxIndex, setLightboxIndex] = useState<number | null>(null);
```

`lightboxIndex` is the index into the `images` array of the currently open item. `null` = closed.

Helper functions:
- `openLightbox(index)` — sets `lightboxIndex`
- `closeLightbox()` — sets to `null`
- `navLightbox(delta)` — adds delta, wraps with modulo

Keyboard handler: `useEffect` that adds/removes a `keydown` listener on `window` when `lightboxIndex !== null`. Handles `ArrowLeft`, `ArrowRight`, `Escape`.

Each thumbnail card gets an `onClick` handler that calls `openLightbox(index)`. Each manage button gets `onClick={(e) => { e.stopPropagation(); /* existing handler */ }}`.

The existing standalone video modal (`playingVideoId` state) is removed — videos now open through the lightbox like images do.

## Thumbnail Grid — Click Cursor

Add `cursor-pointer` to each thumbnail card so the click affordance is visible.

## Out of Scope

- Pinch-to-zoom inside the lightbox
- Swipe gestures
- Caption editing from within the lightbox
- Downloading the full-res image from the lightbox
