import type { Metadata } from "next";

import { notFound } from "next/navigation";

import { getScript, loadCatalog, relatedScripts } from "@/lib/catalog";
import { ScriptView } from "@/components/heretek/script-view";

export const dynamicParams = false;

export function generateStaticParams() {
  return loadCatalog().scripts.map(s => ({ slug: s.slug }));
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const script = getScript((await params).slug);
  if (!script)
    return {};
  return {
    title: `${script.name} | Heretek-AI`,
    description: script.description.slice(0, 160),
    openGraph: { title: `${script.name} for Proxmox VE`, description: script.description.slice(0, 200) },
  };
}

export default async function ScriptPage({ params }: { params: Promise<{ slug: string }> }) {
  const script = getScript((await params).slug);
  if (!script)
    notFound();
  const categories = loadCatalog().categories.map(c => ({ id: c.id, name: c.name }));
  return <ScriptView script={script} categories={categories} related={relatedScripts(script)} />;
}
