"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";

import { formatDate } from "@/lib/script-meta";

type Release = { id: number; tag_name: string; name: string | null; html_url: string; published_at: string; body: string | null; prerelease: boolean };

// Upstream releases are fetched in the browser from the public GitHub API
// (60 requests an hour per visitor), so the page stays static.
export function Releases({ repo, installed }: { repo: string; installed: string | null }) {
  const [showAll, setShowAll] = useState(false);
  const { data, isLoading, isError } = useQuery({
    queryKey: ["releases", repo],
    queryFn: async () => {
      const res = await fetch(`https://api.github.com/repos/${repo}/releases?per_page=6`, { headers: { Accept: "application/vnd.github+json" } });
      if (!res.ok)
        throw new Error(String(res.status));
      return (await res.json()) as Release[];
    },
    staleTime: 60 * 60 * 1000,
    retry: false,
  });

  if (isLoading)
    return <p className="label-mono py-6">Fetching releases from GitHub…</p>;
  if (isError || !data?.length) {
    return (
      <p className="py-4 text-[14px] text-muted-foreground">
        Releases could not be loaded right now.
        {" "}
        <a href={`https://github.com/${repo}/releases`} target="_blank" rel="noreferrer" className="text-foreground underline underline-offset-4 hover:text-blood">See them on GitHub</a>
        .
      </p>
    );
  }

  const shown = showAll ? data : data.slice(0, 3);
  return (
    <div>
      <p className="mb-4 text-[13px] text-muted-foreground">
        Releases of
        {" "}
        <a href={`https://github.com/${repo}`} target="_blank" rel="noreferrer" className="font-mono text-foreground hover:text-blood">{repo}</a>
        . The script may pin an older version for stability.
      </p>
      <ol className="border-l border-border">
        {shown.map((r, i) => <ReleaseItem key={r.id} release={r} latest={i === 0} installed={installed === r.tag_name} />)}
      </ol>
      <div className="mt-4 flex gap-5 pl-5 font-mono text-[11px] uppercase tracking-[0.14em]">
        {data.length > 3 && (
          <button type="button" onClick={() => setShowAll(v => !v)} className="text-muted-foreground hover:text-foreground">
            {showAll ? "Show fewer" : `Show ${data.length - 3} older`}
          </button>
        )}
        <a href={`https://github.com/${repo}/releases`} target="_blank" rel="noreferrer" className="text-blood hover:underline">All release notes →</a>
      </div>
    </div>
  );
}

function ReleaseItem({ release, latest, installed }: { release: Release; latest: boolean; installed: boolean }) {
  const [open, setOpen] = useState(false);
  // Release notes are Markdown; show them as readable plain text.
  const body = (release.body ?? "")
    .replace(/<!--[\s\S]*?-->/g, "")
    .replace(/^#{1,6}\s*/gm, "")
    .replace(/^\s*[*-]\s+/gm, "• ")
    .replace(/\*\*([^*]+)\*\*/g, "$1")
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .trim();
  return (
    <li className="relative pb-6 pl-5 last:pb-0">
      <span className={`absolute -left-[4.5px] top-1.5 size-2 ${latest ? "bg-blood" : "bg-border"}`} aria-hidden />
      <div className="flex flex-wrap items-baseline gap-x-3 gap-y-1">
        <a href={release.html_url} target="_blank" rel="noreferrer" className="font-mono text-[14px] font-medium hover:text-blood">{release.tag_name}</a>
        {latest && <span className="font-mono text-[10px] uppercase tracking-[0.14em] text-blood">Latest</span>}
        {installed && <span className="font-mono text-[10px] uppercase tracking-[0.14em] text-verdigris">Tracked by script</span>}
        {release.prerelease && <span className="font-mono text-[10px] uppercase tracking-[0.14em] text-brass">Pre-release</span>}
        <span className="font-mono text-[11px] text-muted-foreground">{formatDate(release.published_at)}</span>
      </div>
      {body.length > 0 && (
        <>
          <pre className={`mt-2 whitespace-pre-wrap break-words font-sans text-[13px] leading-relaxed text-muted-foreground ${open ? "" : "line-clamp-3"}`}>{body}</pre>
          {body.length > 200 && (
            <button type="button" onClick={() => setOpen(o => !o)} className="mt-1 font-mono text-[11px] uppercase tracking-[0.14em] text-muted-foreground hover:text-foreground">
              {open ? "Collapse" : "Read more"}
            </button>
          )}
        </>
      )}
    </li>
  );
}
