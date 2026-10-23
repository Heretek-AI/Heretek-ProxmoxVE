import type { Metadata, Viewport } from "next";

import { Cinzel, IBM_Plex_Sans, JetBrains_Mono } from "next/font/google";
import { NuqsAdapter } from "nuqs/adapters/next/app";
import Script from "next/script";
import React from "react";

import { SiteFooter } from "@/components/heretek/site-footer";
import { SiteHeader } from "@/components/heretek/site-header";
import { ThemeProvider } from "@/components/theme-provider";
import { analytics, basePath } from "@/config/site-config";
import QueryProvider from "@/components/query-provider";
import { Toaster } from "@/components/ui/sonner";
import { formatDate } from "@/lib/script-meta";
import { loadCatalog } from "@/lib/catalog";
import "@/styles/globals.css";

// Cinzel carries the Heretek display voice, Plex Sans keeps long text readable,
// and JetBrains Mono is used for anything a machine would print.
const cinzel = Cinzel({
  subsets: ["latin"],
  weight: ["500", "600", "700", "800"],
  variable: "--font-cinzel",
  display: "swap",
});

const plex = IBM_Plex_Sans({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-plex",
  display: "swap",
});

const jetbrainsMono = JetBrains_Mono({
  subsets: ["latin"],
  variable: "--font-jetbrains",
  display: "swap",
});

export const metadata: Metadata = {
  title: "Heretek AI - Proxmox VE Scripts",
  description:
    "The Heretek AI repository for Proxmox VE Helper-Scripts. Embrace the machine spirit with a growing catalogue of scripts to manage your Proxmox Virtual Environment. Tech-heresy made manifest.",
  applicationName: "Heretek AI",
  generator: "Next.js",
  referrer: "origin-when-cross-origin",
  keywords: [
    "Proxmox VE",
    "Helper-Scripts",
    "Heretek",
    "Heretek AI",
    "helper",
    "scripts",
    "proxmox",
    "VE",
    "virtualization",
    "containers",
    "LXC",
    "VM",
    "machine spirit",
    "tech-heresy",
    "Warhammer 40K",
  ],
  authors: [
    { name: "Bram Suurd", url: "https://github.com/BramSuurdje" },
    { name: "Heretek AI", url: "https://github.com/Heretek-AI" },
  ],
  creator: "Bram Suurd",
  publisher: "Heretek AI",
  metadataBase: new URL(`https://Heretek-AI.github.io/${basePath}/`),
  alternates: {
    canonical: `https://Heretek-AI.github.io/${basePath}/`,
  },
  formatDetection: {
    email: false,
    address: false,
    telephone: false,
  },
  openGraph: {
    title: "Heretek AI - Proxmox VE Scripts",
    description:
      "The Heretek AI repository for Proxmox VE Helper-Scripts. Embrace the machine spirit with a growing catalogue of scripts to manage your Proxmox Virtual Environment.",
    url: `https://Heretek-AI.github.io/${basePath}/`,
    siteName: "Heretek AI",
    images: [
      {
        url: `https://Heretek-AI.github.io/${basePath}/defaultimg.png`,
        width: 1200,
        height: 630,
        alt: "Heretek AI - Proxmox VE Scripts",
      },
    ],
    locale: "en_US",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "Heretek AI - Proxmox VE Scripts",
    creator: "@BramSuurdje",
    description:
      "The Heretek AI repository for Proxmox VE Helper-Scripts. Embrace the machine spirit with a growing catalogue of scripts to manage your Proxmox Virtual Environment.",
    images: [`https://Heretek-AI.github.io/${basePath}/defaultimg.png`],
  },
  manifest: "/manifest.webmanifest",
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "Heretek AI",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
  themeColor: [
    { media: "(prefers-color-scheme: dark)", color: "#0b0a09" },
    { media: "(prefers-color-scheme: light)", color: "#f1ece2" },
  ],
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const { scripts, categories, versionsGenerated } = loadCatalog();
  const live = scripts.filter(s => s.available);
  const usedCategories = categories.filter(c => c.scripts.some(s => s.available)).length;
  const status = [
    `${live.length} scripts`,
    `${usedCategories} categories`,
    versionsGenerated ? `versions checked ${formatDate(versionsGenerated)}` : null,
  ].filter(Boolean).join(" · ");
  const paletteScripts = live.map(s => ({
    slug: s.slug,
    name: s.name,
    type: s.type,
    logo: s.logo,
    category: s.categoryNames[0] ?? "",
    description: s.description,
  }));

  return (
    <html lang="en" suppressHydrationWarning className={`${cinzel.variable} ${plex.variable} ${jetbrainsMono.variable}`}>
      <head>
        <link rel="canonical" href={metadata.metadataBase?.href} />
        <link rel="manifest" href="manifest.webmanifest" />
        <link rel="preconnect" href="https://api.github.com" />
        <link rel="alternate" type="application/rss+xml" title="Heretek-AI: new scripts" href={`/${basePath}/rss.xml`} />
      </head>
      <body className="antialiased">
        <Script
          src={`https://${analytics.url}/api/script.js`}
          data-site-id={analytics.token}
          strategy="afterInteractive"
        />
        <ThemeProvider attribute="class" defaultTheme="dark" enableSystem disableTransitionOnChange>
          <NuqsAdapter>
            <QueryProvider>
              <a href="#main" className="sr-only focus:not-sr-only focus:fixed focus:left-4 focus:top-4 focus:z-[60] focus:bg-primary focus:px-3 focus:py-2 focus:text-primary-foreground">
                Skip to content
              </a>
              <div className="flex min-h-screen flex-col">
                <SiteHeader scripts={paletteScripts} status={status} />
                <main id="main" className="flex-1">
                  {children}
                </main>
                <SiteFooter />
              </div>
              <Toaster />
            </QueryProvider>
          </NuqsAdapter>
        </ThemeProvider>
      </body>
    </html>
  );
}
