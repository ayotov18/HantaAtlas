import type { Metadata } from "next";
import Link from "next/link";

import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { siteConfig } from "@/lib/site";

export const metadata: Metadata = {
  title: "Support",
  description:
    "Contact HantaAtlas support, review source methodology, and find the privacy and informational-use links for the iPhone app.",
  alternates: {
    canonical: "/support",
  },
};

export default function SupportPage() {
  return (
    <>
      <SiteHeader />
      <main className="px-6 pb-20 pt-32">
        <section className="mx-auto max-w-4xl">
          <Badge variant="amber">Support</Badge>
          <h1 className="mt-6 text-5xl font-semibold leading-[1.02] md:text-7xl">
            Help, corrections, and source questions.
          </h1>
          <p className="mt-6 max-w-3xl text-lg leading-8 text-muted-foreground">
            HantaAtlas depends on public sources. If something looks stale,
            unclear, or incorrectly attributed, send the source and country
            context so it can be reviewed.
          </p>
          <div className="mt-10 grid gap-5 md:grid-cols-2">
            <Card>
              <CardHeader>
                <CardTitle>Email support</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-base leading-8 text-muted-foreground">
                  Use email for privacy requests, source corrections, App Store
                  support, and informational-use questions.
                </p>
                <Button asChild className="mt-6">
                  <a href={`mailto:${siteConfig.supportEmail}`}>{siteConfig.supportEmail}</a>
                </Button>
              </CardContent>
            </Card>
            <Card>
              <CardHeader>
                <CardTitle>Source methodology</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-base leading-8 text-muted-foreground">
                  The public API exposes the current endpoint contract. The app
                  still shows source organizations, URLs, confidence, and dates
                  where available.
                </p>
                <Button asChild className="mt-6" variant="outline">
                  <a href={`${siteConfig.apiUrl}/openapi.json`}>Open API contract</a>
                </Button>
              </CardContent>
            </Card>
          </div>
          <div className="mt-10 flex flex-wrap gap-3">
            <Button asChild variant="outline">
              <Link href="/privacy">Privacy</Link>
            </Button>
            <Button asChild variant="outline">
              <Link href="/tos">Terms</Link>
            </Button>
          </div>
        </section>
      </main>
      <SiteFooter />
    </>
  );
}
