import type { Metadata } from "next";
import Link from "next/link";

import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { siteConfig } from "@/lib/site";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "How HantaAtlas handles local preferences, optional location and notifications, advertising and App Tracking Transparency, the Remove Ads purchase, public data sources, and App Store privacy alignment.",
  alternates: {
    canonical: "/privacy",
  },
};

const privacySections = [
  {
    title: "What HantaAtlas is",
    body: "HantaAtlas is an informational public-health reference app for iPhone. It is not diagnosis, treatment, a personal risk predictor, emergency guidance, or a replacement for medical advice.",
  },
  {
    title: "No account required",
    body: "The current App Store build does not require account creation or sign-in. Saved countries, map preferences, alert settings, cached guide content, and the last selected map metric are stored locally on your device.",
  },
  {
    title: "Optional location",
    body: "Location access is optional and used only to center the map or provide nearby country context while you use the app. If you decline location, you can still search and select countries manually.",
  },
  {
    title: "Optional notifications",
    body: "If you enable notifications, HantaAtlas may use an anonymous installation identifier, push token, and watched country codes to route alert notifications. Notification permission is optional and the app remains usable if you decline.",
  },
  {
    title: "No advertising or tracking",
    body: "HantaAtlas shows no ads and contains no advertising or third-party tracking SDKs. There is no IDFA use, no App Tracking Transparency prompt, and no data shared with advertising partners. The app's only outbound connection for content is to the backend you configure it against.",
  },
  {
    title: "Public data sources",
    body: "The app summarizes public-health and source-backed signals. Source organizations, URLs, reported dates, published dates, confidence labels, and limitations remain attached to the data where available.",
  },
  {
    title: "Analytics",
    body: "HantaAtlas does not add a third-party analytics or advertising SDK to profile users. Any change to analytics behaviour will be reflected here and in the App Store privacy details before release.",
  },
  {
    title: "Deletion and export expectations",
    body: "Local preferences can be removed by changing settings in the app or deleting the app from the device. For optional server-side push registration data, contact support with the device/app context you can provide so we can help locate and remove the registration where technically possible.",
  },
  {
    title: "App Store privacy alignment",
    body: "App Store privacy answers should reflect the shipped version of the app. If optional alerts, anonymous install registration, analytics, or other data collection change, the App Store privacy details and this page should be updated together.",
  },
];

export default function PrivacyPage() {
  return (
    <>
      <SiteHeader />
      <main className="px-6 pb-20 pt-32">
        <article className="mx-auto max-w-4xl">
          <Badge variant="amber">Privacy</Badge>
          <h1 className="mt-6 text-5xl font-semibold leading-[1.02] md:text-7xl">
            Privacy for a no-account public-health atlas.
          </h1>
          <p className="mt-6 max-w-3xl text-lg leading-8 text-muted-foreground">
            HantaAtlas is designed as a free, no-account reference tool:
            local preferences on device by default, optional permissions only
            when a feature needs them, and source-backed public data kept
            separate from personal identity.
          </p>
          <div className="mt-10 grid gap-5">
            {privacySections.map((section) => (
              <Card key={section.title}>
                <CardHeader>
                  <CardTitle>{section.title}</CardTitle>
                </CardHeader>
                <CardContent>
                  <p className="text-base leading-8 text-muted-foreground">{section.body}</p>
                </CardContent>
              </Card>
            ))}
          </div>
          <div className="mt-10 rounded-[28px] border border-border bg-secondary/70 p-6">
            <p className="text-base leading-7 text-muted-foreground">
              Questions, deletion requests, or privacy corrections can be sent to{" "}
              <a className="font-semibold text-primary underline" href={`mailto:${siteConfig.supportEmail}`}>
                {siteConfig.supportEmail}
              </a>
              .
            </p>
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
