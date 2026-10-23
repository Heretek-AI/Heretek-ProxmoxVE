"use client";

import { useState } from "react";

import type { CatalogScript } from "@/lib/script-meta";

import { installCommand, typeMeta } from "@/lib/script-meta";
import { cn } from "@/lib/utils";

import { CommandLine } from "./command-line";

const METHOD_LABEL: Record<string, string> = { default: "Default", alpine: "Alpine" };

export function InstallPanel({ script }: { script: CatalogScript }) {
  const methods = script.install_methods.filter(m => m.script);
  const [active, setActive] = useState(0);
  const method = methods[active];

  if (!script.available || !method) {
    return (
      <div className="hazard-edge border border-rust/50 bg-rust/[0.06] p-4 pl-6 text-[14px]">
        <p className="font-semibold">Install script not found</p>
        <p className="mt-1 text-muted-foreground">
          This entry&apos;s script file is missing from the repository, so there is no command to run yet.
        </p>
      </div>
    );
  }

  return (
    <div>
      {methods.length > 1 && (
        <div role="tablist" aria-label="Install method" className="mb-3 flex gap-1">
          {methods.map((m, i) => (
            <button
              key={m.type}
              role="tab"
              type="button"
              aria-selected={i === active}
              onClick={() => setActive(i)}
              className={cn(
                "border px-3 py-1.5 font-mono text-[11px] uppercase tracking-[0.14em] transition-colors",
                i === active ? "border-foreground bg-foreground text-background" : "border-border text-muted-foreground hover:text-foreground",
              )}
            >
              {METHOD_LABEL[m.type] ?? m.type}
            </button>
          ))}
        </div>
      )}
      <CommandLine command={installCommand(method.script)} />
      <p className="mt-3 text-[13px] leading-relaxed text-muted-foreground">
        Run as root in the
        {" "}
        <span className="text-foreground">{typeMeta(script.type).runsIn}</span>
        .
        {" "}
        {script.type === "ct" && "Pick Default for the sizing below, or Advanced to choose storage, network and resources yourself."}
        {method.type === "alpine" && " The Alpine variant is smaller and starts faster, and follows Alpine's package updates."}
      </p>
    </div>
  );
}
