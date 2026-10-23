"use client";

import { useQuery } from "@tanstack/react-query";

import { formatDate, REPO, REPO_URL } from "@/lib/script-meta";

type Commit = { sha: string; html_url: string; commit: { message: string; committer: { date: string } } };

// Latest commit touching the script, from the public GitHub API.
export function LastChange({ path }: { path: string }) {
  const { data, isError, isLoading } = useQuery({
    queryKey: ["last-change", path],
    queryFn: async () => {
      const res = await fetch(`https://api.github.com/repos/${REPO}/commits?path=${encodeURIComponent(path)}&per_page=1`);
      if (!res.ok)
        throw new Error(String(res.status));
      const list = (await res.json()) as Commit[];
      return list[0] ?? null;
    },
    staleTime: 60 * 60 * 1000,
    retry: false,
  });

  if (isLoading)
    return <span className="text-muted-foreground">…</span>;
  if (isError || !data)
    return <a href={`${REPO_URL}/commits/main/${path}`} target="_blank" rel="noreferrer" className="hover:text-blood">History →</a>;
  const pr = data.commit.message.match(/\(#(\d+)\)/)?.[1];
  return (
    <a href={data.html_url} target="_blank" rel="noreferrer" className="hover:text-blood" title={data.commit.message.split("\n")[0]}>
      {formatDate(data.commit.committer.date)}
      {" · "}
      {pr ? `PR #${pr}` : data.sha.slice(0, 7)}
    </a>
  );
}
