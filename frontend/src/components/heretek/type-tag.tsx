import { typeMeta } from "@/lib/script-meta";
import { cn } from "@/lib/utils";

export function TypeTag({ type, long = false, className }: { type: string; long?: boolean; className?: string }) {
  const meta = typeMeta(type);
  return (
    <span
      className={cn(
        "inline-flex h-5 items-center border px-1.5 font-mono text-[10.5px] font-medium uppercase leading-none tracking-[0.12em]",
        meta.className,
        className,
      )}
    >
      {long ? meta.long : meta.label}
    </span>
  );
}

export function Tag({ children, className }: { children: React.ReactNode; className?: string }) {
  return (
    <span
      className={cn(
        "inline-flex h-5 items-center border border-border px-1.5 font-mono text-[10.5px] font-medium uppercase leading-none tracking-[0.12em] text-muted-foreground",
        className,
      )}
    >
      {children}
    </span>
  );
}
