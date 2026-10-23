"use client";

import { Moon, Sun } from "lucide-react";
import { useTheme } from "next-themes";

export function ThemeToggle() {
  const { setTheme, resolvedTheme } = useTheme();

  const toggle = () => {
    const next = resolvedTheme === "dark" ? "light" : "dark";
    if (!document.startViewTransition)
      return setTheme(next);
    document.startViewTransition(() => setTheme(next));
  };

  return (
    <button
      type="button"
      onClick={toggle}
      aria-label="Toggle light and dark theme"
      title="Toggle theme"
      className="flex size-9 items-center justify-center text-muted-foreground transition-colors hover:text-foreground"
    >
      <Sun className="size-[18px] dark:hidden" />
      <Moon className="hidden size-[18px] dark:block" />
    </button>
  );
}
