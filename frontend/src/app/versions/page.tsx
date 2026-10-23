import type { Metadata } from "next";

import Link from "next/link";

import { ScriptLogo } from "@/components/heretek/script-logo";
import { formatDate, scriptHref } from "@/lib/script-meta";
import { loadCatalog } from "@/lib/catalog";

export const metadata: Metadata = {
  title: "Version ledger | Heretek-AI",
  description: "The upstream version each Heretek-AI script installs, and when it was released.",
};

export default function VersionsPage() {
  const { scripts, versionsGenerated } = loadCatalog();
  const rows = scripts
    .filter(s => s.version)
    .sort((a, b) => (b.version!.date ?? "").localeCompare(a.version!.date ?? ""));
  const pinned = rows.filter(s => s.version!.pinned).length;
  const untracked = scripts.filter(s => !s.version && s.available);

  return (
    <div className="mx-auto max-w-[1440px] px-4 md:px-6">
      <header className="border-b border-border py-10 md:py-14">
        <p className="label-mono mb-3">
          <span className="text-blood">⛧</span>
          {" "}
          Ledger
        </p>
        <h1 className="font-display text-4xl font-bold tracking-tight md:text-5xl">Versions</h1>
        <p className="mt-3 max-w-2xl text-[16px] text-muted-foreground">
          The upstream release each script tracks, newest first.
          {" "}
          {pinned > 0 ? `${pinned} pinned to a fixed version.` : "None are pinned right now."}
          {versionsGenerated && ` Last checked ${formatDate(versionsGenerated)}.`}
        </p>
      </header>

      <div className="mt-8 overflow-x-auto border border-border">
        <table className="w-full min-w-[640px] text-left text-[14px]">
          <thead className="bg-panel">
            <tr className="label-mono">
              <th className="px-4 py-3 font-medium">Script</th>
              <th className="px-4 py-3 font-medium">Version</th>
              <th className="px-4 py-3 font-medium">Released</th>
              <th className="px-4 py-3 font-medium">Upstream</th>
              <th className="px-4 py-3 font-medium">Pinned</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-border">
            {rows.map(s => (
              <tr key={s.slug} className="bg-card hover:bg-panel">
                <td className="px-4 py-3">
                  <Link href={scriptHref(s.slug)} className="flex items-center gap-3 font-medium hover:text-blood">
                    <ScriptLogo src={s.logo} alt="" size={20} />
                    {s.name}
                  </Link>
                </td>
                <td className="px-4 py-3 font-mono text-[13px]">
                  <a href={`https://github.com/${s.version!.repo}/releases/tag/${encodeURIComponent(s.version!.version)}`} target="_blank" rel="noreferrer" className="hover:text-blood">
                    {s.version!.version}
                  </a>
                </td>
                <td className="px-4 py-3 font-mono text-[13px] text-muted-foreground">{formatDate(s.version!.date)}</td>
                <td className="px-4 py-3 font-mono text-[13px] text-muted-foreground">
                  <a href={`https://github.com/${s.version!.repo}`} target="_blank" rel="noreferrer" className="hover:text-foreground">{s.version!.repo}</a>
                </td>
                <td className="px-4 py-3 font-mono text-[12px]">{s.version!.pinned ? <span className="text-brass">PINNED</span> : <span className="text-muted-foreground">—</span>}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {untracked.length > 0 && (
        <p className="mt-6 text-[13px] text-muted-foreground">
          <span className="label-mono mr-2">Not tracked:</span>
          {untracked.map(s => s.name).join(" · ")}
        </p>
      )}
    </div>
  );
}
