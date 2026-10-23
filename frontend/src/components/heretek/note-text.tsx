"use client";

import { CopyButton } from "./copy-button";

const URL_RE = /(https?:\/\/[^\s)]+)/g;

function linkify(text: string, keyPrefix: string) {
  return text.split(URL_RE).map((part, i) =>
    i % 2 === 1
      ? <a key={`${keyPrefix}-${i}`} href={part} target="_blank" rel="noreferrer" className="break-all underline decoration-border underline-offset-4 hover:text-blood">{part}</a>
      : part,
  );
}

// Note text from script JSON: `backticks` become copyable code, bare URLs become links.
export function NoteText({ text }: { text: string }) {
  return (
    <>
      {text.split(/`([^`]*)`/g).map((part, i) =>
        i % 2 === 1
          ? (
              <span key={i} className="mx-0.5 inline-flex items-center gap-1.5 border border-border bg-panel py-px pl-1.5 pr-1 align-middle font-mono text-[12.5px]">
                {part}
                <CopyButton value={part} what="Snippet" className="text-muted-foreground hover:text-foreground" />
              </span>
            )
          : <span key={i}>{linkify(part, String(i))}</span>,
      )}
    </>
  );
}
