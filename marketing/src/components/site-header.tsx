"use client";

import Image from "next/image";
import Link from "next/link";
import { motion, useScroll, useSpring, useTransform } from "motion/react";

import { Button } from "@/components/ui/button";
import { siteConfig } from "@/lib/site";

const navItems = [
  { label: "Privacy", href: "/privacy" },
  { label: "Terms", href: "/tos" },
  { label: "Support", href: "/support" },
];

export function SiteHeader() {
  const { scrollY } = useScroll();
  // Compact when the user lands; grows wider/taller as they scroll.
  const spring = { stiffness: 200, damping: 30 };
  const height = useSpring(useTransform(scrollY, [0, 140], [56, 72]), spring);
  const maxWidth = useSpring(useTransform(scrollY, [0, 140], [640, 1152]), spring);
  const blur = useTransform(scrollY, [0, 140], [10, 22]);
  const backdropFilter = useTransform(blur, (b) => `blur(${b}px)`);

  return (
    <header className="fixed inset-x-0 top-0 z-50 px-4 pt-4">
      <motion.div
        style={{ height, maxWidth, backdropFilter, WebkitBackdropFilter: backdropFilter }}
        className="mx-auto flex items-center justify-between rounded-full border border-border/80 bg-background/82 px-3 shadow-[0_18px_60px_rgba(31,27,22,0.08)]"
      >
        <Link className="flex items-center gap-3" href="/" aria-label="HantaAtlas home">
          <span className="relative flex size-10 overflow-hidden rounded-2xl border border-border bg-paper">
            <Image
              src="/assets/generated/app-icon-concept.png"
              alt=""
              fill
              sizes="40px"
              className="object-cover"
              priority
            />
          </span>
          <span className="text-sm font-semibold text-foreground">HantaAtlas</span>
        </Link>
        <nav
          aria-label="Primary navigation"
          className="hidden items-center gap-6 text-sm font-medium text-muted-foreground md:flex"
        >
          {navItems.map((item) => (
            <Link className="transition-colors hover:text-foreground" href={item.href} key={item.href}>
              {item.label}
            </Link>
          ))}
        </nav>
        <Button asChild size="sm">
          <a href={siteConfig.appStoreUrl}>App Store</a>
        </Button>
      </motion.div>
    </header>
  );
}
