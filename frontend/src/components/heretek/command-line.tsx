"use client";

import { cn } from "@/lib/utils";

import { CopyButton } from "./copy-button";

// A shell line. The terminal surface stays dark in both themes.
export function CommandLine({ command, className, compact = false }: { command: string; className?: string; compact?: boolean }) {
  return (
    <div className={cn("terminal flex items-stretch", className)}>
      <div className={cn("flex min-w-0 flex-1 items-start gap-3 overflow-x-auto font-mono", compact ? "px-3 py-2.5 text-[12.5px]" : "px-4 py-3.5 text-[13px]")}>
        <span aria-hidden className="select-none text-[hsl(356_76%_58%)]">#</span>
        <code className="whitespace-pre-wrap break-all leading-relaxed">{command}</code>
      </div>
      <CopyButton
        value={command}
        label="Copy"
        className="border-l border-[hsl(18_10%_18%)] px-4 text-[hsl(36_24%_80%)] hover:bg-[hsl(356_76%_52%)] hover:text-white"
      />
    </div>
  );
}
