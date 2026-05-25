"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { Bell, Compass, Globe2, Layers3, ShieldCheck } from "lucide-react";

import { Badge } from "@/components/ui/badge";
import { IPhoneFrame } from "@/components/iphone-frame";
import { cn } from "@/lib/utils";

const chapters = [
  {
    eyebrow: "Know",
    title: "See global activity without opening a dozen tabs.",
    body: "The Today view compresses public-health signals into a readable daily brief, with counts, activity windows, and the latest official alert close at hand.",
    image: "/screenshots/app/story-know.webp",
    alt: "HantaAtlas Today screen in Hantavirus mode showing global activity, active countries, and official alerts.",
    icon: Globe2,
  },
  {
    eyebrow: "Track",
    title: "Save countries and keep the watchlist narrow.",
    body: "Follow only the countries you care about. HantaAtlas stores local preferences and keeps watchlist behavior explicit instead of turning the product into a noisy feed.",
    image: "/screenshots/app/story-track.webp",
    alt: "HantaAtlas Saved screen showing tracked countries and opt-in alert settings for official notices, case signals, and news bursts.",
    icon: Bell,
  },
  {
    eyebrow: "Map",
    title: "Read signals geographically, not as a panic feed.",
    body: "Map layers separate confidence, alerts, and signal location. Country fills and dot clusters make it easier to understand what is public, recent, and source-backed.",
    image: "/screenshots/app/story-map.webp",
    alt: "HantaAtlas map showing an Ebola signal callout over the Democratic Republic of the Congo with source and confidence.",
    icon: Compass,
  },
  {
    eyebrow: "Verify",
    title: "Every claim keeps its source and limitation visible.",
    body: "Source organization, publication dates, confidence labels, and known limitations are part of the product model, not hidden footnotes.",
    image: "/screenshots/app/story-verify.webp",
    alt: "HantaAtlas Today screen showing the latest official alert with source organization, dates, and confidence labels.",
    icon: ShieldCheck,
  },
  {
    eyebrow: "Context",
    title: "Open a signal when it matters, then return to the atlas.",
    body: "Map callouts expose the main source, severity, language, and headline, while keeping the underlying map readable and grounded.",
    image: "/screenshots/app/story-context.webp",
    alt: "HantaAtlas map signals hub listing source-backed public signals with time ranges and country tags.",
    icon: Layers3,
  },
];

export function ScrollStory() {
  const [activeIndex, setActiveIndex] = useState(0);
  const itemRefs = useRef<Array<HTMLDivElement | null>>([]);
  const reducedMotion = useMemo(
    () =>
      typeof window !== "undefined" &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches,
    [],
  );

  useEffect(() => {
    if (reducedMotion) {
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        const visible = entries
          .filter((entry) => entry.isIntersecting)
          .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];

        if (!visible) {
          return;
        }

        const index = itemRefs.current.findIndex((node) => node === visible.target);
        if (index >= 0) {
          setActiveIndex(index);
        }
      },
      { rootMargin: "-30% 0px -40% 0px", threshold: [0.2, 0.45, 0.7] },
    );

    itemRefs.current.forEach((node) => {
      if (node) {
        observer.observe(node);
      }
    });

    return () => observer.disconnect();
  }, [reducedMotion]);

  const active = chapters[activeIndex];

  return (
    <section id="story" className="relative px-6 py-24 md:py-32">
      <div className="mx-auto grid max-w-6xl gap-12 lg:grid-cols-[1fr_440px]">
        <div className="lg:order-2">
          <div className="sticky top-28">
            <div className="mb-5 flex items-center justify-center gap-2">
              {chapters.map((chapter, index) => (
                <button
                  aria-label={`Show ${chapter.eyebrow} screenshot`}
                  className={cn(
                    "h-1.5 cursor-pointer rounded-full transition-all",
                    index === activeIndex ? "w-10 bg-primary" : "w-4 bg-border hover:bg-primary/40",
                  )}
                  key={chapter.eyebrow}
                  onClick={() => setActiveIndex(index)}
                  type="button"
                />
              ))}
            </div>
            <IPhoneFrame src={active.image} alt={active.alt} priority={activeIndex === 0} />
          </div>
        </div>
        <div className="flex flex-col gap-8 lg:order-1">
          <div className="max-w-xl">
            <Badge variant="amber">The app story</Badge>
            <h2 className="mt-5 text-4xl font-semibold leading-[1.05] text-balance md:text-5xl">
              Built for calm awareness, not doom-scrolling.
            </h2>
            <p className="mt-5 text-lg leading-8 text-muted-foreground">
              The scroll below follows the real iPhone app screens. Each chapter
              keeps the job clear: know what happened, track what matters,
              verify the source, and act responsibly.
            </p>
          </div>
          {chapters.map((chapter, index) => {
            const Icon = chapter.icon;
            return (
              <div
                className={cn(
                  "rounded-[28px] border bg-card/74 p-7 transition-all duration-300 md:p-9",
                  index === activeIndex
                    ? "border-primary/35 shadow-[0_22px_70px_rgba(193,95,60,0.14)]"
                    : "border-border opacity-72",
                )}
                key={chapter.eyebrow}
                ref={(node) => {
                  itemRefs.current[index] = node;
                }}
              >
                <div className="mb-8 flex size-12 items-center justify-center rounded-2xl bg-primary/10 text-primary">
                  <Icon aria-hidden="true" className="size-5" />
                </div>
                <p className="text-xs font-semibold uppercase tracking-[0.18em] text-primary">
                  {chapter.eyebrow}
                </p>
                <h3 className="mt-3 text-2xl font-semibold leading-tight text-balance md:text-3xl">
                  {chapter.title}
                </h3>
                <p className="mt-4 text-base leading-7 text-muted-foreground">{chapter.body}</p>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
