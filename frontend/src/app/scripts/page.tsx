import type { Metadata } from "next";

import { Suspense } from "react";

import { Catalog } from "@/components/heretek/catalog";
import { loadCatalog } from "@/lib/catalog";

export const metadata: Metadata = {
  title: "All scripts | Heretek-AI",
  description: "Browse, filter and copy every Heretek-AI script for Proxmox VE.",
};

export default function ScriptsPage() {
  const { scripts, categories } = loadCatalog();
  const used = categories.filter(c => c.scripts.length > 0).map(c => ({ id: c.id, name: c.name }));

  return (
    <div className="mx-auto max-w-[1440px] px-4 md:px-6">
      <header className="border-b border-border py-10 md:py-14">
        <p className="label-mono mb-3">
          <span className="text-blood">⛧</span>
          {" "}
          Catalogue
        </p>
        <h1 className="font-display text-4xl font-bold tracking-tight md:text-5xl">All scripts</h1>
        <p className="mt-3 max-w-2xl text-[16px] text-muted-foreground">
          Every installer in the repository. Filters live in the URL, so a filtered view can be bookmarked or shared.
        </p>
      </header>
      <div className="pt-8">
        <Suspense fallback={<p className="label-mono py-20 text-center">Loading catalogue…</p>}>
          <Catalog scripts={scripts} categories={used} />
        </Suspense>
      </div>
    </div>
  );
}
