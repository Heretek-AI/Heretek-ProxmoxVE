import type { OperatingSystem } from "@/lib/types";

// eslint-disable-next-line node/no-process-env
export const basePath = process.env.BASE_PATH || "ProxmoxVE";

export type NavLink = { href: string; text: string; external?: boolean };

// Primary navigation. Order matters: it is also the order in the mobile menu and command palette.
export const navbarLinks: NavLink[] = [
  { href: "/scripts", text: "Scripts" },
  { href: "/categories", text: "Categories" },
  { href: "/versions", text: "Versions" },
  { href: "/generator", text: "Generator" },
  { href: "/community", text: "Community" },
];

export const externalLinks = {
  github: `https://github.com/Heretek-AI/${basePath}`,
  discord: "https://discord.gg/3AnUqsXnmK",
  changelog: `https://github.com/Heretek-AI/${basePath}/blob/main/CHANGELOG.md`,
  docs: `https://github.com/Heretek-AI/${basePath}/tree/main/docs`,
  contributing: `https://github.com/Heretek-AI/${basePath}/blob/main/CONTRIBUTING.md`,
  issues: `https://github.com/Heretek-AI/${basePath}/issues`,
  upstream: "https://community-scripts.org",
  tteck: "https://github.com/tteck",
};

export const mostPopularScripts = ["post-pve-install", "docker", "homeassistant"];

export const analytics = {
  url: "analytics.bramsuurd.nl",
  token: "f9eee289f931",
};

// Note styles, keyed by the "type" field of a script note.
export const AlertColors = {
  warning: "border-rust/40 bg-rust/[0.06]",
  info: "border-border bg-panel",
  success: "border-verdigris/40 bg-verdigris/[0.06]",
  danger: "border-blood/50 bg-blood/[0.07]",
};

export const OperatingSystems: OperatingSystem[] = [
  {
    name: "Debian",
    versions: [
      { name: "12", slug: "bookworm" },
      { name: "13", slug: "trixie" },
    ],
  },
  {
    name: "Ubuntu",
    versions: [
      { name: "22.04", slug: "jammy" },
      { name: "24.04", slug: "noble" },
    ],
  },
];
