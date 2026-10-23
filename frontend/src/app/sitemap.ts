import type { MetadataRoute } from "next";

import { basePath } from "@/config/site-config";
import { loadCatalog } from "@/lib/catalog";

export const dynamic = "force-static";

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const base = `https://heretek-ai.github.io/${basePath}`;
  const pages = ["", "/scripts", "/categories", "/versions", "/generator", "/community", "/json-editor"].map(p => ({
    url: `${base}${p}`,
    lastModified: new Date(),
  }));
  const scripts = loadCatalog().scripts.map(s => ({
    url: `${base}/scripts/${s.slug}`,
    lastModified: new Date(s.date_created),
  }));
  return [...pages, ...scripts];
}
