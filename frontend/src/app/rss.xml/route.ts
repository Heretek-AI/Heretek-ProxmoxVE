import { basePath } from "@/config/site-config";
import { loadCatalog } from "@/lib/catalog";

export const dynamic = "force-static";

const SITE = `https://heretek-ai.github.io/${basePath}`;

function esc(s: string) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

// RSS feed of scripts, newest first, generated at build time.
export function GET() {
  const items = loadCatalog().scripts.filter(s => s.available).sort((a, b) => b.date_created.localeCompare(a.date_created)).slice(0, 50).map(s => `    <item>
      <title>${esc(s.name)}</title>
      <link>${SITE}/scripts/${s.slug}</link>
      <guid isPermaLink="true">${SITE}/scripts/${s.slug}</guid>
      <pubDate>${new Date(`${s.date_created}T00:00:00Z`).toUTCString()}</pubDate>
      <description>${esc(s.description)}</description>
    </item>`).join("\n");

  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Heretek-AI: new Proxmox VE scripts</title>
    <link>${SITE}</link>
    <description>New scripts added to the Heretek-AI Proxmox VE catalogue.</description>
    <language>en</language>
${items}
  </channel>
</rss>
`;
  return new Response(xml, { headers: { "Content-Type": "application/rss+xml; charset=utf-8" } });
}
