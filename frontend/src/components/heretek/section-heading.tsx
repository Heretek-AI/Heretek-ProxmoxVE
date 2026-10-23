import { cn } from "@/lib/utils";

// Section header: a numbered mono marker over a Cinzel title, with an optional action on the right.
export function SectionHeading({
  index,
  kicker,
  title,
  action,
  className,
  id,
}: {
  index?: string;
  kicker: string;
  title: React.ReactNode;
  action?: React.ReactNode;
  className?: string;
  id?: string;
}) {
  return (
    <div id={id} className={cn("mb-6 flex items-end justify-between gap-4 border-b border-border pb-3", className)}>
      <div>
        <p className="label-mono mb-2">
          {Boolean(index) && <span className="mr-2 text-blood">{index}</span>}
          {kicker}
        </p>
        <h2 className="font-display text-2xl font-semibold tracking-tight md:text-[28px]">{title}</h2>
      </div>
      {action && <div className="shrink-0">{action}</div>}
    </div>
  );
}
