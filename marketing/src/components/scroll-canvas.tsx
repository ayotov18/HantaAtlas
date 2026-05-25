"use client";

import { useEffect, useRef } from "react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";

gsap.registerPlugin(ScrollTrigger);

/**
 * Apple-style scroll-bound frame sequence. Preloads a numbered image sequence
 * and draws the frame matching scroll progress to a <canvas>. Place sequences
 * in narrative order down the page (each section's first frame == the previous
 * section's last frame) so the whole page reads as one continuous animation.
 *
 * Frames are served from R2: `${baseUrl}${0001..count}.${ext}`.
 * Reduced-motion users get a static first frame, no scrubbing.
 */
export function ScrollCanvas({
  baseUrl,
  count,
  pad = 4,
  ext = "webp",
  className,
  start = "top bottom",
  end = "bottom top",
}: {
  baseUrl: string;
  count: number;
  pad?: number;
  ext?: string;
  className?: string;
  start?: string;
  end?: string;
}) {
  const wrapRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const wrap = wrapRef.current;
    const canvas = canvasRef.current;
    if (!wrap || !canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const images: HTMLImageElement[] = [];
    let current = 0;
    const frameUrl = (i: number) =>
      `${baseUrl}${String(i + 1).padStart(pad, "0")}.${ext}`;

    const draw = (i: number) => {
      const idx = Math.max(0, Math.min(count - 1, Math.round(i)));
      const img = images[idx];
      if (!img || !img.complete || !img.naturalWidth) return;
      const cw = canvas.width;
      const ch = canvas.height;
      const scale = Math.max(cw / img.naturalWidth, ch / img.naturalHeight);
      const dw = img.naturalWidth * scale;
      const dh = img.naturalHeight * scale;
      ctx.clearRect(0, 0, cw, ch);
      ctx.drawImage(img, (cw - dw) / 2, (ch - dh) / 2, dw, dh);
    };

    const resize = () => {
      const rect = wrap.getBoundingClientRect();
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      canvas.width = Math.round(rect.width * dpr);
      canvas.height = Math.round(rect.height * dpr);
      draw(current);
    };

    // Preload the sequence. Redraw the active frame as each lands, and once
    // the sequence is in, recalc ScrollTrigger positions — without the refresh
    // the trigger is measured before the frames/layout settle, so progress
    // never advances and the canvas looks static.
    let loaded = 0;
    for (let i = 0; i < count; i++) {
      const img = new Image();
      img.decoding = "async";
      img.onload = () => {
        loaded += 1;
        if (i === 0) resize();
        if (Math.round(current) === i) draw(current);
        if (loaded === count) ScrollTrigger.refresh();
      };
      img.src = frameUrl(i);
      images[i] = img;
    }

    window.addEventListener("resize", resize);
    resize();

    let trigger: ScrollTrigger | undefined;
    if (!window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      trigger = ScrollTrigger.create({
        trigger: wrap,
        start,
        end,
        scrub: 0.5,
        invalidateOnRefresh: true,
        onUpdate: (self) => {
          current = self.progress * (count - 1);
          draw(current);
        },
      });
      ScrollTrigger.refresh();
    }

    return () => {
      trigger?.kill();
      window.removeEventListener("resize", resize);
    };
  }, [baseUrl, count, pad, ext, start, end]);

  return (
    <div ref={wrapRef} aria-hidden="true" className={className}>
      <canvas ref={canvasRef} className="block size-full" />
    </div>
  );
}
