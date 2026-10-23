import { ArrowRight } from "lucide-react";
import Link from "next/link";

import { InstallShowcase } from "@/components/heretek/install-showcase";
import { SectionHeading } from "@/components/heretek/section-heading";
import { CommandLine } from "@/components/heretek/command-line";
import { formatDate, installCommand } from "@/lib/script-meta";
import { ScriptCard } from "@/components/heretek/script-card";
import { HeroSearch } from "@/components/heretek/hero-search";
import { externalLinks } from "@/config/site-config";
import { loadCatalog } from "@/lib/catalog";
import FAQ from "@/components/faq";

const ROMAN = ["I", "II", "III"];

export default function HomePage() {
  const { scripts, categories } = loadCatalog();
  const live = scripts.filter(s => s.available);
  const newest = [...live].sort((a, b) => b.date_created.localeCompare(a.date_created));
  const showcase = newest.filter(s => s.type === "ct").slice(0, 4);
  const usedCategories = categories.filter(c => c.scripts.some(s => s.available));
  const tracked = live.filter(s => s.version).length;
  const example = showcase[0];

  const stats = [
    { value: String(live.length), label: "Scripts", href: "/scripts" },
    { value: String(usedCategories.length), label: "Categories", href: "/categories" },
    { value: String(tracked), label: "Upstream versions tracked", href: "/versions" },
    { value: formatDate(newest[0]?.date_created, { day: "numeric", month: "short" }), label: `Last added: ${newest[0]?.name ?? "—"}`, href: newest[0] ? `/scripts/${newest[0].slug}` : "/scripts" },
  ];

  return (
    <>
      {/* Hero */}
      <section className="relative overflow-hidden border-b border-border">
        <div className="grid-lines pointer-events-none absolute inset-0 [mask-image:linear-gradient(to_bottom,black,transparent_85%)]" aria-hidden />
        <div className="relative mx-auto grid max-w-[1440px] items-center gap-12 px-4 py-12 md:px-6 lg:grid-cols-[1.05fr_1fr] lg:py-20">
          <div>
            <p className="label-mono mb-6">
              <span className="text-blood">⛧</span>
              {" "}
              Heretek-AI · Proxmox VE helper scripts
            </p>
            <h1 className="text-balance font-display text-[40px] font-bold leading-[1.02] tracking-tight sm:text-6xl xl:text-[76px]">
              Forbidden scripts,
              <br />
              <span className="text-blood">forged</span>
              {" "}
              in innovation.
            </h1>
            <p className="mt-6 max-w-xl text-[17px] leading-relaxed text-muted-foreground">
              One-line installers for local AI, agents and homelab services that the orthodox catalogue doesn&apos;t carry.
              Find a script, copy its command, paste it into the Proxmox VE shell.
            </p>
            <div className="mt-8">
              <HeroSearch total={live.length} />
            </div>
            <div className="mt-5 flex flex-wrap items-center gap-x-5 gap-y-2 font-mono text-[11.5px] uppercase tracking-[0.14em] text-muted-foreground">
              <Link href="/scripts" className="inline-flex items-center gap-1.5 text-foreground hover:text-blood">
                Browse all
                <ArrowRight className="size-3.5" />
              </Link>
              {usedCategories.slice(0, 4).map(c => (
                <Link key={c.id} href={`/scripts?categories=${c.id}`} className="hover:text-foreground">
                  {c.name}
                </Link>
              ))}
            </div>
          </div>
          {showcase.length > 0 && <InstallShowcase scripts={showcase} />}
        </div>

        {/* Readout */}
        <div className="relative border-t border-border bg-background/60">
          <dl className="mx-auto grid max-w-[1440px] grid-cols-2 md:grid-cols-4">
            {stats.map((s, i) => (
              <Link
                key={s.label}
                href={s.href}
                className={`group flex items-baseline justify-between gap-4 border-border px-4 py-5 transition-colors hover:bg-panel md:px-6 ${i % 2 === 1 ? "border-l" : ""} ${i >= 2 ? "border-t md:border-t-0" : ""} md:border-l md:first:border-l-0`}
              >
                <div>
                  <dd className="font-display text-4xl font-semibold tabular-nums">{s.value}</dd>
                  <dt className="label-mono mt-1 line-clamp-1">{s.label}</dt>
                </div>
                <ArrowRight className="size-4 text-muted-foreground opacity-0 transition-opacity group-hover:opacity-100" />
              </Link>
            ))}
          </dl>
        </div>
      </section>

      <div className="mx-auto max-w-[1440px] px-4 md:px-6">
        {/* Newest */}
        <section className="pt-20">
          <SectionHeading
            index="01"
            kicker="Newly forged"
            title="Latest additions"
            action={(
              <Link href="/scripts?sort=newest" className="inline-flex items-center gap-1.5 font-mono text-[11.5px] uppercase tracking-[0.14em] text-muted-foreground hover:text-foreground">
                All scripts
                <ArrowRight className="size-3.5" />
              </Link>
            )}
          />
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
            {newest.slice(0, 6).map(s => (
              <ScriptCard key={s.slug} script={s} />
            ))}
          </div>
        </section>

        {/* Categories */}
        <section className="pt-20">
          <SectionHeading
            index="02"
            kicker="Index"
            title="Browse by purpose"
            action={(
              <Link href="/categories" className="inline-flex items-center gap-1.5 font-mono text-[11.5px] uppercase tracking-[0.14em] text-muted-foreground hover:text-foreground">
                All categories
                <ArrowRight className="size-3.5" />
              </Link>
            )}
          />
          <ul className="grid border-l border-t border-border sm:grid-cols-2 lg:grid-cols-3">
            {usedCategories.map((c, i) => {
              const items = c.scripts.filter(s => s.available);
              return (
                <li key={c.id} className="border-b border-r border-border">
                  <Link href={`/scripts?categories=${c.id}`} className="group flex h-full flex-col gap-3 p-5 transition-colors hover:bg-panel">
                    <div className="flex items-baseline justify-between gap-3">
                      <span className="font-mono text-[11px] text-blood">{String(i + 1).padStart(2, "0")}</span>
                      <span className="font-mono text-[11px] tabular-nums text-muted-foreground">
                        {items.length}
                        {" "}
                        {items.length === 1 ? "script" : "scripts"}
                      </span>
                    </div>
                    <p className="text-[17px] font-semibold group-hover:text-blood">{c.name}</p>
                    <p className="line-clamp-1 text-[13px] text-muted-foreground">
                      {items.slice(0, 5).map(s => s.name).join(", ")}
                      {items.length > 5 ? "…" : ""}
                    </p>
                  </Link>
                </li>
              );
            })}
          </ul>
        </section>

        {/* How it works */}
        <section className="pt-20">
          <SectionHeading index="03" kicker="The rite" title="From search to running service" />
          <ol className="grid gap-px border border-border bg-border lg:grid-cols-3">
            <li className="bg-card p-6">
              <p className="font-display text-3xl font-bold text-blood">{ROMAN[0]}</p>
              <h3 className="mt-4 text-lg font-semibold">Find the script</h3>
              <p className="mt-2 text-[14px] leading-relaxed text-muted-foreground">
                Search or filter by type, category, OS and resources. Every page lists what the container gets, the
                port it listens on and any credentials it sets.
              </p>
              <p className="mt-4 font-mono text-[11.5px] text-muted-foreground">
                Press
                {" "}
                <kbd className="border border-border px-1">⌘K</kbd>
                {" "}
                from anywhere.
              </p>
            </li>
            <li className="bg-card p-6">
              <p className="font-display text-3xl font-bold text-blood">{ROMAN[1]}</p>
              <h3 className="mt-4 text-lg font-semibold">Read it, then copy it</h3>
              <p className="mt-2 text-[14px] leading-relaxed text-muted-foreground">
                Scripts run as root on your host. Each page links the container and install sources on GitHub so you
                can read exactly what will run.
              </p>
              {example && <CommandLine command={installCommand(example.install_methods[0].script)} compact className="mt-4" />}
            </li>
            <li className="bg-card p-6">
              <p className="font-display text-3xl font-bold text-blood">{ROMAN[2]}</p>
              <h3 className="mt-4 text-lg font-semibold">Paste into the PVE shell</h3>
              <p className="mt-2 text-[14px] leading-relaxed text-muted-foreground">
                Choose
                {" "}
                <span className="text-foreground">Default</span>
                {" "}
                for sensible resources and minimal questions, or
                {" "}
                <span className="text-foreground">Advanced</span>
                {" "}
                to set storage, network and sizing yourself. Updateable containers upgrade by running
                {" "}
                <code className="border border-border bg-panel px-1 font-mono text-[12.5px]">update</code>
                {" "}
                inside them.
              </p>
            </li>
          </ol>
        </section>

        {/* FAQ */}
        <section className="grid gap-10 pt-20 lg:grid-cols-[1fr_2fr]" id="faq">
          <div>
            <p className="label-mono mb-2">
              <span className="mr-2 text-blood">04</span>
              Questions
            </p>
            <h2 className="font-display text-2xl font-semibold tracking-tight md:text-[28px]">Before you run anything</h2>
            <p className="mt-4 max-w-sm text-[14px] leading-relaxed text-muted-foreground">
              Still stuck? Ask in
              {" "}
              <a href={externalLinks.discord} className="text-foreground underline decoration-border underline-offset-4 hover:text-blood" target="_blank" rel="noreferrer">Discord</a>
              {" "}
              or
              {" "}
              <a href={externalLinks.issues} className="text-foreground underline decoration-border underline-offset-4 hover:text-blood" target="_blank" rel="noreferrer">open an issue</a>
              .
            </p>
          </div>
          <FAQ />
        </section>
      </div>
    </>
  );
}
