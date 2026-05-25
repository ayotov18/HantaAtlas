"use client";

/* eslint-disable @next/next/no-img-element */

import type { CSSProperties, ReactNode } from "react";
import { useEffect, useMemo, useState } from "react";

type SizeKey = "6.9" | "6.5" | "6.3" | "6.1" | "ipad-13";

type Slide = {
  id: string;
  eyebrow: string;
  headline: ReactNode;
  body: string;
  image: string;
  alt: string;
  accent: string;
  variant: "hero" | "stack" | "map" | "evidence" | "trust" | "matrix";
};

const STORE_SIZES: Record<SizeKey, { label: string; w: number; h: number; device: "iphone" | "ipad" }> = {
  "6.9": { label: "6.9 inch", w: 1320, h: 2868, device: "iphone" },
  "6.5": { label: "6.5 inch", w: 1284, h: 2778, device: "iphone" },
  "6.3": { label: "6.3 inch", w: 1206, h: 2622, device: "iphone" },
  "6.1": { label: "6.1 inch", w: 1125, h: 2436, device: "iphone" },
  "ipad-13": { label: "13 inch iPad", w: 2064, h: 2752, device: "ipad" },
};

const IPHONE_SIZES = Object.fromEntries(
  Object.entries(STORE_SIZES).filter(([, size]) => size.device === "iphone"),
) as Record<Exclude<SizeKey, "ipad-13">, { label: string; w: number; h: number; device: "iphone" }>;

const SLIDES: Slide[] = [
  {
    id: "01-alerts",
    eyebrow: "Critical Alerts",
    headline: (
      <>
        Know what
        <br />
        matters first
      </>
    ),
    body: "Fast context for public-health signals without a noisy feed.",
    image: "/screenshots/simulator/01-alerts-national-emergency.png",
    alt: "HantaAtlas alerts screen",
    accent: "#f07167",
    variant: "hero",
  },
  {
    id: "02-today",
    eyebrow: "Today View",
    headline: (
      <>
        See the
        <br />
        world clearly
      </>
    ),
    body: "A calm global readout for current hantavirus activity.",
    image: "/screenshots/simulator/02-today-global-activity.png",
    alt: "HantaAtlas today screen",
    accent: "#56c8d8",
    variant: "stack",
  },
  {
    id: "03-country",
    eyebrow: "Country Watch",
    headline: (
      <>
        Watch places
        <br />
        you care about
      </>
    ),
    body: "Follow country-level context before a signal gets buried.",
    image: "/screenshots/simulator/03-today-paho-alert.png",
    alt: "HantaAtlas country alert screen",
    accent: "#f5b85b",
    variant: "matrix",
  },
  {
    id: "04-map",
    eyebrow: "Live Atlas",
    headline: (
      <>
        Map risk
        <br />
        by region
      </>
    ),
    body: "Move from headlines to geography in one glance.",
    image: "/screenshots/simulator/04-map-layers.png",
    alt: "HantaAtlas map layers screen",
    accent: "#7dd87d",
    variant: "map",
  },
  {
    id: "05-signal",
    eyebrow: "Signal Detail",
    headline: (
      <>
        Open the
        <br />
        context fast
      </>
    ),
    body: "Tap into the confidence, place, timing, and source trail.",
    image: "/screenshots/simulator/05-map-callout.png",
    alt: "HantaAtlas map callout screen",
    accent: "#f07167",
    variant: "evidence",
  },
  {
    id: "06-sources",
    eyebrow: "Source First",
    headline: (
      <>
        Every claim
        <br />
        stays visible
      </>
    ),
    body: "Built for people who need the citation, not just the alert.",
    image: "/screenshots/simulator/03-today-paho-alert.png",
    alt: "HantaAtlas source-backed signal screen",
    accent: "#d8c16a",
    variant: "trust",
  },
];

const MK_W = 1022;
const MK_H = 2082;
const SCREEN = {
  left: (52 / MK_W) * 100,
  top: (46 / MK_H) * 100,
  width: (918 / MK_W) * 100,
  height: (1990 / MK_H) * 100,
  rx: (126 / 918) * 100,
  ry: (126 / 1990) * 100,
};

function p(value: number, scale: number) {
  return `${Math.round(value * scale)}px`;
}

function numberParam(value: string | null, fallback: number) {
  if (!value) return fallback;
  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function sizeParam(value: string | null): SizeKey {
  return value === "6.5" || value === "6.3" || value === "6.1" || value === "ipad-13" ? value : "6.9";
}

const DEFAULT_PARAMS = { exportMode: false, slide: 1, sizeKey: "6.9" as SizeKey };

function readParamsFromLocation() {
  if (typeof window === "undefined") {
    return DEFAULT_PARAMS;
  }

  const search = new URLSearchParams(window.location.search);
  const sizeKey = sizeParam(search.get("size"));
  const slide = Math.min(Math.max(numberParam(search.get("slide"), 1), 1), SLIDES.length);

  return {
    exportMode: search.get("export") === "1",
    slide,
    sizeKey,
  };
}

function Phone({
  src,
  alt,
  style,
  shadowColor,
}: {
  src: string;
  alt: string;
  style?: CSSProperties;
  shadowColor: string;
}) {
  return (
    <div
      aria-label={alt}
      style={{
        position: "absolute",
        aspectRatio: `${MK_W}/${MK_H}`,
        filter: `drop-shadow(0 46px 76px rgba(0, 0, 0, 0.46)) drop-shadow(0 12px 26px ${shadowColor})`,
        ...style,
      }}
    >
      <img
        alt=""
        draggable={false}
        src="/store-screenshots/mockup.png"
        style={{ display: "block", height: "100%", width: "100%" }}
      />
      <div
        style={{
          borderRadius: `${SCREEN.rx}% / ${SCREEN.ry}%`,
          height: `${SCREEN.height}%`,
          left: `${SCREEN.left}%`,
          overflow: "hidden",
          position: "absolute",
          top: `${SCREEN.top}%`,
          width: `${SCREEN.width}%`,
          zIndex: 2,
        }}
      >
        <img
          alt={alt}
          draggable={false}
          src={src}
          style={{
            display: "block",
            height: "100%",
            objectFit: "cover",
            objectPosition: "top",
            width: "100%",
          }}
        />
      </div>
    </div>
  );
}

function Background({ accent, scale }: { accent: string; scale: number }) {
  return (
    <>
      <div
        style={{
          background:
            "linear-gradient(180deg, #07100f 0%, #0b1716 38%, #11110f 100%)",
          inset: 0,
          position: "absolute",
        }}
      />
      <div
        style={{
          backgroundImage:
            "linear-gradient(rgba(255,255,255,0.055) 1px, transparent 1px), linear-gradient(90deg, rgba(255,255,255,0.045) 1px, transparent 1px)",
          backgroundSize: `${p(92, scale)} ${p(92, scale)}`,
          inset: 0,
          opacity: 0.2,
          position: "absolute",
        }}
      />
      <div
        style={{
          background: `linear-gradient(138deg, transparent 0%, transparent 23%, ${accent}1F 23.2%, ${accent}10 37%, transparent 37.2%, transparent 100%)`,
          inset: 0,
          position: "absolute",
        }}
      />
      <div
        style={{
          background:
            "linear-gradient(180deg, rgba(255,255,255,0.08), transparent 20%, transparent 82%, rgba(0,0,0,0.34))",
          inset: 0,
          position: "absolute",
        }}
      />
    </>
  );
}

function AppMark({ scale }: { scale: number }) {
  return (
    <div
      style={{
        alignItems: "center",
        display: "flex",
        gap: p(20, scale),
        position: "relative",
        zIndex: 5,
      }}
    >
      <img
        alt="HantaAtlas app icon"
        src="/store-screenshots/app-icon.png"
        style={{
          borderRadius: p(28, scale),
          boxShadow: "0 20px 44px rgba(0, 0, 0, 0.38)",
          height: p(94, scale),
          width: p(94, scale),
        }}
      />
      <div
        style={{
          color: "#f9f4e8",
          fontSize: p(34, scale),
          fontWeight: 750,
          lineHeight: 1,
        }}
      >
        HantaAtlas
      </div>
    </div>
  );
}

function Caption({
  slide,
  scale,
  align = "left",
  compact = false,
}: {
  slide: Slide;
  scale: number;
  align?: "left" | "center";
  compact?: boolean;
}) {
  return (
    <div
      style={{
        color: "#fffaf0",
        maxWidth: compact ? p(660, scale) : p(820, scale),
        position: "relative",
        textAlign: align,
        zIndex: 6,
      }}
    >
      <div
        style={{
          alignItems: "center",
          color: slide.accent,
          display: "inline-flex",
          fontSize: p(27, scale),
          fontWeight: 800,
          gap: p(13, scale),
          lineHeight: 1,
          marginBottom: p(30, scale),
          textTransform: "uppercase",
        }}
      >
        <span
          style={{
            background: slide.accent,
            borderRadius: 999,
            display: "inline-block",
            height: p(12, scale),
            width: p(44, scale),
          }}
        />
        {slide.eyebrow}
      </div>
      <h1
        style={{
          color: "#fffaf0",
          fontSize: compact ? p(112, scale) : p(132, scale),
          fontWeight: 850,
          lineHeight: 0.94,
          margin: 0,
        }}
      >
        {slide.headline}
      </h1>
      <p
        style={{
          color: "rgba(255, 250, 240, 0.72)",
          fontSize: p(36, scale),
          fontWeight: 520,
          lineHeight: 1.28,
          margin: `${p(34, scale)} 0 0`,
          maxWidth: p(680, scale),
        }}
      >
        {slide.body}
      </p>
    </div>
  );
}

function DataRails({ scale, accent }: { scale: number; accent: string }) {
  return (
    <div
      style={{
        bottom: p(166, scale),
        display: "grid",
        gap: p(18, scale),
        left: p(88, scale),
        position: "absolute",
        width: p(310, scale),
        zIndex: 4,
      }}
    >
      {["CDC", "PAHO", "WHO"].map((label, index) => (
        <div
          key={label}
          style={{
            alignItems: "center",
            background: "rgba(255,255,255,0.07)",
            border: "1px solid rgba(255,255,255,0.12)",
            borderRadius: p(22, scale),
            color: "rgba(255,250,240,0.82)",
            display: "flex",
            fontSize: p(25, scale),
            fontWeight: 760,
            gap: p(16, scale),
            height: p(76, scale),
            padding: `0 ${p(24, scale)}`,
            transform: `translateX(${p(index * 22, scale)})`,
          }}
        >
          <span
            style={{
              background: index === 1 ? accent : "rgba(255,255,255,0.34)",
              borderRadius: 999,
              height: p(14, scale),
              width: p(14, scale),
            }}
          />
          {label}
        </div>
      ))}
    </div>
  );
}

function SignalChips({ scale, accent }: { scale: number; accent: string }) {
  const chips = ["Confidence", "Location", "Sources"];
  return (
    <div
      style={{
        bottom: p(190, scale),
        display: "flex",
        gap: p(14, scale),
        left: p(96, scale),
        position: "absolute",
        zIndex: 5,
      }}
    >
      {chips.map((chip) => (
        <div
          key={chip}
          style={{
            background: chip === "Sources" ? accent : "rgba(255,255,255,0.08)",
            border: "1px solid rgba(255,255,255,0.12)",
            borderRadius: 999,
            color: chip === "Sources" ? "#06110f" : "rgba(255,250,240,0.82)",
            fontSize: p(24, scale),
            fontWeight: 800,
            padding: `${p(15, scale)} ${p(22, scale)}`,
          }}
        >
          {chip}
        </div>
      ))}
    </div>
  );
}

function IpadFrame({
  src,
  alt,
  style,
  shadowColor,
}: {
  src: string;
  alt: string;
  style?: CSSProperties;
  shadowColor: string;
}) {
  return (
    <div
      aria-label={alt}
      style={{
        aspectRatio: "4 / 3",
        background: "linear-gradient(145deg, #f8f3e8 0%, #d9cfbb 42%, #6b6256 100%)",
        border: "2px solid rgba(255,255,255,0.36)",
        borderRadius: "6.8%",
        boxShadow: `0 54px 92px rgba(0,0,0,0.48), 0 20px 42px ${shadowColor}`,
        padding: "2.25%",
        position: "absolute",
        ...style,
      }}
    >
      <div
        style={{
          background: "#050606",
          borderRadius: "5.2%",
          height: "100%",
          overflow: "hidden",
          position: "relative",
          width: "100%",
        }}
      >
        <img
          alt=""
          draggable={false}
          src={src}
          style={{
            display: "block",
            filter: "blur(18px) saturate(1.1) brightness(0.62)",
            height: "112%",
            inset: "-6%",
            objectFit: "cover",
            objectPosition: "top",
            opacity: 0.72,
            position: "absolute",
            width: "112%",
          }}
        />
        <div
          style={{
            background:
              "linear-gradient(90deg, rgba(7,16,15,0.76), transparent 28%, transparent 72%, rgba(7,16,15,0.76))",
            inset: 0,
            position: "absolute",
            zIndex: 1,
          }}
        />
        <img
          alt={alt}
          draggable={false}
          src={src}
          style={{
            borderRadius: "3.2%",
            boxShadow: "0 24px 58px rgba(0,0,0,0.42)",
            display: "block",
            height: "100%",
            left: "50%",
            objectFit: "cover",
            objectPosition: "top",
            position: "absolute",
            top: 0,
            transform: "translateX(-50%)",
            width: "46.2%",
            zIndex: 2,
          }}
        />
      </div>
    </div>
  );
}

function IpadSlideCanvas({
  slide,
  index,
  size,
}: {
  slide: Slide;
  index: number;
  size: { w: number; h: number };
}) {
  const scale = size.w / 2064;
  const supportingImage =
    slide.variant === "trust"
      ? "/screenshots/simulator/05-map-callout.png"
      : slide.variant === "map"
        ? "/screenshots/simulator/04-map-layers.png"
        : "/screenshots/simulator/01-alerts-national-emergency.png";

  return (
    <section
      data-slide-id={`ipad-${slide.id}`}
      style={{
        background: "#07100f",
        color: "#fffaf0",
        height: `${size.h}px`,
        overflow: "hidden",
        position: "relative",
        width: `${size.w}px`,
      }}
    >
      <Background accent={slide.accent} scale={size.w / 1320} />

      <div
        style={{
          left: p(118, scale),
          position: "absolute",
          right: p(118, scale),
          top: p(106, scale),
          zIndex: 6,
        }}
      >
        <AppMark scale={scale * 1.18} />
      </div>

      <div style={{ left: p(124, scale), position: "absolute", top: p(330, scale), zIndex: 7 }}>
        <Caption compact slide={slide} scale={scale * 1.26} />
      </div>

      <IpadFrame
        alt={slide.alt}
        shadowColor={`${slide.accent}55`}
        src={slide.image}
        style={{
          bottom: p(326, scale),
          right: p(116, scale),
          width: p(1248, scale),
          zIndex: 4,
        }}
      />

      <Phone
        alt="HantaAtlas supporting iPhone view"
        shadowColor="rgba(0,0,0,0.34)"
        src={supportingImage}
        style={{
          bottom: p(110, scale),
          left: p(128, scale),
          opacity: 0.78,
          transform: "rotate(-4deg)",
          width: p(468, scale),
          zIndex: 5,
        }}
      />

      <div
        style={{
          alignItems: "center",
          background: "rgba(255,255,255,0.08)",
          border: "1px solid rgba(255,255,255,0.14)",
          borderRadius: p(34, scale),
          bottom: p(164, scale),
          color: "rgba(255,250,240,0.84)",
          display: "flex",
          fontSize: p(30, scale),
          fontWeight: 800,
          gap: p(18, scale),
          left: p(702, scale),
          padding: `${p(28, scale)} ${p(34, scale)}`,
          position: "absolute",
          zIndex: 8,
        }}
      >
        <span
          style={{
            background: slide.accent,
            borderRadius: 999,
            display: "inline-block",
            height: p(16, scale),
            width: p(16, scale),
          }}
        />
        Built for iPad and iPhone
      </div>

      <div
        style={{
          bottom: p(70, scale),
          color: "rgba(255,250,240,0.36)",
          fontSize: p(28, scale),
          fontWeight: 700,
          position: "absolute",
          right: p(104, scale),
          zIndex: 9,
        }}
      >
        {String(index + 1).padStart(2, "0")} / {String(SLIDES.length).padStart(2, "0")}
      </div>
    </section>
  );
}

function SlideCanvas({
  slide,
  index,
  size,
}: {
  slide: Slide;
  index: number;
  size: { w: number; h: number };
}) {
  const scale = size.w / 1320;
  const commonPhoneShadow = `${slide.accent}55`;

  return (
    <section
      data-slide-id={slide.id}
      style={{
        background: "#07100f",
        color: "#fffaf0",
        height: `${size.h}px`,
        overflow: "hidden",
        position: "relative",
        width: `${size.w}px`,
      }}
    >
      <Background accent={slide.accent} scale={scale} />
      <div
        style={{
          left: p(82, scale),
          position: "absolute",
          right: p(82, scale),
          top: p(92, scale),
          zIndex: 6,
        }}
      >
        <AppMark scale={scale} />
      </div>

      {slide.variant === "hero" ? (
        <>
          <div style={{ left: p(86, scale), position: "absolute", top: p(278, scale) }}>
            <Caption slide={slide} scale={scale} />
          </div>
          <Phone
            alt={slide.alt}
            shadowColor={commonPhoneShadow}
            src={slide.image}
            style={{
              bottom: p(-110, scale),
              left: p(278, scale),
              width: p(764, scale),
              zIndex: 5,
            }}
          />
          <DataRails accent={slide.accent} scale={scale} />
        </>
      ) : null}

      {slide.variant === "stack" ? (
        <>
          <div style={{ left: p(88, scale), position: "absolute", top: p(270, scale) }}>
            <Caption compact slide={slide} scale={scale} />
          </div>
          <Phone
            alt={slide.alt}
            shadowColor={commonPhoneShadow}
            src={slide.image}
            style={{
              bottom: p(-84, scale),
              left: p(380, scale),
              transform: "rotate(2deg)",
              width: p(710, scale),
              zIndex: 5,
            }}
          />
          <Phone
            alt="HantaAtlas supporting alert screen"
            shadowColor="rgba(0,0,0,0.38)"
            src="/screenshots/simulator/01-alerts-national-emergency.png"
            style={{
              bottom: p(110, scale),
              left: p(98, scale),
              opacity: 0.54,
              transform: "rotate(-6deg)",
              width: p(432, scale),
              zIndex: 3,
            }}
          />
        </>
      ) : null}

      {slide.variant === "matrix" ? (
        <>
          <div style={{ left: p(86, scale), position: "absolute", top: p(280, scale) }}>
            <Caption compact slide={slide} scale={scale} />
          </div>
          <div
            style={{
              background: "rgba(255,255,255,0.075)",
              border: "1px solid rgba(255,255,255,0.13)",
              borderRadius: p(42, scale),
              bottom: p(250, scale),
              color: "rgba(255,250,240,0.82)",
              fontSize: p(28, scale),
              fontWeight: 760,
              left: p(84, scale),
              padding: `${p(24, scale)} ${p(28, scale)}`,
              position: "absolute",
              zIndex: 5,
            }}
          >
            Argentina / Chile / United States
          </div>
          <Phone
            alt={slide.alt}
            shadowColor={commonPhoneShadow}
            src={slide.image}
            style={{
              bottom: p(-90, scale),
              right: p(106, scale),
              width: p(746, scale),
              zIndex: 4,
            }}
          />
        </>
      ) : null}

      {slide.variant === "map" ? (
        <>
          <div style={{ left: p(86, scale), position: "absolute", top: p(278, scale) }}>
            <Caption slide={slide} scale={scale} />
          </div>
          <div
            style={{
              border: `2px solid ${slide.accent}88`,
              borderRadius: "50%",
              bottom: p(720, scale),
              height: p(360, scale),
              position: "absolute",
              right: p(52, scale),
              width: p(360, scale),
              zIndex: 2,
            }}
          />
          <Phone
            alt={slide.alt}
            shadowColor={commonPhoneShadow}
            src={slide.image}
            style={{
              bottom: p(-130, scale),
              left: p(286, scale),
              width: p(768, scale),
              zIndex: 5,
            }}
          />
        </>
      ) : null}

      {slide.variant === "evidence" ? (
        <>
          <div style={{ left: p(86, scale), position: "absolute", top: p(278, scale) }}>
            <Caption compact slide={slide} scale={scale} />
          </div>
          <Phone
            alt={slide.alt}
            shadowColor={commonPhoneShadow}
            src={slide.image}
            style={{
              bottom: p(-98, scale),
              left: p(326, scale),
              width: p(728, scale),
              zIndex: 5,
            }}
          />
          <SignalChips accent={slide.accent} scale={scale} />
        </>
      ) : null}

      {slide.variant === "trust" ? (
        <>
          <div style={{ left: p(86, scale), position: "absolute", top: p(270, scale) }}>
            <Caption compact slide={slide} scale={scale} />
          </div>
          <Phone
            alt={slide.alt}
            shadowColor={commonPhoneShadow}
            src={slide.image}
            style={{
              bottom: p(72, scale),
              left: p(96, scale),
              transform: "rotate(-4deg)",
              width: p(520, scale),
              zIndex: 4,
            }}
          />
          <Phone
            alt="HantaAtlas map detail screen"
            shadowColor="rgba(86,200,216,0.34)"
            src="/screenshots/simulator/05-map-callout.png"
            style={{
              bottom: p(-72, scale),
              right: p(94, scale),
              transform: "rotate(4deg)",
              width: p(646, scale),
              zIndex: 5,
            }}
          />
          <div
            style={{
              background: "rgba(255,255,255,0.08)",
              border: "1px solid rgba(255,255,255,0.14)",
              borderRadius: p(38, scale),
              bottom: p(206, scale),
              color: "#fffaf0",
              fontSize: p(30, scale),
              fontWeight: 820,
              left: p(542, scale),
              padding: `${p(25, scale)} ${p(31, scale)}`,
              position: "absolute",
              zIndex: 7,
            }}
          >
            Source-backed by design
          </div>
        </>
      ) : null}

      <div
        style={{
          bottom: p(56, scale),
          color: "rgba(255,250,240,0.36)",
          fontSize: p(22, scale),
          fontWeight: 700,
          position: "absolute",
          right: p(72, scale),
          zIndex: 9,
        }}
      >
        {String(index + 1).padStart(2, "0")} / {String(SLIDES.length).padStart(2, "0")}
      </div>
    </section>
  );
}

export default function StoreScreenshotsPage() {
  const [params, setParams] = useState(DEFAULT_PARAMS);

  useEffect(() => {
    const nextParams = readParamsFromLocation();
    const frame = window.requestAnimationFrame(() => setParams(nextParams));
    return () => window.cancelAnimationFrame(frame);
  }, []);

  const size = STORE_SIZES[params.sizeKey];
  const current = SLIDES[params.slide - 1] ?? SLIDES[0];

  const exportLinks = useMemo(
    () =>
      SLIDES.flatMap((slide, slideIndex) =>
        Object.entries(STORE_SIZES).map(([key, value]) => ({
          href: `/store-screenshots?export=1&slide=${slideIndex + 1}&size=${key}`,
          label: `${slideIndex + 1} - ${slide.id} - ${value.label}`,
        })),
      ),
    [],
  );

  if (params.exportMode) {
    return (
      <main
        style={{
          background: "#07100f",
          height: `${size.h}px`,
          margin: 0,
          overflow: "hidden",
          width: `${size.w}px`,
        }}
      >
        {size.device === "ipad" ? (
          <IpadSlideCanvas index={params.slide - 1} size={size} slide={current} />
        ) : (
          <SlideCanvas index={params.slide - 1} size={size} slide={current} />
        )}
      </main>
    );
  }

  return (
    <main className="min-h-screen bg-[#091210] px-6 py-8 text-[#fffaf0]">
      <div className="mx-auto flex max-w-7xl flex-col gap-8">
        <header className="flex flex-wrap items-end justify-between gap-5">
          <div>
            <p className="text-sm font-bold uppercase text-[#56c8d8]">HantaAtlas</p>
            <h1 className="mt-2 text-4xl font-black">Apple App Store screenshots</h1>
            <p className="mt-3 max-w-2xl text-base text-white/65">
              Six premium Apple App Store slides for iPhone and 13-inch iPad.
              Open an export link, then capture the viewport at the listed size.
            </p>
          </div>
          <div className="flex flex-wrap gap-2 text-sm">
            {exportLinks.slice(0, 6).map((link) => (
              <a
                className="rounded-full border border-white/15 px-4 py-2 font-bold text-white/78 hover:border-[#56c8d8] hover:text-white"
                href={link.href}
                key={link.href}
              >
                {link.label}
              </a>
            ))}
          </div>
        </header>

        <section className="grid gap-8 lg:grid-cols-2">
          {SLIDES.map((slide, index) => (
            <div className="overflow-hidden rounded-[20px] border border-white/10 bg-white/[0.04] p-3" key={slide.id}>
              <div
                style={{
                  aspectRatio: "1320 / 2868",
                  height: "1205px",
                  overflow: "hidden",
                  position: "relative",
                  width: "100%",
                }}
              >
                <div
                  style={{
                    left: 0,
                    position: "absolute",
                    top: 0,
                    transform: "scale(0.42)",
                    transformOrigin: "top left",
                  }}
                >
                  <SlideCanvas index={index} size={IPHONE_SIZES["6.9"]} slide={slide} />
                </div>
              </div>
            </div>
          ))}
        </section>
      </div>
    </main>
  );
}
