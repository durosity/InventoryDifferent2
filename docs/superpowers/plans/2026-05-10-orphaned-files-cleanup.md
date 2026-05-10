# Orphaned Files Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a lazy-scan orphaned file detector to the Usage page that lists filesystem files not referenced by any Image record, and lets admins delete them individually or in bulk with confirmation.

**Architecture:** New `orphanedFiles` GraphQL query walks `/app/uploads/devices/`, cross-references all Image paths from the DB, and returns un-referenced files with sizes. A new `deleteOrphanedFiles` mutation validates and removes them. The Usage page gets a new bottom section with a scan button, checkbox list, and bulk/individual delete with confirmation.

**Tech Stack:** TypeScript, Apollo Server (GraphQL), Node.js `fs` module, Next.js 14 App Router, Apollo Client (`useLazyQuery`/`useMutation`), Tailwind CSS.

---

### Task 1: Add GraphQL schema — OrphanedFile type, query, mutation

**Files:**
- Modify: `api/src/typeDefs.ts`

- [ ] **Step 1: Add `OrphanedFile` type after the `SystemUsage` type block**

In `api/src/typeDefs.ts`, find the `SystemUsage` type (around line 250). After its closing `}`, add:

```graphql
  type OrphanedFile {
    path: String!
    sizeBytes: Float!
  }
```

- [ ] **Step 2: Add `orphanedFiles` to the Query type**

In the `type Query {` block (around line 581), after the `systemUsage: SystemUsage!` line, add:

```graphql
    orphanedFiles: [OrphanedFile!]!
```

- [ ] **Step 3: Add `deleteOrphanedFiles` to the Mutation type**

In the `type Mutation {` block (around line 823), add at the end before the closing `}`:

```graphql
    deleteOrphanedFiles(paths: [String!]!): Int!
```

- [ ] **Step 4: Verify TypeScript compiles**

```bash
cd api && npm run build 2>&1 | grep -E "(error|warning|BUILD)"
```

Expected: no errors (schema is just strings; compile errors would be in resolver steps).

- [ ] **Step 5: Commit**

```bash
git add api/src/typeDefs.ts
git commit -m "$(cat <<'EOF'
feat(api): add OrphanedFile type, orphanedFiles query, and deleteOrphanedFiles mutation to schema

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Add `orphanedFiles` query resolver

**Files:**
- Modify: `api/src/resolvers.ts`

- [ ] **Step 1: Add the `orphanedFiles` resolver in the Query object**

In `api/src/resolvers.ts`, find the `systemUsage` resolver (around line 623). After its closing `},`, add:

```typescript
        orphanedFiles: async (_parent: any, _args: any, context: Context) => {
            requireAuth(context);
            const fs = await import('fs');
            const pathModule = await import('path');

            // Collect all DB-referenced paths into a Set
            const images = await context.prisma.image.findMany({
                select: { path: true, thumbnailPath: true },
            });
            const referencedPaths = new Set<string>();
            for (const img of images) {
                if (img.path) referencedPaths.add(img.path);
                if ((img as any).thumbnailPath) referencedPaths.add((img as any).thumbnailPath);
            }

            // Recursively walk /app/uploads/devices/
            const uploadsRoot = '/app/uploads/devices';
            const results: { path: string; sizeBytes: number }[] = [];

            function walkDir(dir: string) {
                if (!fs.existsSync(dir)) return;
                for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
                    const fullPath = pathModule.join(dir, entry.name);
                    if (entry.isDirectory()) {
                        walkDir(fullPath);
                    } else if (entry.isFile()) {
                        // Convert disk path back to URL-style /uploads/... path
                        const urlPath = fullPath.replace('/app/uploads', '/uploads');
                        if (!referencedPaths.has(urlPath)) {
                            try {
                                const stats = fs.statSync(fullPath);
                                results.push({ path: urlPath, sizeBytes: stats.size });
                            } catch {
                                // Skip unreadable files
                            }
                        }
                    }
                }
            }

            walkDir(uploadsRoot);
            return results;
        },
```

- [ ] **Step 2: Build to verify no TypeScript errors**

```bash
cd api && npm run build 2>&1 | grep -E "error TS"
```

Expected: no output (no errors).

- [ ] **Step 3: Commit**

```bash
git add api/src/resolvers.ts
git commit -m "$(cat <<'EOF'
feat(api): add orphanedFiles query resolver — walks uploads dir and cross-references DB image paths

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Add `deleteOrphanedFiles` mutation resolver

**Files:**
- Modify: `api/src/resolvers.ts`

- [ ] **Step 1: Add the mutation resolver in the Mutation object**

In `api/src/resolvers.ts`, find the Mutation resolver object. Add `deleteOrphanedFiles` alongside the other mutations (near `deleteImage`, `deleteDevice`, etc.):

```typescript
        deleteOrphanedFiles: async (_parent: any, args: { paths: string[] }, context: Context) => {
            requireAuth(context);
            const fs = await import('fs');
            const pathModule = await import('path');

            let deleted = 0;
            for (const urlPath of args.paths) {
                // Path traversal guard — only allow /uploads/devices/ paths
                if (!urlPath.startsWith('/uploads/devices/')) {
                    continue;
                }
                const diskPath = pathModule.join('/app/uploads', urlPath.replace('/uploads/', ''));
                // Ensure resolved path stays within /app/uploads
                if (!diskPath.startsWith('/app/uploads/')) {
                    continue;
                }
                try {
                    fs.unlinkSync(diskPath);
                    deleted++;
                } catch {
                    // File already gone or unreadable — skip silently
                }
            }
            return deleted;
        },
```

- [ ] **Step 2: Build to verify**

```bash
cd api && npm run build 2>&1 | grep -E "error TS"
```

Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add api/src/resolvers.ts
git commit -m "$(cat <<'EOF'
feat(api): add deleteOrphanedFiles mutation resolver with path traversal guard

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Add i18n strings for all three languages

**Files:**
- Modify: `web/src/i18n/translations/en.ts`
- Modify: `web/src/i18n/translations/de.ts`
- Modify: `web/src/i18n/translations/fr.ts`

- [ ] **Step 1: Add the type keys to the `usage` block in `en.ts`**

In `web/src/i18n/translations/en.ts`, find the `usage: {` block inside the `Translations` type interface (around line 474). Add these keys after `bytes: string;`:

```typescript
      orphanedFiles: string;
      scanButton: string;
      scanAgainButton: string;
      noOrphansFound: string;
      orphansSummary: string;
      deleteSelected: string;
      selectAll: string;
      confirmDeleteSingle: string;
      confirmDeleteBulkTitle: string;
      confirmDeleteBulkBody: string;
```

- [ ] **Step 2: Add English values to `en.ts`**

In `web/src/i18n/translations/en.ts`, find the `usage: {` values block (around line 1445). After `bytes: "bytes",`, add:

```typescript
      orphanedFiles: "Orphaned Files",
      scanButton: "Scan for Orphaned Files",
      scanAgainButton: "Scan Again",
      noOrphansFound: "No orphaned files found.",
      orphansSummary: "orphaned files",
      deleteSelected: "Delete Selected",
      selectAll: "Select All",
      confirmDeleteSingle: "Confirm?",
      confirmDeleteBulkTitle: "Delete files?",
      confirmDeleteBulkBody: "This cannot be undone.",
```

- [ ] **Step 3: Add German values to `de.ts`**

In `web/src/i18n/translations/de.ts`, find the `usage: {` values block (around line 483). After `bytes: "Bytes",`, add:

```typescript
      orphanedFiles: "Verwaiste Dateien",
      scanButton: "Nach verwaisten Dateien suchen",
      scanAgainButton: "Erneut suchen",
      noOrphansFound: "Keine verwaisten Dateien gefunden.",
      orphansSummary: "verwaiste Dateien",
      deleteSelected: "Ausgewählte löschen",
      selectAll: "Alle auswählen",
      confirmDeleteSingle: "Bestätigen?",
      confirmDeleteBulkTitle: "Dateien löschen?",
      confirmDeleteBulkBody: "Dies kann nicht rückgängig gemacht werden.",
```

- [ ] **Step 4: Add French values to `fr.ts`**

In `web/src/i18n/translations/fr.ts`, find the `usage: {` values block (around line 483). After `bytes: "Octets",`, add:

```typescript
      orphanedFiles: "Fichiers orphelins",
      scanButton: "Rechercher les fichiers orphelins",
      scanAgainButton: "Rechercher à nouveau",
      noOrphansFound: "Aucun fichier orphelin trouvé.",
      orphansSummary: "fichiers orphelins",
      deleteSelected: "Supprimer la sélection",
      selectAll: "Tout sélectionner",
      confirmDeleteSingle: "Confirmer ?",
      confirmDeleteBulkTitle: "Supprimer les fichiers ?",
      confirmDeleteBulkBody: "Cette action est irréversible.",
```

- [ ] **Step 5: Build web to verify no TypeScript errors**

```bash
cd web && npm run build 2>&1 | grep -E "error TS|Type error"
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
git add web/src/i18n/translations/en.ts web/src/i18n/translations/de.ts web/src/i18n/translations/fr.ts
git commit -m "$(cat <<'EOF'
feat(web): add i18n strings for orphaned files cleanup feature (en/de/fr)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Add orphaned files section to the Usage page

**Files:**
- Modify: `web/src/app/(main)/usage/page.tsx`

- [ ] **Step 1: Add the GraphQL documents and update imports**

Replace the top of `web/src/app/(main)/usage/page.tsx` (the imports and GQL constants) with:

```typescript
"use client";

import { useQuery, useLazyQuery, useMutation } from "@apollo/client";
import gql from "graphql-tag";
import { useState } from "react";
import { LoadingPanel } from "../../../components/LoadingPanel";
import { useT } from "../../../i18n/context";

const GET_SYSTEM_USAGE = gql`
  query GetSystemUsage {
    systemUsage {
      deviceCount
      noteCount
      taskCount
      imageCount
      categoryCount
      templateCount
      tagCount
      totalStorageBytes
    }
  }
`;

const GET_ORPHANED_FILES = gql`
  query GetOrphanedFiles {
    orphanedFiles {
      path
      sizeBytes
    }
  }
`;

const DELETE_ORPHANED_FILES = gql`
  mutation DeleteOrphanedFiles($paths: [String!]!) {
    deleteOrphanedFiles(paths: $paths)
  }
`;
```

- [ ] **Step 2: Update the component to add orphan state and hooks**

Replace the `export default function UsagePage()` function signature and its initial hook calls with:

```typescript
export default function UsagePage() {
  const t = useT();
  const { loading, error, data } = useQuery(GET_SYSTEM_USAGE);

  // Orphaned files state
  type OrphanedFile = { path: string; sizeBytes: number };
  const [scanState, setScanState] = useState<"idle" | "loading" | "done">("idle");
  const [orphans, setOrphans] = useState<OrphanedFile[]>([]);
  const [selected, setSelected] = useState<Set<string>>(new Set());
  const [confirmingPath, setConfirmingPath] = useState<string | null>(null);
  const [showBulkConfirm, setShowBulkConfirm] = useState(false);

  const [scanOrphans] = useLazyQuery(GET_ORPHANED_FILES, {
    fetchPolicy: "network-only",
    onCompleted: (d) => {
      setOrphans(d.orphanedFiles ?? []);
      setSelected(new Set());
      setScanState("done");
    },
    onError: () => setScanState("idle"),
  });

  const [deleteOrphanedFiles, { loading: deleting }] = useMutation(DELETE_ORPHANED_FILES);

  function handleScan() {
    setScanState("loading");
    setOrphans([]);
    setSelected(new Set());
    scanOrphans();
  }

  function toggleSelect(path: string) {
    setSelected((prev) => {
      const next = new Set(prev);
      next.has(path) ? next.delete(path) : next.add(path);
      return next;
    });
  }

  function toggleAll() {
    setSelected((prev) =>
      prev.size === orphans.length ? new Set() : new Set(orphans.map((o) => o.path))
    );
  }

  async function handleDeleteSingle(path: string) {
    if (confirmingPath !== path) {
      setConfirmingPath(path);
      return;
    }
    setConfirmingPath(null);
    await deleteOrphanedFiles({ variables: { paths: [path] } });
    setOrphans((prev) => prev.filter((o) => o.path !== path));
    setSelected((prev) => { const next = new Set(prev); next.delete(path); return next; });
  }

  async function handleDeleteBulk() {
    const paths = Array.from(selected);
    setShowBulkConfirm(false);
    await deleteOrphanedFiles({ variables: { paths } });
    setOrphans((prev) => prev.filter((o) => !selected.has(o.path)));
    setSelected(new Set());
  }

  const orphanTotalBytes = orphans.reduce((sum, o) => sum + o.sizeBytes, 0);
```

- [ ] **Step 3: Add the orphaned files JSX section**

Inside the returned JSX, after the closing `</section>` of the storage card (after `</section>` around line 126), and before the closing `</div></div>`, add:

```tsx
        {/* Orphaned Files Section */}
        <section className="rounded border border-[var(--border)] bg-[var(--card)] p-6 card-retro">
          <h2 className="mb-4 text-lg font-semibold text-[var(--foreground)]">{t.pages.usage.orphanedFiles}</h2>

          {scanState === "idle" && (
            <button
              onClick={handleScan}
              className="rounded border border-[var(--border)] bg-[var(--background)] px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--muted)] transition-colors"
            >
              {t.pages.usage.scanButton}
            </button>
          )}

          {scanState === "loading" && (
            <div className="text-sm text-[var(--muted-foreground)]">Scanning…</div>
          )}

          {scanState === "done" && orphans.length === 0 && (
            <div className="space-y-3">
              <div className="text-sm text-green-600 dark:text-green-400">{t.pages.usage.noOrphansFound}</div>
              <button
                onClick={handleScan}
                className="rounded border border-[var(--border)] bg-[var(--background)] px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--muted)] transition-colors"
              >
                {t.pages.usage.scanAgainButton}
              </button>
            </div>
          )}

          {scanState === "done" && orphans.length > 0 && (
            <div className="space-y-4">
              {/* Summary bar */}
              <div className="flex items-center gap-3 flex-wrap">
                <label className="flex items-center gap-2 text-sm text-[var(--foreground)] cursor-pointer">
                  <input
                    type="checkbox"
                    checked={selected.size === orphans.length}
                    onChange={toggleAll}
                    className="cursor-pointer"
                  />
                  {t.pages.usage.selectAll}
                </label>
                <span className="text-sm text-[var(--muted-foreground)]">
                  {orphans.length} {t.pages.usage.orphansSummary} · {formatBytes(orphanTotalBytes)}
                </span>
                <button
                  onClick={() => setShowBulkConfirm(true)}
                  disabled={selected.size === 0 || deleting}
                  className="rounded border border-red-400 px-3 py-1 text-sm text-red-600 hover:bg-red-50 dark:hover:bg-red-950 disabled:opacity-40 disabled:cursor-not-allowed transition-colors ml-auto"
                >
                  {t.pages.usage.deleteSelected} ({selected.size})
                </button>
              </div>

              {/* File list */}
              <div className="divide-y divide-[var(--border)] rounded border border-[var(--border)]">
                {orphans.map((orphan) => (
                  <div key={orphan.path} className="flex items-center gap-3 px-4 py-3 bg-[var(--background)]">
                    <input
                      type="checkbox"
                      checked={selected.has(orphan.path)}
                      onChange={() => toggleSelect(orphan.path)}
                      className="cursor-pointer flex-shrink-0"
                    />
                    <span className="flex-1 min-w-0 truncate text-sm font-mono text-[var(--foreground)]">
                      {orphan.path.replace("/uploads/", "")}
                    </span>
                    <span className="flex-shrink-0 text-xs text-[var(--muted-foreground)] tabular-nums">
                      {formatBytes(orphan.sizeBytes)}
                    </span>
                    <button
                      onClick={() => handleDeleteSingle(orphan.path)}
                      disabled={deleting}
                      className={`flex-shrink-0 rounded border px-3 py-1 text-xs transition-colors disabled:opacity-40 disabled:cursor-not-allowed ${
                        confirmingPath === orphan.path
                          ? "border-red-500 bg-red-500 text-white hover:bg-red-600"
                          : "border-[var(--border)] text-[var(--muted-foreground)] hover:border-red-400 hover:text-red-600"
                      }`}
                    >
                      {confirmingPath === orphan.path
                        ? t.pages.usage.confirmDeleteSingle
                        : "×"}
                    </button>
                  </div>
                ))}
              </div>

              <button
                onClick={handleScan}
                className="rounded border border-[var(--border)] bg-[var(--background)] px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--muted)] transition-colors"
              >
                {t.pages.usage.scanAgainButton}
              </button>
            </div>
          )}
        </section>

        {/* Bulk delete confirmation modal */}
        {showBulkConfirm && (
          <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50">
            <div className="rounded border border-[var(--border)] bg-[var(--card)] p-6 shadow-xl max-w-sm w-full mx-4">
              <h3 className="text-lg font-semibold text-[var(--foreground)] mb-2">
                {t.pages.usage.confirmDeleteBulkTitle}
              </h3>
              <p className="text-sm text-[var(--muted-foreground)] mb-6">
                {selected.size} {t.pages.usage.orphansSummary}. {t.pages.usage.confirmDeleteBulkBody}
              </p>
              <div className="flex gap-3 justify-end">
                <button
                  onClick={() => setShowBulkConfirm(false)}
                  className="rounded border border-[var(--border)] px-4 py-2 text-sm text-[var(--foreground)] hover:bg-[var(--muted)] transition-colors"
                >
                  Cancel
                </button>
                <button
                  onClick={handleDeleteBulk}
                  className="rounded border border-red-500 bg-red-500 px-4 py-2 text-sm text-white hover:bg-red-600 transition-colors"
                >
                  {t.pages.usage.deleteSelected}
                </button>
              </div>
            </div>
          </div>
        )}
```

- [ ] **Step 4: Build web to verify**

```bash
cd web && npm run build 2>&1 | grep -E "error TS|Type error|Failed"
```

Expected: no errors.

- [ ] **Step 5: Also build api to verify end-to-end**

```bash
cd api && npm run build 2>&1 | grep -E "error TS"
```

Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add web/src/app/\(main\)/usage/page.tsx
git commit -m "$(cat <<'EOF'
feat(web): add orphaned files section to usage page with lazy scan and bulk/single delete

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Update release notes and CHANGELOG

**Files:**
- Modify: `web/src/lib/releaseNotes.ts`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Add bullet to `Unreleased` in `releaseNotes.ts`**

In `web/src/lib/releaseNotes.ts`, find the `Unreleased` entry's `added: []` array and add:

```typescript
      'Usage page: scan for orphaned files (files on disk not referenced by any image record) and delete them individually or in bulk',
```

- [ ] **Step 2: Add bullet to `CHANGELOG.md`**

In `CHANGELOG.md`, find the `## [Unreleased]` section's `### Added` block and add:

```markdown
- Usage page: scan for orphaned files (files on disk not referenced by any image record) and delete them individually or in bulk
```

If no `### Added` block exists under `## [Unreleased]`, create one.

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/releaseNotes.ts CHANGELOG.md
git commit -m "$(cat <<'EOF'
docs: add orphaned files cleanup to release notes

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```
