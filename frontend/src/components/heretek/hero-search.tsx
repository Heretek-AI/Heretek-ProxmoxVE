"use client";

import { useRouter } from "next/navigation";
import { Search } from "lucide-react";
import { useState } from "react";

export function HeroSearch({ total }: { total: number }) {
  const router = useRouter();
  const [q, setQ] = useState("");
  return (
    <form
      role="search"
      onSubmit={(e) => {
        e.preventDefault();
        router.push(q.trim() ? `/scripts?search=${encodeURIComponent(q.trim())}` : "/scripts");
      }}
      className="flex h-12 w-full max-w-xl items-stretch border border-foreground/25 bg-card focus-within:border-blood"
    >
      <label htmlFor="hero-search" className="flex items-center pl-4 text-muted-foreground">
        <Search className="size-4" />
        <span className="sr-only">Search scripts</span>
      </label>
      <input
        id="hero-search"
        value={q}
        onChange={e => setQ(e.target.value)}
        placeholder={`Search ${total} scripts: llama, rag, agent…`}
        className="min-w-0 flex-1 bg-transparent px-3 text-[15px] outline-none placeholder:text-muted-foreground/80"
        autoComplete="off"
      />
      <button type="submit" className="bg-primary px-5 font-mono text-[11px] uppercase tracking-[0.16em] text-primary-foreground hover:bg-primary/90">
        Search
      </button>
    </form>
  );
}
