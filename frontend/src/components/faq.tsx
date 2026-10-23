import * as AccordionPrimitive from "@radix-ui/react-accordion";
import { Plus } from "lucide-react";

import { Accordion, AccordionContent, AccordionItem } from "./ui/accordion";
import { FAQ_Items } from "../config/faq-config";

export default function FAQ() {
  return (
    <Accordion type="single" collapsible className="w-full border-t border-border">
      {FAQ_Items.map((item, index) => (
        <AccordionItem value={index.toString()} key={item.title} className="border-border">
          <AccordionPrimitive.Header className="flex">
            <AccordionPrimitive.Trigger className="group flex flex-1 items-baseline gap-4 py-4 text-left text-[15px] font-medium leading-6 transition-colors hover:text-blood">
              <span className="w-6 shrink-0 font-mono text-[11px] text-muted-foreground">{String(index + 1).padStart(2, "0")}</span>
              <span className="flex-1">{item.title}</span>
              <Plus size={16} className="shrink-0 self-center text-muted-foreground transition-transform duration-200 group-data-[state=open]:rotate-45" aria-hidden="true" />
            </AccordionPrimitive.Trigger>
          </AccordionPrimitive.Header>
          <AccordionContent className="pb-5 pl-10 pr-8 text-[14px] leading-relaxed text-muted-foreground">{item.content}</AccordionContent>
        </AccordionItem>
      ))}
    </Accordion>
  );
}
