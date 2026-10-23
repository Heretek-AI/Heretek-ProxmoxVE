"use client";

import { FaDiscord, FaGithub } from "react-icons/fa";
import { Menu, Search, X } from "lucide-react";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import Image from "next/image";
import Link from "next/link";

import { basePath, externalLinks, navbarLinks } from "@/config/site-config";
import { ThemeToggle } from "@/components/ui/theme-toggle";
import { cn } from "@/lib/utils";

import type { PaletteScript } from "./command-palette";

import { CommandPalette, openPalette } from "./command-palette";

export function Wordmark({ className }: { className?: string }) {
  return (
    <Link href="/" className={cn("group flex items-center gap-2.5", className)} aria-label="Heretek-AI home">
      <Image src={`/${basePath}/logo.png`} alt="" width={22} height={30} unoptimized className="h-[30px] w-[22px] object-contain" />
      <span className="flex flex-col leading-none">
        <span className="font-display text-[17px] font-bold tracking-[0.06em]">HERETEK</span>
        <span className="mt-0.5 font-mono text-[9px] uppercase tracking-[0.32em] text-muted-foreground">Proxmox VE</span>
      </span>
    </Link>
  );
}

export function SiteHeader({ scripts, status }: { scripts: PaletteScript[]; status: string }) {
  const pathname = usePathname();
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => setMenuOpen(false), [pathname]);

  const isActive = (href: string) => pathname === href || pathname.startsWith(`${href}/`);

  return (
    <header className="sticky top-0 z-50 w-full border-b border-border bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/85">
      {/* Status strip: a one-line readout of what the catalogue holds. */}
      <div className="hidden border-b border-rule md:block">
        <div className="mx-auto flex h-7 max-w-[1440px] items-center justify-between px-6 font-mono text-[10.5px] uppercase tracking-[0.16em] text-muted-foreground">
          <span>
            <span className="text-blood">++</span>
            {" "}
            Scripts for the heretical homelab
            {" "}
            <span className="text-blood">++</span>
          </span>
          <span>{status}</span>
        </div>
      </div>

      <div className="mx-auto flex h-16 max-w-[1440px] items-center gap-6 px-4 md:px-6">
        <Wordmark />

        <nav className="hidden items-center gap-1 lg:flex" aria-label="Main">
          {navbarLinks.map(link => (
            <Link
              key={link.href}
              href={link.href}
              aria-current={isActive(link.href) ? "page" : undefined}
              className={cn(
                "relative px-3 py-2 text-[13.5px] text-muted-foreground transition-colors hover:text-foreground",
                isActive(link.href) && "text-foreground after:absolute after:inset-x-3 after:-bottom-[13px] after:h-[2px] after:bg-blood",
              )}
            >
              {link.text}
            </Link>
          ))}
        </nav>

        <div className="ml-auto flex items-center gap-1.5">
          <button
            type="button"
            onClick={openPalette}
            className="flex h-9 items-center gap-2 border border-border bg-card px-3 text-[13px] text-muted-foreground transition-colors hover:border-foreground/40 hover:text-foreground md:w-56 lg:w-64"
            aria-label="Search scripts"
          >
            <Search className="size-4" />
            <span className="hidden md:inline">Search scripts</span>
            <kbd className="ml-auto hidden border border-border px-1.5 font-mono text-[10px] md:inline">⌘K</kbd>
          </button>
          <a href={externalLinks.github} target="_blank" rel="noreferrer" aria-label="GitHub" className="hidden size-9 items-center justify-center text-muted-foreground hover:text-foreground sm:flex">
            <FaGithub className="size-[18px]" />
          </a>
          <a href={externalLinks.discord} target="_blank" rel="noreferrer" aria-label="Discord" className="hidden size-9 items-center justify-center text-muted-foreground hover:text-foreground sm:flex">
            <FaDiscord className="size-[18px]" />
          </a>
          <ThemeToggle />
          <button
            type="button"
            className="flex size-9 items-center justify-center border border-border lg:hidden"
            aria-label={menuOpen ? "Close menu" : "Open menu"}
            aria-expanded={menuOpen}
            onClick={() => setMenuOpen(o => !o)}
          >
            {menuOpen ? <X className="size-4" /> : <Menu className="size-4" />}
          </button>
        </div>
      </div>

      {menuOpen && (
        <nav className="border-t border-border bg-background lg:hidden" aria-label="Mobile">
          <ul className="mx-auto max-w-[1440px] divide-y divide-border px-4">
            {navbarLinks.map((link, i) => (
              <li key={link.href}>
                <Link href={link.href} className="flex items-center gap-4 py-3.5 text-[15px]">
                  <span className="font-mono text-[11px] text-blood">{String(i + 1).padStart(2, "0")}</span>
                  {link.text}
                </Link>
              </li>
            ))}
            <li className="flex gap-6 py-3.5 font-mono text-[12px] uppercase tracking-widest text-muted-foreground">
              <a href={externalLinks.github} target="_blank" rel="noreferrer">GitHub</a>
              <a href={externalLinks.discord} target="_blank" rel="noreferrer">Discord</a>
              <a href={externalLinks.changelog} target="_blank" rel="noreferrer">Changelog</a>
            </li>
          </ul>
        </nav>
      )}

      <CommandPalette scripts={scripts} />
    </header>
  );
}
