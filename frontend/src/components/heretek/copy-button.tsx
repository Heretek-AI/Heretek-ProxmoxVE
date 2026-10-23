"use client";

import { useEffect, useState } from "react";
import { Check, Copy } from "lucide-react";
import { toast } from "sonner";

import { cn } from "@/lib/utils";

const WARNED_KEY = "heretek-copy-warned";

export function copyText(value: string, what = "Command") {
  navigator.clipboard.writeText(value).then(
    () => {
      toast.success(`${what} copied`);
      try {
        if (!localStorage.getItem(WARNED_KEY)) {
          localStorage.setItem(WARNED_KEY, "1");
          setTimeout(() => toast.warning("Read a script before you run it as root. Every source link is on the script page."), 600);
        }
      }
      catch {}
    },
    () => toast.error("Clipboard is blocked in this browser"),
  );
}

export function CopyButton({
  value,
  what,
  label,
  className,
}: {
  value: string;
  what?: string;
  label?: string;
  className?: string;
}) {
  const [copied, setCopied] = useState(false);
  useEffect(() => {
    if (!copied)
      return;
    const t = setTimeout(() => setCopied(false), 1600);
    return () => clearTimeout(t);
  }, [copied]);

  return (
    <button
      type="button"
      onClick={(e) => {
        e.preventDefault();
        e.stopPropagation();
        copyText(value, what);
        setCopied(true);
      }}
      aria-label={label ?? `Copy ${what?.toLowerCase() ?? "command"}`}
      className={cn(
        "inline-flex shrink-0 items-center justify-center gap-1.5 font-mono text-[11px] uppercase tracking-[0.12em] transition-colors",
        className,
      )}
    >
      {copied ? <Check className="size-3.5" /> : <Copy className="size-3.5" />}
      {label !== undefined && <span>{copied ? "Copied" : label}</span>}
    </button>
  );
}
