import Link from "next/link";

import type { CatalogScript } from "@/lib/script-meta";

import { formatRam, installCommand, osLabel, primaryResources, scriptHref } from "@/lib/script-meta";
import { cn } from "@/lib/utils";

import { CopyButton } from "./copy-button";
import { ScriptLogo } from "./script-logo";
import { TypeTag } from "./type-tag";

export function ResourceLine({ script, className }: { script: CatalogScript; className?: string }) {
  const r = primaryResources(script);
  if (!r || (r.cpu == null && r.ram == null && r.hdd == null))
    return <span className={cn("text-muted-foreground", className)}>Runs on host</span>;
  return (
    <span className={cn("tabular-nums", className)}>
      {r.cpu != null && (
        <span>
          {r.cpu}
          {" "}
          CPU
        </span>
      )}
      {r.ram != null && (
        <span>
          <span className="px-1.5 text-border">/</span>
          {formatRam(r.ram)}
        </span>
      )}
      {r.hdd != null && (
        <span>
          <span className="px-1.5 text-border">/</span>
          {r.hdd}
          {" "}
          GB
        </span>
      )}
    </span>
  );
}

export function ScriptCard({ script, className }: { script: CatalogScript; className?: string }) {
  const command = script.install_methods?.[0]?.script ? installCommand(script.install_methods[0].script) : null;
  const os = osLabel(script);
  return (
    <article
      className={cn(
        "group relative flex flex-col border border-border bg-card transition-colors hover:border-foreground/35",
        !script.available && "opacity-60",
        className,
      )}
    >
      <div className="flex items-start gap-3 p-4 pb-3">
        <div className="flex size-11 shrink-0 items-center justify-center border border-border bg-panel">
          <ScriptLogo src={script.logo} alt="" size={28} />
        </div>
        <div className="min-w-0 flex-1">
          <div className="flex items-start justify-between gap-2">
            <h3 className="truncate text-[15px] font-semibold leading-tight">
              <Link href={scriptHref(script.slug)} className="after:absolute after:inset-0 focus-visible:outline-none group-focus-within:underline">
                {script.name}
              </Link>
            </h3>
            <TypeTag type={script.type} />
          </div>
          <p className="mt-1 truncate font-mono text-[11px] text-muted-foreground">
            {script.categoryNames[0] ?? "Uncategorised"}
            {os != null && <span>{` · ${os}`}</span>}
          </p>
        </div>
      </div>
      <p className="line-clamp-2 px-4 text-[13.5px] leading-relaxed text-muted-foreground">{script.description}</p>
      <div className="mt-auto flex items-center justify-between gap-3 border-t border-dashed border-border px-4 py-2.5 pt-2.5 font-mono text-[11px] text-muted-foreground [margin-top:theme(spacing.4)]">
        <ResourceLine script={script} />
        <div className="flex items-center gap-3">
          {script.version && <span className="hidden text-foreground/80 sm:inline">{script.version.version}</span>}
          {!script.available
            ? <span className="text-blood">Unavailable</span>
            : command && (
              <CopyButton
                value={command}
                label="Copy"
                className="relative z-10 border border-border px-2 py-1 text-foreground hover:border-blood hover:bg-blood hover:text-primary-foreground"
              />
            )}
        </div>
      </div>
    </article>
  );
}
