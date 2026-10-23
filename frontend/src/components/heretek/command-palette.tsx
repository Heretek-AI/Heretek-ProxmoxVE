"use client";

import { ArrowRight, Dices, Moon, Sun } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { useTheme } from "next-themes";

import {
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import { externalLinks, navbarLinks } from "@/config/site-config";
import { DialogTitle } from "@/components/ui/dialog";
import { scriptHref } from "@/lib/script-meta";

import { ScriptLogo } from "./script-logo";
import { TypeTag } from "./type-tag";

export type PaletteScript = {
  slug: string;
  name: string;
  type: string;
  logo: string | null;
  category: string;
  description: string;
};

const OPEN_EVENT = "heretek:open-palette";

export function openPalette() {
  window.dispatchEvent(new Event(OPEN_EVENT));
}

// Every word of the query has to appear somewhere in the item's value.
function wordFilter(value: string, search: string) {
  const words = search.toLowerCase().trim().split(/\s+/).filter(Boolean);
  if (!words.length)
    return 1;
  const v = value.toLowerCase();
  return words.every(w => v.includes(w)) ? (v.startsWith(words[0]) ? 1 : 0.5) : 0;
}

export function CommandPalette({ scripts }: { scripts: PaletteScript[] }) {
  const [open, setOpen] = useState(false);
  const router = useRouter();
  const { resolvedTheme, setTheme } = useTheme();

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key.toLowerCase() === "k" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        setOpen(o => !o);
      }
    };
    const onOpen = () => setOpen(true);
    document.addEventListener("keydown", onKey);
    window.addEventListener(OPEN_EVENT, onOpen);
    return () => {
      document.removeEventListener("keydown", onKey);
      window.removeEventListener(OPEN_EVENT, onOpen);
    };
  }, []);

  const go = (href: string) => {
    setOpen(false);
    if (href.startsWith("http"))
      window.open(href, "_blank", "noopener");
    else
      router.push(href);
  };

  return (
    <CommandDialog open={open} onOpenChange={setOpen} filter={wordFilter}>
      <DialogTitle className="sr-only">Search scripts</DialogTitle>
      <CommandInput placeholder="Search by name, category or what it does…" />
      <CommandList className="max-h-[60vh]">
        <CommandEmpty>
          <p className="text-sm">Nothing in the catalogue matches.</p>
          <a href={externalLinks.contributing} target="_blank" rel="noreferrer" className="mt-2 inline-block font-mono text-[11px] uppercase tracking-widest text-blood">
            Contribute a script
          </a>
        </CommandEmpty>
        <CommandGroup heading="Scripts">
          {scripts.map(s => (
            <CommandItem key={s.slug} value={`${s.name} ${s.slug} ${s.category} ${s.description}`} onSelect={() => go(scriptHref(s.slug))} className="gap-3">
              <ScriptLogo src={s.logo} alt="" size={20} />
              <span className="font-medium">{s.name}</span>
              <span className="hidden truncate text-xs text-muted-foreground sm:inline">{s.category}</span>
              <TypeTag type={s.type} className="ml-auto" />
            </CommandItem>
          ))}
        </CommandGroup>
        <CommandGroup heading="Pages">
          {navbarLinks.map(l => (
            <CommandItem key={l.href} value={`page ${l.text}`} onSelect={() => go(l.href)} className="gap-3">
              <ArrowRight className="text-muted-foreground" />
              {l.text}
            </CommandItem>
          ))}
        </CommandGroup>
        <CommandGroup heading="Actions">
          <CommandItem
            value="random script surprise"
            onSelect={() => scripts.length && go(scriptHref(scripts[Math.floor(Math.random() * scripts.length)].slug))}
            className="gap-3"
          >
            <Dices className="text-muted-foreground" />
            Open a random script
          </CommandItem>
          <CommandItem
            value="toggle theme dark light"
            onSelect={() => {
              setTheme(resolvedTheme === "dark" ? "light" : "dark");
              setOpen(false);
            }}
            className="gap-3"
          >
            {resolvedTheme === "dark" ? <Sun className="text-muted-foreground" /> : <Moon className="text-muted-foreground" />}
            Switch to
            {" "}
            {resolvedTheme === "dark" ? "vellum (light)" : "void (dark)"}
            {" "}
            theme
          </CommandItem>
        </CommandGroup>
      </CommandList>
      <div className="flex items-center gap-4 border-t border-border px-3 py-2 font-mono text-[10.5px] uppercase tracking-widest text-muted-foreground">
        <span>↑↓ move</span>
        <span>↵ open</span>
        <span>esc close</span>
      </div>
    </CommandDialog>
  );
}
