"use client";

import { parseAsArrayOf, parseAsBoolean, parseAsInteger, parseAsString, parseAsStringLiteral, useQueryStates } from "nuqs";
import { LayoutGrid, List, Search, SlidersHorizontal, X } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import Link from "next/link";

import type { CatalogScript } from "@/lib/script-meta";

import { formatDate, installCommand, normalizedType, osLabel, primaryResources, scriptHref, TYPE_FILTERS } from "@/lib/script-meta";
import { cn } from "@/lib/utils";

import { ResourceLine, ScriptCard } from "./script-card";
import { CopyButton } from "./copy-button";
import { ScriptLogo } from "./script-logo";
import { TypeTag } from "./type-tag";

const SORTS = ["name", "newest", "updated", "lightest", "heaviest"] as const;
const SORT_LABELS: Record<(typeof SORTS)[number], string> = {
  name: "Name A–Z",
  newest: "Newest first",
  updated: "Recent upstream release",
  lightest: "Lightest (RAM)",
  heaviest: "Heaviest (RAM)",
};
const RAM_STEPS = [2048, 4096, 8192, 16384];

const params = {
  search: parseAsString.withDefault(""),
  types: parseAsArrayOf(parseAsString).withDefault([]),
  categories: parseAsArrayOf(parseAsInteger).withDefault([]),
  os: parseAsArrayOf(parseAsString).withDefault([]),
  updateable: parseAsBoolean.withDefault(false),
  webui: parseAsBoolean.withDefault(false),
  creds: parseAsBoolean.withDefault(false),
  unavailable: parseAsBoolean.withDefault(false),
  maxRam: parseAsInteger,
  sort: parseAsStringLiteral(SORTS).withDefault("name"),
  view: parseAsStringLiteral(["grid", "list"] as const).withDefault("grid"),
};

type CategoryOption = { id: number; name: string };

function matchesSearch(s: CatalogScript, q: string) {
  const words = q.toLowerCase().split(/\s+/).filter(Boolean);
  if (!words.length)
    return true;
  const hay = `${s.name} ${s.slug} ${s.description} ${s.categoryNames.join(" ")} ${osLabel(s) ?? ""}`.toLowerCase();
  return words.every(w => hay.includes(w));
}

export function Catalog({ scripts, categories }: { scripts: CatalogScript[]; categories: CategoryOption[] }) {
  const [state, setState] = useQueryStates(params, { history: "replace" });
  const [filtersOpen, setFiltersOpen] = useState(false);
  const searchRef = useRef<HTMLInputElement>(null);
  const router = useRouter();
  const legacyId = useSearchParams().get("id");

  // Old links used /scripts?id=<slug>; send them to the script's own page.
  useEffect(() => {
    if (legacyId)
      router.replace(scriptHref(legacyId));
  }, [legacyId, router]);

  // "/" focuses search, like most catalogue sites.
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement;
      if (e.key === "/" && !["INPUT", "TEXTAREA", "SELECT"].includes(target.tagName) && !target.isContentEditable) {
        e.preventDefault();
        searchRef.current?.focus();
      }
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, []);

  const osOptions = useMemo(() => Array.from(new Set(scripts.map(osLabel).filter(Boolean) as string[])).sort((a, b) => a.localeCompare(b)), [scripts]);

  // Filters are applied in groups so each facet can show how many results it
  // would have with every *other* facet applied.
  const predicates = useMemo(() => ({
    search: (s: CatalogScript) => matchesSearch(s, state.search),
    types: (s: CatalogScript) => !state.types.length || state.types.includes(normalizedType(s.type)),
    categories: (s: CatalogScript) => !state.categories.length || s.categories.some(id => state.categories.includes(id)),
    os: (s: CatalogScript) => !state.os.length || state.os.includes(osLabel(s) ?? ""),
    flags: (s: CatalogScript) =>
      (!state.updateable || s.updateable)
      && (!state.webui || s.interface_port != null)
      && (!state.creds || !!(s.default_credentials?.username || s.default_credentials?.password)),
    available: (s: CatalogScript) => state.unavailable || s.available,
    ram: (s: CatalogScript) => state.maxRam == null || (primaryResources(s)?.ram ?? 0) <= state.maxRam,
  }), [state]);

  const passesExcept = (s: CatalogScript, skip?: keyof typeof predicates) =>
    (Object.keys(predicates) as (keyof typeof predicates)[]).every(k => k === skip || predicates[k](s));

  const results = useMemo(() => {
    const list = scripts.filter(s => passesExcept(s));
    const ram = (s: CatalogScript) => primaryResources(s)?.ram ?? 0;
    const sorters: Record<(typeof SORTS)[number], (a: CatalogScript, b: CatalogScript) => number> = {
      name: (a, b) => a.name.localeCompare(b.name),
      newest: (a, b) => b.date_created.localeCompare(a.date_created),
      updated: (a, b) => (b.version?.date ?? "").localeCompare(a.version?.date ?? ""),
      lightest: (a, b) => ram(a) - ram(b),
      heaviest: (a, b) => ram(b) - ram(a),
    };
    return list.sort(sorters[state.sort]);
  }, [scripts, predicates, state.sort]);

  const count = (skip: keyof typeof predicates, test: (s: CatalogScript) => boolean) =>
    scripts.filter(s => passesExcept(s, skip) && test(s)).length;

  const toggle = <T,>(list: T[], value: T) => (list.includes(value) ? list.filter(v => v !== value) : [...list, value]);

  const unavailableCount = scripts.filter(s => !s.available).length;

  const chips: { label: string; clear: () => void }[] = [
    ...(state.search ? [{ label: `“${state.search}”`, clear: () => setState({ search: null }) }] : []),
    ...state.types.map(t => ({ label: TYPE_FILTERS.find(f => f.value === t)?.label ?? t, clear: () => setState({ types: state.types.filter(x => x !== t) }) })),
    ...state.categories.map(id => ({ label: categories.find(c => c.id === id)?.name ?? `#${id}`, clear: () => setState({ categories: state.categories.filter(x => x !== id) }) })),
    ...state.os.map(o => ({ label: o, clear: () => setState({ os: state.os.filter(x => x !== o) }) })),
    ...(state.updateable ? [{ label: "Self-updating", clear: () => setState({ updateable: null }) }] : []),
    ...(state.webui ? [{ label: "Has web UI", clear: () => setState({ webui: null }) }] : []),
    ...(state.creds ? [{ label: "Default login", clear: () => setState({ creds: null }) }] : []),
    ...(state.maxRam != null ? [{ label: `≤ ${state.maxRam / 1024} GB RAM`, clear: () => setState({ maxRam: null }) }] : []),
  ];

  const clearAll = () => setState({ search: null, types: null, categories: null, os: null, updateable: null, webui: null, creds: null, maxRam: null, unavailable: null });

  const filterRail = (
    <div className="space-y-8">
      <FilterGroup title="Type">
        {TYPE_FILTERS.map(t => (
          <Check
            key={t.value}
            checked={state.types.includes(t.value)}
            onChange={() => setState({ types: toggle(state.types, t.value) })}
            label={<TypeTag type={t.value} />}
            count={count("types", s => normalizedType(s.type) === t.value)}
          />
        ))}
      </FilterGroup>

      <FilterGroup title="Category">
        {categories.map(c => (
          <Check
            key={c.id}
            checked={state.categories.includes(c.id)}
            onChange={() => setState({ categories: toggle(state.categories, c.id) })}
            label={c.name}
            count={count("categories", s => s.categories.includes(c.id))}
          />
        ))}
      </FilterGroup>

      {osOptions.length > 0 && (
        <FilterGroup title="Base OS">
          {osOptions.map(o => (
            <Check
              key={o}
              checked={state.os.includes(o)}
              onChange={() => setState({ os: toggle(state.os, o) })}
              label={o}
              count={count("os", s => osLabel(s) === o)}
            />
          ))}
        </FilterGroup>
      )}

      <FilterGroup title="Memory budget">
        <div className="flex flex-wrap gap-1.5">
          {[null, ...RAM_STEPS].map(v => (
            <button
              key={v ?? "any"}
              type="button"
              onClick={() => setState({ maxRam: v })}
              aria-pressed={state.maxRam === v}
              className={cn(
                "border px-2 py-1 font-mono text-[11px] transition-colors",
                state.maxRam === v ? "border-blood bg-blood text-primary-foreground" : "border-border text-muted-foreground hover:border-foreground/40 hover:text-foreground",
              )}
            >
              {v == null ? "Any" : `≤ ${v / 1024} GB`}
            </button>
          ))}
        </div>
      </FilterGroup>

      <FilterGroup title="Features">
        <Check checked={state.updateable} onChange={() => setState({ updateable: !state.updateable || null })} label="Self-updating" count={count("flags", s => s.updateable)} />
        <Check checked={state.webui} onChange={() => setState({ webui: !state.webui || null })} label="Has web UI" count={count("flags", s => s.interface_port != null)} />
        <Check checked={state.creds} onChange={() => setState({ creds: !state.creds || null })} label="Default login" count={count("flags", s => !!(s.default_credentials?.username || s.default_credentials?.password))} />
        {unavailableCount > 0 && (
          <Check checked={state.unavailable} onChange={() => setState({ unavailable: !state.unavailable || null })} label="Show unavailable" count={unavailableCount} />
        )}
      </FilterGroup>
    </div>
  );

  return (
    <div className="grid gap-10 lg:grid-cols-[250px_1fr]">
      <aside className="hidden lg:block" aria-label="Filters">
        <div className="pb-8">{filterRail}</div>
      </aside>

      <div className="min-w-0">
        {/* Toolbar */}
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center">
          <label className="flex h-11 w-full shrink-0 items-center gap-3 border sm:w-auto sm:flex-1 border-foreground/25 bg-card px-3 focus-within:border-blood">
            <Search className="size-4 text-muted-foreground" />
            <span className="sr-only">Search scripts</span>
            <input
              ref={searchRef}
              value={state.search}
              onChange={e => setState({ search: e.target.value || null })}
              placeholder="Filter by name, purpose or OS"
              className="min-w-0 flex-1 bg-transparent text-[15px] outline-none placeholder:text-muted-foreground/80"
              autoComplete="off"
            />
            {state.search
              ? (
                  <button type="button" onClick={() => setState({ search: null })} aria-label="Clear search" className="text-muted-foreground hover:text-foreground">
                    <X className="size-4" />
                  </button>
                )
              : <kbd className="hidden border border-border px-1.5 font-mono text-[10px] text-muted-foreground sm:inline">/</kbd>}
          </label>
          <div className="flex min-w-0 items-center gap-2">
            <button
              type="button"
              onClick={() => setFiltersOpen(o => !o)}
              className="flex h-11 items-center gap-2 border border-border px-3 text-[13px] lg:hidden"
              aria-expanded={filtersOpen}
            >
              <SlidersHorizontal className="size-4" />
              Filters
              {chips.length > 0 && <span className="bg-blood px-1.5 font-mono text-[10px] text-primary-foreground">{chips.length}</span>}
            </button>
            <label className="relative flex h-11 min-w-0 flex-1 items-center border border-border sm:flex-none">
              <span className="sr-only">Sort</span>
              <select
                value={state.sort}
                onChange={e => setState({ sort: e.target.value as (typeof SORTS)[number] })}
                className="h-full w-full min-w-0 appearance-none bg-transparent pl-3 pr-8 text-[13px] outline-none"
              >
                {SORTS.map(s => <option key={s} value={s} className="bg-popover">{SORT_LABELS[s]}</option>)}
              </select>
              <span className="pointer-events-none absolute right-3 text-[10px] text-muted-foreground">▼</span>
            </label>
            <div className="flex h-11 shrink-0 border border-border" role="group" aria-label="View">
              {(["grid", "list"] as const).map(v => (
                <button
                  key={v}
                  type="button"
                  onClick={() => setState({ view: v === "grid" ? null : v })}
                  aria-pressed={state.view === v}
                  aria-label={v === "grid" ? "Grid view" : "List view"}
                  className={cn("flex w-11 items-center justify-center transition-colors", state.view === v ? "bg-foreground text-background" : "text-muted-foreground hover:text-foreground")}
                >
                  {v === "grid" ? <LayoutGrid className="size-4" /> : <List className="size-4" />}
                </button>
              ))}
            </div>
          </div>
        </div>

        {filtersOpen && <div className="mt-4 border border-border bg-card p-5 lg:hidden">{filterRail}</div>}

        {/* Result summary */}
        <div className="mt-5 flex min-h-8 flex-wrap items-center gap-2 border-b border-border pb-4">
          <p className="mr-2 font-mono text-[12px] uppercase tracking-[0.14em] text-muted-foreground">
            <span className="text-foreground">{results.length}</span>
            {" "}
            {results.length === 1 ? "script" : "scripts"}
          </p>
          {chips.map(c => (
            <button
              key={c.label}
              type="button"
              onClick={c.clear}
              className="inline-flex items-center gap-1.5 border border-border bg-panel px-2 py-1 text-[12px] hover:border-blood"
            >
              {c.label}
              <X className="size-3" />
            </button>
          ))}
          {chips.length > 1 && (
            <button type="button" onClick={clearAll} className="font-mono text-[11px] uppercase tracking-[0.14em] text-blood hover:underline">
              Clear all
            </button>
          )}
        </div>

        {results.length === 0
          ? (
              <div className="py-24 text-center">
                <p className="font-display text-2xl">The archive is silent.</p>
                <p className="mt-2 text-muted-foreground">No script matches these filters.</p>
                <button type="button" onClick={clearAll} className="mt-6 border border-border px-4 py-2 text-[13px] hover:border-blood">
                  Clear filters
                </button>
              </div>
            )
          : state.view === "list"
            ? <ScriptTable scripts={results} />
            : (
                <div className="mt-6 grid gap-4 sm:grid-cols-2 2xl:grid-cols-3">
                  {results.map(s => <ScriptCard key={s.slug} script={s} />)}
                </div>
              )}
      </div>
    </div>
  );
}

function FilterGroup({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <fieldset>
      <legend className="label-mono mb-3 w-full border-b border-border pb-2">{title}</legend>
      <div className="space-y-1">{children}</div>
    </fieldset>
  );
}

function Check({ checked, onChange, label, count }: { checked: boolean; onChange: () => void; label: React.ReactNode; count: number }) {
  return (
    <label className={cn("flex cursor-pointer items-center gap-2.5 py-1 text-[13.5px]", count === 0 && !checked && "opacity-45")}>
      <input type="checkbox" checked={checked} onChange={onChange} className="peer sr-only" />
      <span
        aria-hidden
        className={cn(
          "flex size-3.5 shrink-0 items-center justify-center border peer-focus-visible:outline peer-focus-visible:outline-2 peer-focus-visible:outline-ring",
          checked ? "border-blood bg-blood" : "border-foreground/35",
        )}
      >
        {checked && <span className="size-1.5 bg-primary-foreground" />}
      </span>
      <span className="flex-1 truncate">{label}</span>
      <span className="font-mono text-[11px] tabular-nums text-muted-foreground">{count}</span>
    </label>
  );
}

function ScriptTable({ scripts }: { scripts: CatalogScript[] }) {
  return (
    <div className="mt-6 overflow-x-auto border border-border">
      <table className="w-full min-w-[760px] text-left text-[13.5px]">
        <thead className="bg-panel">
          <tr className="label-mono">
            <th className="px-4 py-2.5 font-medium">Script</th>
            <th className="px-3 py-2.5 font-medium">Type</th>
            <th className="px-3 py-2.5 font-medium">Resources</th>
            <th className="px-3 py-2.5 font-medium">OS</th>
            <th className="px-3 py-2.5 font-medium">Version</th>
            <th className="px-3 py-2.5 font-medium">Added</th>
            <th className="px-4 py-2.5 text-right font-medium">Install</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-border">
          {scripts.map(s => (
            <tr key={s.slug} className={cn("bg-card transition-colors hover:bg-panel", !s.available && "opacity-60")}>
              <td className="px-4 py-2.5">
                <Link href={scriptHref(s.slug)} className="flex items-center gap-3 hover:text-blood">
                  <ScriptLogo src={s.logo} alt="" size={20} />
                  <span className="font-medium">{s.name}</span>
                </Link>
              </td>
              <td className="px-3 py-2.5"><TypeTag type={s.type} /></td>
              <td className="px-3 py-2.5 font-mono text-[12px] text-muted-foreground"><ResourceLine script={s} /></td>
              <td className="px-3 py-2.5 text-muted-foreground">{osLabel(s) ?? "—"}</td>
              <td className="px-3 py-2.5 font-mono text-[12px]">{s.version?.version ?? "—"}</td>
              <td className="px-3 py-2.5 font-mono text-[12px] text-muted-foreground">{formatDate(s.date_created)}</td>
              <td className="px-4 py-2.5 text-right">
                {s.available && s.install_methods[0]?.script
                  ? <CopyButton value={installCommand(s.install_methods[0].script)} label="Copy" className="border border-border px-2 py-1 hover:border-blood hover:bg-blood hover:text-primary-foreground" />
                  : <span className="font-mono text-[11px] text-blood">Unavailable</span>}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
