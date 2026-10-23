import type { AppVersion, Script } from "./types";

// Helpers shared by server pages and client components. Keep this file free of
// Node APIs so it can ship to the browser.

export type CatalogScript = Script & {
  categoryNames: string[];
  version: AppVersion | null;
  available: boolean;
};

export const REPO = "Heretek-AI/ProxmoxVE";
export const REPO_URL = `https://github.com/${REPO}`;
export const RAW_BASE = `https://raw.githubusercontent.com/${REPO}/main`;

type TypeMeta = { label: string; long: string; className: string; runsIn: string };

// Each script type gets one colour from the sigil so a list can be scanned by colour alone.
const TYPE_META: Record<string, TypeMeta> = {
  ct: { label: "LXC", long: "Container", className: "text-rust border-rust/40", runsIn: "Proxmox VE shell" },
  vm: { label: "VM", long: "Virtual machine", className: "text-warp border-warp/40", runsIn: "Proxmox VE shell" },
  pve: { label: "PVE", long: "Host tool", className: "text-blood border-blood/40", runsIn: "Proxmox VE host" },
  tool: { label: "PVE", long: "Host tool", className: "text-blood border-blood/40", runsIn: "Proxmox VE host" },
  addon: { label: "Addon", long: "Add-on", className: "text-verdigris border-verdigris/40", runsIn: "Existing LXC or host" },
  turnkey: { label: "Turnkey", long: "TurnKey", className: "text-brass border-brass/40", runsIn: "Proxmox VE shell" },
};

export function typeMeta(type: string): TypeMeta {
  return TYPE_META[type] ?? { label: type.toUpperCase(), long: type, className: "text-muted-foreground border-border", runsIn: "Proxmox VE shell" };
}

export const TYPE_FILTERS = [
  { value: "ct", label: "LXC" },
  { value: "vm", label: "VM" },
  { value: "pve", label: "PVE / Tool" },
  { value: "addon", label: "Addon" },
] as const;

// "tool" is the older spelling of "pve" in some JSON files.
export function normalizedType(type: string) {
  return type === "tool" ? "pve" : type;
}

export function installCommand(scriptPath: string) {
  return `bash -c "$(curl -fsSL ${RAW_BASE}/${scriptPath})"`;
}

export function sourceLinks(script: Script) {
  const main = script.install_methods?.[0]?.script;
  const links: { label: string; href: string }[] = [];
  if (main)
    links.push({ label: script.type === "ct" ? "Container script" : "Script source", href: `${REPO_URL}/blob/main/${main}` });
  if (script.type === "ct")
    links.push({ label: "Install script", href: `${REPO_URL}/blob/main/install/${script.slug}-install.sh` });
  const meta = `frontend/public/json/${script.slug}.json`;
  links.push({ label: "Metadata JSON", href: `${REPO_URL}/blob/main/${meta}` });
  return links;
}

export function reportIssueUrl(script: Script) {
  const title = encodeURIComponent(`${script.name}: `);
  const body = encodeURIComponent(
    `**Script:** ${script.name} (\`${script.install_methods?.[0]?.script ?? script.slug}\`)\n\n**What happened?**\n\n\n**Proxmox VE version:**\n\n**Log output:**\n\`\`\`\n\n\`\`\``,
  );
  return `${REPO_URL}/issues/new?title=${title}&body=${body}&labels=bug`;
}

export function formatRam(mb: number | null | undefined) {
  if (mb == null)
    return null;
  return mb >= 1024 ? `${+(mb / 1024).toFixed(1)} GB` : `${mb} MB`;
}

export function formatDate(value: string | null | undefined, opts: Intl.DateTimeFormatOptions = { year: "numeric", month: "short", day: "numeric" }) {
  if (!value)
    return "";
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? value : d.toLocaleDateString("en-GB", { ...opts, timeZone: "UTC" });
}

export function primaryResources(script: Script) {
  return script.install_methods?.[0]?.resources ?? null;
}

export function osLabel(script: Script) {
  const r = primaryResources(script);
  if (r?.os)
    return `${r.os}${r.version ? ` ${r.version}` : ""}`;
  return null;
}

export function scriptHref(slug: string) {
  return `/scripts/${slug}`;
}
