import type { Metadata, Viewport } from "next";
import { Fraunces, Inter } from "next/font/google";
import Link from "next/link";
import type { ReactNode } from "react";

import { siteConfig } from "@/lib/site";

import "./globals.css";

const inter = Inter({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-inter",
});

const fraunces = Fraunces({
  subsets: ["latin"],
  display: "swap",
  variable: "--font-fraunces",
});

export const metadata: Metadata = {
  metadataBase: new URL(siteConfig.url),
  title: {
    default: "HantaAtlas | Hantavirus & Ebola Tracker App & Source-Backed Alerts",
    template: "%s | HantaAtlas",
  },
  description:
    "Track hantavirus and Ebola maps, saved country alerts, source-backed public-health signals, and confidence labels in the HantaAtlas iPhone app.",
  keywords: [
    "hantavirus tracker app",
    "ebola tracker app",
    "hantavirus map",
    "ebola outbreak map",
    "public health alert app",
    "disease surveillance app",
    "source-backed outbreak alerts",
    "hantavirus country alerts",
    "ebola country alerts",
  ],
  alternates: {
    canonical: "/",
  },
  openGraph: {
    type: "website",
    url: siteConfig.url,
    title: "HantaAtlas | Source-backed hantavirus & Ebola maps and alerts",
    description:
      "A calm iPhone atlas for hantavirus and Ebola public-health signals, country watchlists, map context, confidence labels, and source transparency.",
    siteName: "HantaAtlas",
    images: [
      {
        url: "/assets/generated/today-globe-hero.png",
        width: 1738,
        height: 905,
        alt: "HantaAtlas globe interface artwork in a warm editorial style.",
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: "HantaAtlas | Hantavirus & Ebola tracker app",
    description:
      "Source-backed hantavirus and Ebola map, country alerts, and public-health signal context for iPhone.",
    images: ["/assets/generated/today-globe-hero.png"],
  },
  appleWebApp: {
    capable: true,
    title: "HantaAtlas",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#FBF7F2",
  colorScheme: "light",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body className={`${inter.variable} ${fraunces.variable} antialiased`}>
        {children}
        <noscript>
          <div className="fixed inset-x-0 bottom-0 z-50 bg-graphite px-4 py-3 text-center text-sm text-paper">
            HantaAtlas works best with JavaScript enabled.
          </div>
        </noscript>
      </body>
    </html>
  );
}

export function FooterLegalLinks() {
  return (
    <div className="flex flex-wrap gap-4 text-sm text-muted-foreground">
      <Link className="hover:text-foreground" href="/privacy">
        Privacy
      </Link>
      <Link className="hover:text-foreground" href="/tos">
        Terms
      </Link>
      <Link className="hover:text-foreground" href="/support">
        Support
      </Link>
    </div>
  );
}
