import type { Metadata } from "next";

import { ArrowRight } from "lucide-react";
import Link from "next/link";

import { ScriptLogo } from "@/components/heretek/script-logo";
import { TypeTag } from "@/components/heretek/type-tag";
import { scriptHref } from "@/lib/script-meta";
import { loadCatalog } from "@/lib/catalog";

export const metadata: Metadata = {
  title: "Categories | Heretek-AI",
  description: "Heretek-AI Proxmox VE scripts grouped by what they do.",
};

export default function CategoriesPage() {
  const { categories } = loadCatalog();
  const used = categories
    .map(c => ({ ...c, scripts: c.scripts.filter(s => s.available) }))
    .filter(c => c.scripts.length > 0);
  const empty = categories.filter(c => !c.scripts.some(s => s.available));

  return (
    <div className="mx-auto max-w-[1440px] px-4 md:px-6">
      <header className="border-b border-border py-10 md:py-14">
        <p className="label-mono mb-3">
          <span className="text-blood">⛧</span>
          {" "}
          Index
        </p>
        <h1 className="font-display text-4xl font-bold tracking-tight md:text-5xl">Categories</h1>
        <p className="mt-3 max-w-2xl text-[16px] text-muted-foreground">
          {used.length}
          {" "}
          categories hold scripts today. A script can sit in more than one.
        </p>
      </header>

      <div className="grid gap-x-10 lg:grid-cols-[220px_1fr]">
        <nav aria-label="Categories" className="hidden lg:block">
          <ul className="sticky top-32 space-y-1 pt-10 text-[13.5px]">
            {used.map(c => (
              <li key={c.id}>
                <a href={`#cat-${c.id}`} className="flex justify-between gap-3 py-1 text-muted-foreground hover:text-foreground">
                  <span className="truncate">{c.name}</span>
                  <span className="font-mono text-[11px]">{c.scripts.length}</span>
                </a>
              </li>
            ))}
          </ul>
        </nav>

        <div>
          {used.map((c, i) => (
            <section key={c.id} id={`cat-${c.id}`} className="scroll-mt-32 border-b border-border py-10">
              <div className="mb-5 flex flex-wrap items-end justify-between gap-4">
                <div>
                  <p className="label-mono mb-1">
                    <span className="mr-2 text-blood">{String(i + 1).padStart(2, "0")}</span>
                    {c.scripts.length}
                    {" "}
                    {c.scripts.length === 1 ? "script" : "scripts"}
                  </p>
                  <h2 className="font-display text-2xl font-semibold">{c.name}</h2>
                  <p className="mt-1 text-[14px] text-muted-foreground">{c.description}</p>
                </div>
                <Link href={`/scripts?categories=${c.id}`} className="inline-flex items-center gap-1.5 font-mono text-[11.5px] uppercase tracking-[0.14em] text-muted-foreground hover:text-foreground">
                  Filter catalogue
                  <ArrowRight className="size-3.5" />
                </Link>
              </div>
              <ul className="grid gap-px border border-border bg-border sm:grid-cols-2 xl:grid-cols-3">
                {c.scripts.map(s => (
                  <li key={s.slug} className="bg-card">
                    <Link href={scriptHref(s.slug)} className="group flex items-center gap-3 px-4 py-3 transition-colors hover:bg-panel">
                      <ScriptLogo src={s.logo} alt="" size={24} />
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-[14.5px] font-medium group-hover:text-blood">{s.name}</span>
                        <span className="block truncate text-[12.5px] text-muted-foreground">{s.description}</span>
                      </span>
                      <TypeTag type={s.type} />
                    </Link>
                  </li>
                ))}
              </ul>
            </section>
          ))}
          {empty.length > 0 && (
            <p className="py-10 text-[13px] text-muted-foreground">
              <span className="label-mono mr-2">Empty for now:</span>
              {empty.map(c => c.name).join(" · ")}
            </p>
          )}
        </div>
      </div>
    </div>
  );
}
