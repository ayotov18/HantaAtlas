import Image from "next/image";
import Link from "next/link";
import {
  BellRing,
  BookOpenCheck,
  CheckCircle2,
  FileSearch,
  Map,
  ShieldAlert,
  ShieldCheck,
} from "lucide-react";

import { JsonLd } from "@/components/json-ld";
import { BorderBeam } from "@/components/animate-ui/border-beam";
import { LiquidButton } from "@/components/animate-ui/liquid-button";
import { Reveal } from "@/components/animate-ui/reveal";
import { ScrollCanvas } from "@/components/scroll-canvas";
import { ScrollStory } from "@/components/scroll-story";

const R2_FRAMES = "https://pub-b0557359c03245819f4dee117959288b.r2.dev/frames";
import { SectionHeading } from "@/components/section-heading";
import { SiteFooter } from "@/components/site-footer";
import { SiteHeader } from "@/components/site-header";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import {
  faqJsonLd,
  softwareApplicationJsonLd,
  websiteJsonLd,
} from "@/lib/structured-data";
import { siteConfig } from "@/lib/site";

const featureCards = [
  {
    title: "Source-backed feed",
    body: "Signals retain organization, URL, dates, confidence level, and known limitations.",
    icon: FileSearch,
  },
  {
    title: "Country watchlist",
    body: "Save countries locally and enable opt-in alerts only when you want them.",
    icon: BellRing,
  },
  {
    title: "Offline guidance",
    body: "Read prevention, symptom, and urgent-care guidance without turning the app into medical advice.",
    icon: BookOpenCheck,
  },
];

const sourceRows = [
  ["Confidence", "Structured data, official alerts, media signals, or no recent public data."],
  ["Dates", "Reported, published, and last checked timestamps stay visible."],
  ["Limitations", "Each metric explains what the source can and cannot support."],
  ["Traceability", "Source organization and public URL remain attached to the signal."],
];

const faqItems = [
  {
    question: "Is HantaAtlas medical advice?",
    answer:
      "No. HantaAtlas is informational public-health surveillance. It is not diagnosis, treatment, a personal risk predictor, or a replacement for medical advice.",
  },
  {
    question: "Which diseases does HantaAtlas track?",
    answer:
      "Hantavirus and Ebola. You can view both together or focus on either one. Each disease keeps its own source-backed signals, confidence labels, country context, and official-source links.",
  },
  {
    question: "How fresh is the data?",
    answer:
      "The app shows checked, reported, and published dates where available. Freshness depends on the public sources being monitored and on what those sources publish.",
  },
  {
    question: "Which countries are covered?",
    answer:
      "The app supports a country catalogue and highlights countries with recent public signals. No recent public data does not mean zero cases; it means no recent country-level public source was found in monitored channels.",
  },
  {
    question: "Can I get country alerts?",
    answer:
      "Yes. Alerts are opt-in. If enabled, the app may register an anonymous installation and the country codes you choose to watch so push alerts can be routed.",
  },
  {
    question: "What does HantaAtlas store?",
    answer:
      "Version one is no-account by default. Saved countries, preferences, cached content, and the last selected map metric live locally unless push alert registration is enabled.",
  },
  {
    question: "Does HantaAtlas show ads?",
    answer:
      "No. HantaAtlas shows no ads and contains no advertising or third-party tracking SDKs. There is no IDFA use and no App Tracking Transparency prompt.",
  },
  {
    question: "Does the guide work offline?",
    answer:
      "Yes. Core guide content is designed to remain available offline, with the same reminder that it is informational and not a substitute for medical care.",
  },
];

export default function Home() {
  return (
    <>
      <JsonLd data={websiteJsonLd} />
      <JsonLd data={softwareApplicationJsonLd} />
      <JsonLd data={faqJsonLd} />
      <SiteHeader />
      <main>
        <HeroSection />
        <ScrollStory />
        <SourceTransparencySection />
        <WatchlistSection />
        <CoverageSection />
        <PrivacyDisclaimerSection />
        <FaqSection />
        <FinalCta />
      </main>
      <SiteFooter />
    </>
  );
}

function HeroSection() {
  return (
    <section className="paper-grain relative flex min-h-screen items-center overflow-hidden px-6 pb-16 pt-32">
      <ScrollCanvas
        baseUrl={`${R2_FRAMES}/s1/`}
        count={60}
        ext="jpg"
        start="top top"
        end="bottom top"
        className="absolute inset-0 size-full opacity-75"
      />
      <div className="absolute inset-0 bg-[linear-gradient(90deg,rgba(251,247,242,0.92),rgba(251,247,242,0.55)_48%,rgba(251,247,242,0.42))]" />
      <div className="relative mx-auto grid w-full max-w-6xl items-end gap-12 lg:grid-cols-[1.05fr_0.95fr]">
        <div className="max-w-3xl">
          <h1 className="max-w-4xl text-6xl font-semibold leading-[0.95] text-balance md:text-7xl lg:text-8xl">
            Know what is happening globally.
          </h1>
          <p className="mt-7 max-w-2xl text-xl leading-8 text-muted-foreground md:text-2xl md:leading-9">
            HantaAtlas turns source-backed hantavirus and Ebola signals into a
            calm map, country watchlist, alert feed, and offline guide.
          </p>
          <div className="mt-9 flex flex-col gap-3 sm:flex-row">
            <LiquidButton href={siteConfig.appStoreUrl} className="h-14 px-8 text-base">
              Get on the App Store
            </LiquidButton>
            <LiquidButton href="#sources" variant="outline" className="h-14 px-8 text-base">
              View sources
            </LiquidButton>
          </div>
          <p className="mt-6 max-w-xl text-sm leading-6 text-muted-foreground">
            Informational only. Not diagnosis, treatment, personal risk prediction,
            or emergency advice.
          </p>
        </div>
        <div className="relative hidden lg:block">
          <div className="absolute -inset-6 rounded-[46px] bg-primary/10 blur-3xl" />
          <div className="relative overflow-hidden rounded-[42px] bg-paper p-4 shadow-[0_30px_90px_rgba(31,27,22,0.18)]">
            <BorderBeam />
            <Image
              src="/screenshots/app/today-global.webp"
              alt="HantaAtlas Today dashboard showing global activity across hantavirus and Ebola with official alert metrics."
              width={1000}
              height={2036}
              priority
              className="h-[620px] w-full rounded-[32px] object-cover object-top"
            />
          </div>
        </div>
      </div>
    </section>
  );
}

function SourceTransparencySection() {
  return (
    <section id="sources" className="relative overflow-hidden px-6 py-24 md:py-32">
      <ScrollCanvas
        baseUrl={`${R2_FRAMES}/s2/`}
        count={60}
        ext="jpg"
        className="absolute inset-0 size-full opacity-40"
      />
      <div className="absolute inset-0 bg-background/82" />
      <div className="relative mx-auto grid max-w-6xl gap-12 lg:grid-cols-[0.9fr_1.1fr]">
        <SectionHeading
          kicker="Source transparency"
          title="The source is part of the interface."
        >
          HantaAtlas is built around the constraint that public-health data is
          uneven. The app says what was found, who published it, when it was
          checked, and where confidence is limited.
        </SectionHeading>
        <Card className="overflow-hidden">
          <CardHeader className="pb-2">
            <CardTitle className="flex items-center gap-3 text-2xl">
              <ShieldCheck className="size-6 text-primary" aria-hidden="true" />
              Signal record
            </CardTitle>
            <CardDescription>
              The same fields that power the iPhone app become the page promise.
            </CardDescription>
          </CardHeader>
          <CardContent className="pt-3">
            <div className="flex flex-col">
              {sourceRows.map(([label, value], index) => (
                <div key={label}>
                  {index > 0 ? <Separator /> : null}
                  <div className="grid gap-3 py-5 md:grid-cols-[160px_1fr]">
                    <p className="text-sm font-semibold text-foreground">{label}</p>
                    <p className="text-sm leading-6 text-muted-foreground">{value}</p>
                  </div>
                </div>
              ))}
            </div>
          </CardContent>
        </Card>
      </div>
    </section>
  );
}

function WatchlistSection() {
  return (
    <section className="bg-graphite px-6 py-24 text-paper md:py-32">
      <div className="mx-auto grid max-w-6xl items-center gap-12 lg:grid-cols-[1fr_0.9fr]">
        <Reveal>
          <p className="mb-4 text-xs font-semibold uppercase tracking-[0.18em] text-primary">
            Save &amp; track
          </p>
          <h2 className="max-w-3xl text-4xl font-semibold leading-[1.05] text-balance md:text-5xl">
            Track the countries that matter without accepting a noisy feed.
          </h2>
          <p className="mt-5 max-w-2xl text-lg leading-8 text-paper/72">
            The watchlist is explicit. Countries can be saved locally, alert
            settings are opt-in, and push delivery only needs an anonymous
            installation plus selected country codes when enabled.
          </p>
          <div className="mt-10 grid gap-4 sm:grid-cols-3">
            {featureCards.map((feature) => {
              const Icon = feature.icon;
              return (
                <div
                  className="rounded-[26px] border border-paper/10 bg-paper/[0.06] p-5 transition-all duration-300 hover:-translate-y-1 hover:border-primary/35 hover:bg-paper/[0.09]"
                  key={feature.title}
                >
                  <Icon className="size-6 text-primary" aria-hidden="true" />
                  <p className="mt-5 text-base font-semibold">{feature.title}</p>
                  <p className="mt-2 text-sm leading-6 text-paper/66">{feature.body}</p>
                </div>
              );
            })}
          </div>
        </Reveal>
        <Reveal delay={0.1} className="relative overflow-hidden rounded-[38px] bg-paper/[0.06] p-4">
          <BorderBeam />
          <Image
            src="/screenshots/app/saved-track.webp"
            alt="HantaAtlas Saved screen for following the countries that matter and keeping the watchlist focused."
            width={1000}
            height={2036}
            className="h-[560px] w-full rounded-[28px] object-cover object-top"
          />
        </Reveal>
      </div>
    </section>
  );
}

function CoverageSection() {
  return (
    <section className="relative overflow-hidden px-6 py-24 md:py-32">
      <ScrollCanvas
        baseUrl={`${R2_FRAMES}/s3/`}
        count={60}
        ext="jpg"
        className="absolute inset-0 size-full opacity-40"
      />
      <div className="absolute inset-0 bg-background/82" />
      <div className="relative mx-auto max-w-6xl">
        <SectionHeading
          kicker="Map and country coverage"
          title="An atlas for public signals, not a personal risk score."
        >
          The map helps users understand what has been publicly reported for
          hantavirus and Ebola and where signals cluster. It does not infer
          individual exposure or tell users whether travel is safe.
        </SectionHeading>
        <div className="mt-12 grid gap-5 md:grid-cols-3">
          {[
            ["45", "public signals visible in the current map story"],
            ["30d", "activity windows for recent changes"],
            ["4", "confidence states carried through the product"],
          ].map(([stat, label]) => (
            <Card key={stat}>
              <CardHeader>
                <CardTitle className="text-5xl font-semibold">{stat}</CardTitle>
                <CardDescription className="text-base">{label}</CardDescription>
              </CardHeader>
            </Card>
          ))}
        </div>
        <div className="mt-8 overflow-hidden rounded-[36px] border border-border bg-card p-4 shadow-[0_24px_80px_rgba(31,27,22,0.08)]">
          <Image
            src="/screenshots/app/map-globe.webp"
            alt="HantaAtlas world map showing source-backed hantavirus and Ebola signal clusters across regions."
            width={1000}
            height={2036}
            className="max-h-[760px] w-full rounded-[26px] object-cover object-center"
          />
        </div>
      </div>
    </section>
  );
}

function PrivacyDisclaimerSection() {
  return (
    <section className="bg-secondary/55 px-6 py-24 md:py-32">
      <div className="mx-auto grid max-w-6xl gap-6 md:grid-cols-2">
        <Card className="bg-paper">
          <CardHeader>
            <ShieldAlert className="size-8 text-primary" aria-hidden="true" />
            <CardTitle className="text-3xl">Informational by design.</CardTitle>
            <CardDescription className="text-base">
              HantaAtlas is public-health surveillance context. It does not
              diagnose, treat, predict personal risk, or replace emergency care.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button asChild variant="outline">
              <Link href="/tos">Read terms</Link>
            </Button>
          </CardContent>
        </Card>
        <Card className="bg-paper">
          <CardHeader>
            <CheckCircle2 className="size-8 text-primary" aria-hidden="true" />
            <CardTitle className="text-3xl">Privacy stays plain.</CardTitle>
            <CardDescription className="text-base">
              No-account by default. Local preferences stay on device. Optional
              push registration only uses the anonymous install and watchlist
              country codes needed for alerts.
            </CardDescription>
          </CardHeader>
          <CardContent>
            <Button asChild variant="outline">
              <Link href="/privacy">Read privacy</Link>
            </Button>
          </CardContent>
        </Card>
      </div>
    </section>
  );
}

function FaqSection() {
  return (
    <section className="px-6 py-24 md:py-32">
      <div className="mx-auto grid max-w-6xl gap-10 lg:grid-cols-[0.75fr_1fr]">
        <SectionHeading kicker="FAQ" title="Questions before you install." />
        <Accordion type="single" collapsible className="rounded-[28px] border border-border bg-card px-6">
          {faqItems.map((item, index) => (
            <AccordionItem value={`item-${index}`} key={item.question}>
              <AccordionTrigger>{item.question}</AccordionTrigger>
              <AccordionContent>{item.answer}</AccordionContent>
            </AccordionItem>
          ))}
        </Accordion>
      </div>
    </section>
  );
}

function FinalCta() {
  return (
    <section className="px-6 pb-24">
      <div className="mx-auto overflow-hidden rounded-[42px] bg-graphite px-6 py-16 text-center text-paper md:px-12 md:py-20">
        <div className="mx-auto max-w-3xl">
          <Map className="mx-auto size-10 text-primary" aria-hidden="true" />
          <h2 className="mt-6 text-4xl font-semibold leading-[1.05] text-balance md:text-6xl">
            Stay informed without turning outbreak news into noise.
          </h2>
          <p className="mx-auto mt-6 max-w-2xl text-lg leading-8 text-paper/72">
            HantaAtlas gives you the map, the source, the country context, and
            the limitation. The rest is deliberately quiet.
          </p>
          <div className="mt-9 flex flex-col items-center justify-center gap-3 sm:flex-row">
            <LiquidButton href={siteConfig.appStoreUrl} className="h-14 px-8 text-base">
              Get on the App Store
            </LiquidButton>
            <LiquidButton href="/support" variant="outline" className="h-14 px-8 text-base">
              Contact support
            </LiquidButton>
          </div>
        </div>
      </div>
    </section>
  );
}
