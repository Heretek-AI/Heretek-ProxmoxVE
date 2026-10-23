import { AlertTriangle, ArrowUpRight } from "lucide-react";
import Link from "next/link";

import type { CatalogScript } from "@/lib/script-meta";

import { formatDate, formatRam, osLabel, primaryResources, reportIssueUrl, sourceLinks, typeMeta } from "@/lib/script-meta";
import { cn } from "@/lib/utils";

import { InstallPanel } from "./install-panel";
import { CopyButton } from "./copy-button";
import { ScriptLogo } from "./script-logo";
import { ScriptCard } from "./script-card";
import { LastChange } from "./last-change";
import { Tag, TypeTag } from "./type-tag";
import { NoteText } from "./note-text";
import { Releases } from "./releases";

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-baseline justify-between gap-4 border-b border-dashed border-border py-2.5 last:border-b-0">
      <dt className="label-mono shrink-0">{label}</dt>
      <dd className="min-w-0 text-right text-[13.5px]">{children}</dd>
    </div>
  );
}

function Panel({ title, children, className }: { title: string; children: React.ReactNode; className?: string }) {
  return (
    <section className={cn("slate p-5", className)}>
      <h2 className="label-mono mb-3 text-foreground">{title}</h2>
      {children}
    </section>
  );
}

type CategoryRef = { id: number; name: string };

// The full script page. Pure presentation, so the JSON editor can render a live preview with it.
export function ScriptView({ script, categories, related = [] }: { script: CatalogScript; categories: CategoryRef[]; related?: CatalogScript[] }) {
  const r = primaryResources(script);
  const os = osLabel(script);
  const meta = typeMeta(script.type);
  const scriptPath = script.install_methods?.[0]?.script;
  const creds = script.default_credentials ?? { username: null, password: null };
  const notes = script.notes ?? [];
  // Warnings go first and get the hazard treatment; plain information reads as a list.
  const cautions = notes.filter(n => n.type === "warning" || n.type === "danger");
  const infos = notes.filter(n => n.type !== "warning" && n.type !== "danger");
  const firstCategory = categories.find(c => script.categories.includes(c.id));

  const anchors = [
    { id: "install", label: "Install" },
    ...(notes.length ? [{ id: "notes", label: `Notes (${notes.length})` }] : []),
    ...(script.version ? [{ id: "releases", label: "Releases" }] : []),
    { id: "details", label: "Details" },
    ...(related.length ? [{ id: "related", label: "Related" }] : []),
  ];

  return (
    <article>
      {/* Header */}
      <header className="relative border-b border-border">
        <div className="grid-lines pointer-events-none absolute inset-0 [mask-image:linear-gradient(to_bottom,black,transparent)]" aria-hidden />
        <div className="relative mx-auto max-w-[1440px] px-4 pb-8 pt-8 md:px-6 md:pt-10">
          <nav aria-label="Breadcrumb" className="mb-8 font-mono text-[11.5px] uppercase tracking-[0.14em] text-muted-foreground">
            <Link href="/scripts" className="hover:text-foreground">Scripts</Link>
            {firstCategory && (
              <>
                <span className="px-2 text-border">/</span>
                <Link href={`/scripts?categories=${firstCategory.id}`} className="hover:text-foreground">{firstCategory.name}</Link>
              </>
            )}
            <span className="px-2 text-border">/</span>
            <span className="text-foreground">{script.name}</span>
          </nav>

          <div className="flex flex-col gap-6 md:flex-row md:items-start">
            <div className="slate flex size-24 shrink-0 items-center justify-center bg-panel">
              <ScriptLogo src={script.logo} alt={`${script.name} logo`} size={60} />
            </div>
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-2">
                <TypeTag type={script.type} long />
                {script.updateable && <Tag className="border-verdigris/40 text-verdigris">Updateable</Tag>}
                <Tag>{script.privileged ? "Privileged" : "Unprivileged"}</Tag>
                {os != null && <Tag>{os}</Tag>}
                {!script.available && <Tag className="border-blood/50 text-blood">Script missing</Tag>}
                {script.categories.map((id) => {
                  const c = categories.find(x => x.id === id);
                  return c && (
                    <Link key={id} href={`/scripts?categories=${id}`} className="inline-flex h-5 items-center px-1 text-[12.5px] text-muted-foreground underline decoration-border underline-offset-4 hover:text-foreground">
                      {c.name}
                    </Link>
                  );
                })}
              </div>
              <h1 className="mt-3 font-display text-4xl font-bold tracking-tight md:text-5xl">{script.name}</h1>
              <p className="mt-3 max-w-3xl text-[16.5px] leading-relaxed text-muted-foreground">{script.description}</p>
              <div className="mt-5 flex flex-wrap gap-2">
                {script.website ? <HeaderLink href={script.website}>Website</HeaderLink> : null}
                {script.documentation ? <HeaderLink href={script.documentation}>Docs</HeaderLink> : null}
                {script.version && <HeaderLink href={`https://github.com/${script.version.repo}`}>Upstream repo</HeaderLink>}
                {Boolean(scriptPath) && <HeaderLink href={sourceLinks(script)[0].href}>Source</HeaderLink>}
                <HeaderLink href={reportIssueUrl(script)} className="border-blood/50 text-blood hover:bg-blood hover:text-primary-foreground">Report issue</HeaderLink>
              </div>
            </div>
          </div>
        </div>

        {/* Local section nav */}
        <nav aria-label="On this page" className="relative border-t border-border">
          <ul className="mx-auto flex max-w-[1440px] gap-6 overflow-x-auto px-4 font-mono text-[11.5px] uppercase tracking-[0.14em] text-muted-foreground md:px-6">
            {anchors.map(a => (
              <li key={a.id}>
                <a href={`#${a.id}`} className="block whitespace-nowrap py-3 hover:text-foreground">{a.label}</a>
              </li>
            ))}
          </ul>
        </nav>
      </header>

      <div className="mx-auto grid max-w-[1440px] gap-10 px-4 pt-10 md:px-6 lg:grid-cols-[minmax(0,1fr)_400px]">
        {/* Main column */}
        <div className="min-w-0 space-y-14">
          <section id="install" className="scroll-mt-28">
            <h2 className="mb-4 font-display text-2xl font-semibold">Install</h2>
            <InstallPanel script={script} />
          </section>

          {notes.length > 0 && (
            <section id="notes" className="scroll-mt-28">
              <h2 className="mb-4 font-display text-2xl font-semibold">Notes</h2>
              {cautions.length > 0 && (
                <ul className="mb-5 space-y-2">
                  {cautions.map(n => (
                    <li key={n.text} className={cn("flex gap-3 border px-4 py-3 text-[14px] leading-relaxed", n.type === "danger" ? "hazard-edge border-blood/50 bg-blood/[0.07] pl-6" : "hazard-edge border-rust/45 bg-rust/[0.06] pl-6")}>
                      <AlertTriangle className={cn("mt-[3px] size-4 shrink-0", n.type === "danger" ? "text-blood" : "text-rust")} aria-hidden />
                      <span className="min-w-0">
                        <span className="sr-only">Warning: </span>
                        <NoteText text={n.text} />
                      </span>
                    </li>
                  ))}
                </ul>
              )}
              {infos.length > 0 && (
                <ul className="divide-y divide-dashed divide-border border-y border-border">
                  {infos.map(n => (
                    <li key={n.text} className="flex gap-3 py-2.5 text-[14px] leading-relaxed">
                      <span className={cn("mt-[9px] size-1.5 shrink-0", n.type === "success" ? "bg-verdigris" : "bg-muted-foreground/60")} aria-hidden />
                      <span className="min-w-0"><NoteText text={n.text} /></span>
                    </li>
                  ))}
                </ul>
              )}
            </section>
          )}

          {script.version && (
            <section id="releases" className="scroll-mt-28">
              <h2 className="mb-4 font-display text-2xl font-semibold">What&apos;s new upstream</h2>
              <Releases repo={script.version.repo} installed={script.version.version} />
            </section>
          )}

          <section id="details" className="scroll-mt-28">
            <h2 className="mb-4 font-display text-2xl font-semibold">Script details</h2>
            <dl className="grid border-l border-t border-border sm:grid-cols-2">
              {[
                ["Type", meta.long],
                ["Runs in", meta.runsIn],
                ["Added", formatDate(script.date_created)],
                ["Slug", <code key="slug" className="font-mono text-[13px]">{script.slug}</code>],
                ...sourceLinks(script).map(l => [l.label, <ViewLink key={l.href} href={l.href} />] as const),
                ...(scriptPath ? [["Last change", <LastChange key="lc" path={scriptPath} />] as const] : []),
              ].map(([k, v]) => (
                <div key={k as string} className="flex items-baseline justify-between gap-4 border-b border-r border-border px-4 py-3">
                  <dt className="label-mono">{k}</dt>
                  <dd className="text-right text-[14px]">{v}</dd>
                </div>
              ))}
            </dl>
          </section>
        </div>

        {/* Side rail */}
        <aside className="space-y-5 lg:sticky lg:top-32 lg:self-start">
          <Panel title="Default resources">
            <dl>
              <Row label="CPU">{r?.cpu != null ? `${r.cpu} vCPU` : "—"}</Row>
              <Row label="Memory">{formatRam(r?.ram) ?? "—"}</Row>
              <Row label="Disk">{r?.hdd != null ? `${r.hdd} GB` : "—"}</Row>
              <Row label="OS">{os ?? (script.type === "addon" ? "Existing LXC or host" : "Proxmox VE host")}</Row>
            </dl>
          </Panel>

          {(script.interface_port != null || script.config_path) && (
            <Panel title="Access">
              <dl>
                {script.interface_port != null && (
                  <Row label="Web UI">
                    <span className="inline-flex items-center gap-2 font-mono text-[13px]">
                      http://&lt;ip&gt;:
                      {script.interface_port}
                      <CopyButton value={String(script.interface_port)} what="Port" className="text-muted-foreground hover:text-foreground" />
                    </span>
                  </Row>
                )}
                {Boolean(script.config_path) && (
                  <Row label="Config">
                    <span className="inline-flex max-w-full items-center gap-2 font-mono text-[12.5px]">
                      <span className="truncate" title={script.config_path}>{script.config_path}</span>
                      <CopyButton value={script.config_path} what="Path" className="text-muted-foreground hover:text-foreground" />
                    </span>
                  </Row>
                )}
              </dl>
            </Panel>
          )}

          {Boolean(creds.username || creds.password) && (
            <Panel title="Default login" className="border-brass/40">
              <dl>
                {Boolean(creds.username) && (
                  <Row label="User">
                    <span className="inline-flex items-center gap-2 font-mono text-[13px]">
                      {creds.username}
                      <CopyButton value={creds.username ?? ""} what="Username" className="text-muted-foreground hover:text-foreground" />
                    </span>
                  </Row>
                )}
                {Boolean(creds.password) && (
                  <Row label="Password">
                    <span className="inline-flex items-center gap-2 font-mono text-[13px]">
                      {creds.password}
                      <CopyButton value={creds.password ?? ""} what="Password" className="text-muted-foreground hover:text-foreground" />
                    </span>
                  </Row>
                )}
              </dl>
              <p className="mt-3 text-[12.5px] text-muted-foreground">Change these after your first login.</p>
            </Panel>
          )}

          {script.version && (
            <Panel title="Tracked version">
              <dl>
                <Row label="Version"><span className="font-mono">{script.version.version}</span></Row>
                <Row label="Released">{formatDate(script.version.date)}</Row>
                <Row label="Pinned">{script.version.pinned ? <span className="text-brass">Yes</span> : "No"}</Row>
              </dl>
            </Panel>
          )}
        </aside>
      </div>

      {related.length > 0 && (
        <section id="related" className="mx-auto max-w-[1440px] scroll-mt-28 px-4 pt-16 md:px-6">
          <div className="mb-6 flex items-end justify-between border-b border-border pb-3">
            <h2 className="font-display text-2xl font-semibold">You might also need</h2>
          </div>
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            {related.map(s => <ScriptCard key={s.slug} script={s} />)}
          </div>
        </section>
      )}
    </article>
  );
}

function HeaderLink({ href, children, className }: { href: string; children: React.ReactNode; className?: string }) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noreferrer"
      className={cn("inline-flex h-8 items-center gap-1.5 border border-border bg-card px-3 text-[13px] transition-colors hover:border-foreground/40", className)}
    >
      {children}
      <ArrowUpRight className="size-3.5" />
    </a>
  );
}

function ViewLink({ href }: { href: string }) {
  return (
    <a href={href} target="_blank" rel="noreferrer" className="inline-flex items-center gap-1 hover:text-blood">
      View
      <ArrowUpRight className="size-3.5" />
    </a>
  );
}
