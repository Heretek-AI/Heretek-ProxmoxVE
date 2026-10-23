import Link from "next/link";

import { basePath, externalLinks } from "@/config/site-config";

const columns: { title: string; links: { href: string; text: string; external?: boolean }[] }[] = [
  {
    title: "Explore",
    links: [
      { href: "/scripts", text: "All scripts" },
      { href: "/scripts?sort=newest", text: "Newest" },
      { href: "/categories", text: "Categories" },
      { href: "/versions", text: "Version ledger" },
    ],
  },
  {
    title: "Tools",
    links: [
      { href: "/generator", text: "Command generator" },
      { href: "/json-editor", text: "JSON editor" },
      { href: "/data", text: "Install data" },
      { href: externalLinks.docs, text: "Docs", external: true },
    ],
  },
  {
    title: "Community",
    links: [
      { href: "/community", text: "News & FAQ" },
      { href: externalLinks.changelog, text: "Changelog", external: true },
      { href: externalLinks.issues, text: "Report an issue", external: true },
      { href: externalLinks.contributing, text: "Contribute", external: true },
    ],
  },
  {
    title: "Connect",
    links: [
      { href: externalLinks.github, text: "GitHub", external: true },
      { href: externalLinks.discord, text: "Discord", external: true },
      { href: `/${basePath}/rss.xml`, text: "New scripts (RSS)", external: true },
    ],
  },
];

export function SiteFooter() {
  return (
    <footer className="mt-24 border-t border-border bg-panel">
      <div className="mx-auto grid max-w-[1440px] gap-10 px-4 py-12 md:grid-cols-[1.4fr_repeat(4,1fr)] md:px-6">
        <div className="max-w-xs">
          <p className="font-display text-lg font-bold tracking-[0.06em]">HERETEK</p>
          <p className="mt-3 text-[13.5px] leading-relaxed text-muted-foreground">
            Scripts for Proxmox VE that stray from the orthodox catalogue. Built on the work of tteck and the
            {" "}
            <a href={externalLinks.upstream} className="underline decoration-border underline-offset-4 hover:text-foreground" target="_blank" rel="noreferrer">community-scripts</a>
            {" "}
            project. MIT licensed.
          </p>
        </div>
        {columns.map(col => (
          <div key={col.title}>
            <p className="label-mono mb-4">{col.title}</p>
            <ul className="space-y-2.5 text-[13.5px]">
              {col.links.map(l => (
                <li key={l.text}>
                  {l.external
                    ? <a href={l.href} target="_blank" rel="noreferrer" className="text-foreground/80 hover:text-blood">{l.text}</a>
                    : <Link href={l.href} className="text-foreground/80 hover:text-blood">{l.text}</Link>}
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
      <div className="border-t border-border">
        <div className="mx-auto flex max-w-[1440px] flex-col justify-between gap-2 px-4 py-4 font-mono text-[10.5px] uppercase tracking-[0.16em] text-muted-foreground md:flex-row md:px-6">
          <span>In memory of tteck</span>
          <span>
            Only run scripts from
            {" "}
            <span className="text-foreground">heretek-ai.github.io</span>
            {" "}
            or the GitHub repository
          </span>
        </div>
      </div>
    </footer>
  );
}
