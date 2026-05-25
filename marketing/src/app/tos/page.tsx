import type { Metadata } from "next";
import Link from "next/link";

import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { siteConfig } from "@/lib/site";

export const metadata: Metadata = {
  title: "Terms of Service",
  description:
    "Terms for using HantaAtlas, including acceptable use, medical disclaimer, source limitations, and support contact.",
  alternates: {
    canonical: "/tos",
  },
};

const terms = [
  {
    title: "Acceptable use",
    body: "Use HantaAtlas for personal informational awareness and responsible public-health context. Do not use the service to harass, mislead, scrape aggressively, reverse engineer protected systems, or present the app as an official emergency service.",
  },
  {
    title: "Medical disclaimer",
    body: "HantaAtlas is not medical advice and is not a medical device. It does not diagnose, treat, predict personal risk, measure exposure, or replace a doctor, local health authority, emergency service, or professional travel-health guidance.",
  },
  {
    title: "No emergency reliance",
    body: "Do not rely on HantaAtlas in an emergency. If you feel unwell, suspect exposure, or need urgent guidance, contact a clinician, local health authority, or emergency service.",
  },
  {
    title: "Source limitations",
    body: "Public-health reporting is uneven. Some sources publish structured data, some publish bulletins, some publish late, and some do not publish country-level detail. No recent public data is not the same as zero cases.",
  },
  {
    title: "Free access",
    body: "HantaAtlas is free to use. It shows no ads and does not sell access to outbreak, epidemic, or public-health event information.",
  },
  {
    title: "Privacy and permissions",
    body: "Your use of HantaAtlas is also governed by the Privacy Policy. Location and notifications are optional. Denying a permission may limit related convenience features, but it does not block the core informational app experience.",
  },
  {
    title: "Service changes",
    body: "Data sources, endpoints, screenshots, features, alert behavior, and availability may change as public sources and the product evolve. We aim to keep source methodology and privacy disclosures aligned with the shipped app.",
  },
  {
    title: "Limitation language",
    body: "To the extent allowed by applicable law, HantaAtlas is provided as-is for informational use. We are not responsible for decisions made solely from app content or for delays, omissions, or errors in public source material.",
  },
  {
    title: "Support",
    body: `Questions about these terms can be sent to ${siteConfig.supportEmail}.`,
  },
];

export default function TermsPage() {
  return (
    <>
      <SiteHeader />
      <main className="px-6 pb-20 pt-32">
        <article className="mx-auto max-w-4xl">
          <Badge variant="amber">Terms</Badge>
          <h1 className="mt-6 text-5xl font-semibold leading-[1.02] md:text-7xl">
            Terms for an informational surveillance app.
          </h1>
          <p className="mt-6 max-w-3xl text-lg leading-8 text-muted-foreground">
            These terms set expectations for responsible use, source limits,
            optional permissions, and the free no-account app experience.
          </p>
          <div className="mt-10 grid gap-5">
            {terms.map((term) => (
              <Card key={term.title}>
                <CardHeader>
                  <CardTitle>{term.title}</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-base leading-8 text-muted-foreground">{term.body}</p>
                </CardContent>
              </Card>
            ))}
          </div>
          <div className="mt-10">
            <Button asChild variant="outline">
              <Link href="/">Return home</Link>
            </Button>
          </div>
        </article>
      </main>
      <SiteFooter />
    </>
  );
}
