import { existsSync, readdirSync, readFileSync } from "node:fs";
import path from "node:path";

import type { AppVersion, Category, GitHubVersionsResponse, Metadata, Script } from "./types";
import type { CatalogScript } from "./script-meta";

// The site is a static export, so the catalog is read from disk once at build
// time and handed to pages as props. Nothing here runs in the browser.

const jsonDir = path.resolve("public/json");
const repoRoot = path.resolve("..");
const skipFiles = new Set(["metadata.json", "version.json", "versions.json", "github-versions.json"]);

function readJson<T>(file: string): T {
  return JSON.parse(readFileSync(path.join(jsonDir, file), "utf-8")) as T;
}

export type CatalogCategory = Omit<Category, "scripts"> & { scripts: CatalogScript[] };

let cache: { categories: CatalogCategory[]; scripts: CatalogScript[]; versionsGenerated: string | null } | null = null;

export function loadCatalog() {
  if (cache)
    return cache;

  const metadata = readJson<Metadata>("metadata.json");
  const versionsFile = existsSync(path.join(jsonDir, "github-versions.json"))
    ? readJson<GitHubVersionsResponse>("github-versions.json")
    : { generated: "", versions: [] };
  const versions = new Map<string, AppVersion>(versionsFile.versions.map(v => [v.slug, v]));

  const categoryNames = new Map(metadata.categories.map(c => [c.id, c.name]));

  const raw: Script[] = readdirSync(jsonDir)
    .filter(f => f.endsWith(".json") && !skipFiles.has(f))
    .map(f => readJson<Script>(f));

  // A JSON entry can outlive its script. When the repository checkout is
  // present (CI and local builds), flag entries whose script file is gone so
  // the site never hands out a command that 404s.
  const checkFiles = existsSync(path.join(repoRoot, "ct"));

  const scripts: CatalogScript[] = raw
    .map((s) => {
      const scriptPath = s.install_methods?.[0]?.script ?? "";
      return {
        ...s,
        categoryNames: (s.categories ?? []).map(id => categoryNames.get(id)).filter(Boolean) as string[],
        version: versions.get(s.slug) ?? null,
        available: !checkFiles || !scriptPath || existsSync(path.join(repoRoot, scriptPath)),
      };
    })
    .sort((a, b) => a.name.localeCompare(b.name));

  const categories: CatalogCategory[] = metadata.categories
    .map(c => ({ ...c, scripts: scripts.filter(s => s.categories?.includes(c.id)) }))
    .sort((a, b) => a.sort_order - b.sort_order);

  cache = { categories, scripts, versionsGenerated: versionsFile.generated || null };
  return cache;
}

export function getScript(slug: string) {
  return loadCatalog().scripts.find(s => s.slug === slug) ?? null;
}

export function relatedScripts(script: CatalogScript, limit = 4) {
  const { scripts } = loadCatalog();
  const scored = scripts
    .filter(s => s.slug !== script.slug && s.available)
    .map(s => ({ s, shared: s.categories.filter(id => script.categories.includes(id)).length }))
    .filter(x => x.shared > 0)
    .sort((a, b) => b.shared - a.shared || b.s.date_created.localeCompare(a.s.date_created));
  return scored.slice(0, limit).map(x => x.s);
}
