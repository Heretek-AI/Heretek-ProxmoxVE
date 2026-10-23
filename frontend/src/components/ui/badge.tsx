import type { VariantProps } from "class-variance-authority";

import { cva } from "class-variance-authority";
import * as React from "react";

import { cn } from "@/lib/utils";

const badgeVariants = cva(
  "inline-flex items-center rounded-sm border px-1.5 py-px font-mono text-[11px] font-medium uppercase tracking-wider transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2",
  {
    variants: {
      variant: {
        default:
          "border-transparent  text-primary-foreground border-primary-foreground",
        secondary:
          "border-transparent  text-secondary-foreground border-secondary-foreground",
        destructive:
          "border-transparent  text-destructive-foreground border-destructive-foreground",
        outline: "text-foreground",
        success: "text-verdigris border-verdigris/50",
        warning: "text-brass border-brass/50",
        failure: "text-blood border-blood/50",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  },
);

export type BadgeProps = {} & React.HTMLAttributes<HTMLDivElement> & VariantProps<typeof badgeVariants>;

function Badge({ className, variant, ...props }: BadgeProps) {
  return (
    <div className={cn(badgeVariants({ variant }), className)} {...props} />
  );
}

export { Badge, badgeVariants };
