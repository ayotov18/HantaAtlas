"use client";

import * as React from "react";
import { motion } from "motion/react";

import { cn } from "@/lib/utils";

type LiquidButtonProps = Omit<React.ComponentProps<typeof motion.a>, "children"> & {
  href: string;
  variant?: "primary" | "outline";
  children?: React.ReactNode;
};

/**
 * App-store-style CTA with a "liquid" fill that rises from the bottom on hover,
 * plus spring scale on hover/tap. Modelled on animate-ui's LiquidButton (motion).
 */
export function LiquidButton({
  href,
  variant = "primary",
  className,
  children,
  ...props
}: LiquidButtonProps) {
  const isPrimary = variant === "primary";

  return (
    <motion.a
      href={href}
      initial="rest"
      animate="rest"
      whileHover="hover"
      whileTap={{ scale: 0.96 }}
      transition={{ type: "spring", stiffness: 320, damping: 22 }}
      className={cn(
        "group relative inline-flex h-12 items-center justify-center overflow-hidden rounded-full px-7 text-sm font-semibold transition-colors",
        isPrimary
          ? "bg-primary text-primary-foreground shadow-[0_18px_40px_rgba(193,95,60,0.24)]"
          : "border border-border bg-background/70 text-foreground",
        className,
      )}
      {...props}
    >
      <motion.span
        aria-hidden
        className={cn(
          "absolute inset-0 origin-bottom",
          isPrimary ? "bg-[#a84e2f]" : "bg-primary",
        )}
        variants={{ rest: { scaleY: 0 }, hover: { scaleY: 1 } }}
        transition={{ duration: 0.42, ease: [0.16, 1, 0.3, 1] }}
        style={{ borderRadius: "inherit" }}
      />
      <span
        className={cn(
          "relative z-10 transition-colors",
          !isPrimary && "group-hover:text-primary-foreground",
        )}
      >
        {children}
      </span>
    </motion.a>
  );
}
