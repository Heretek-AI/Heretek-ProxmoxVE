"use client";

import { useState } from "react";
import Image from "next/image";

import { basePath } from "@/config/site-config";
import { cn } from "@/lib/utils";

// Third-party logos are hotlinked and sometimes vanish, so fall back to the sigil.
export function ScriptLogo({ src, alt, size = 40, className }: { src: string | null; alt: string; size?: number; className?: string }) {
  const fallback = `/${basePath}/logo.png`;
  const [current, setCurrent] = useState(src || fallback);
  return (
    <Image
      src={current}
      alt={alt}
      width={size}
      height={size}
      unoptimized
      onError={() => setCurrent(fallback)}
      className={cn("object-contain", className)}
      style={{ width: size, height: size }}
    />
  );
}
