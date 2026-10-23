"use client";

import { useState } from "react";
import Link from "next/link";

import type { CatalogScript } from "@/lib/script-meta";

import { formatRam, installCommand, osLabel, primaryResources, scriptHref } from "@/lib/script-meta";
import { cn } from "@/lib/utils";

import { CopyButton } from "./copy-button";

// The hero's right-hand panel: pick a script, see the exact command and what the
// installer will provision. Everything shown comes from the script's metadata.
export function InstallShowcase({ scripts }: { scripts: CatalogScript[] }) {
  const [active, setActive] = useState(0);
  const s = scripts[active];
  if (!s)
    return null;
  const r = primaryResources(s);
  const command = installCommand(s.install_methods[0].script);
  const os = osLabel(s);

  return (
    <div className="terminal relative w-full overflow-hidden shadow-[0_30px_80px_-40px_rgba(0,0,0,0.8)]">
      <div className="flex items-center justify-between border-b border-[hsl(18_10%_16%)] px-4 py-2.5">
        <div className="flex items-center gap-1.5" aria-hidden>
          <span className="size-2.5 bg-[hsl(356_76%_52%)]" />
          <span className="size-2.5 bg-[hsl(20_10%_25%)]" />
          <span className="size-2.5 bg-[hsl(20_10%_25%)]" />
        </div>
        <span className="font-mono text-[10.5px] uppercase tracking-[0.18em] text-[hsl(30_8%_55%)]">root@pve: ~</span>
      </div>

      <div role="tablist" aria-label="Example scripts" className="flex overflow-x-auto border-b border-[hsl(18_10%_16%)] font-mono text-[12px]">
        {scripts.map((x, i) => (
          <button
            key={x.slug}
            role="tab"
            aria-selected={i === active}
            onClick={() => setActive(i)}
            className={cn(
              "shrink-0 border-r border-[hsl(18_10%_16%)] px-4 py-2 transition-colors",
              i === active ? "bg-[hsl(20_10%_9%)] text-[hsl(36_24%_90%)] shadow-[inset_0_-2px_0_hsl(356_76%_52%)]" : "text-[hsl(30_8%_55%)] hover:text-[hsl(36_24%_86%)]",
            )}
          >
            {x.slug}
          </button>
        ))}
      </div>

      <div className="space-y-1.5 p-5 font-mono text-[12.5px] leading-relaxed">
        <div className="flex items-start gap-3">
          <span className="select-none text-[hsl(356_76%_58%)]">#</span>
          <code className="flex-1 break-all text-[hsl(36_24%_90%)]">{command}</code>
          <CopyButton value={command} label="Copy" className="border border-[hsl(18_10%_22%)] px-2 py-1 text-[hsl(36_24%_80%)] hover:border-[hsl(356_76%_52%)] hover:bg-[hsl(356_76%_52%)] hover:text-white" />
        </div>
        <div className="pt-3 text-[hsl(30_8%_55%)]">
          <p>
            <span className="text-[hsl(172_38%_50%)]">›</span>
            {" "}
            {s.name}
            {" "}
            · default settings
          </p>
          {r != null && Boolean(r.cpu || r.ram || r.hdd) && (
            <p>
              <span className="text-[hsl(172_38%_50%)]">›</span>
              {" "}
              {[r.cpu && `${r.cpu} vCPU`, r.ram && `${formatRam(r.ram)} RAM`, r.hdd && `${r.hdd} GB disk`, os].filter(Boolean).join("  ·  ")}
            </p>
          )}
          {s.interface_port != null && (
            <p>
              <span className="text-[hsl(172_38%_50%)]">›</span>
              {" "}
              web UI on port
              {" "}
              <span className="text-[hsl(40_55%_62%)]">{s.interface_port}</span>
            </p>
          )}
          {s.updateable && (
            <p>
              <span className="text-[hsl(172_38%_50%)]">›</span>
              {" "}
              run
              {" "}
              <span className="text-[hsl(40_55%_62%)]">update</span>
              {" "}
              inside the container to upgrade later
            </p>
          )}
          <p className="pt-1 text-[hsl(36_24%_86%)]">
            <span className="animate-caret">▌</span>
          </p>
        </div>
      </div>
      <div className="flex items-center justify-between border-t border-[hsl(18_10%_16%)] px-5 py-3 font-mono text-[11px] uppercase tracking-[0.14em]">
        <span className="text-[hsl(30_8%_55%)]">Paste into the Proxmox VE shell</span>
        <Link href={scriptHref(s.slug)} className="text-[hsl(36_24%_86%)] hover:text-[hsl(356_76%_62%)]">
          {s.name}
          {" "}
          details →
        </Link>
      </div>
    </div>
  );
}
