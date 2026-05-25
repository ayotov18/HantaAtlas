import Link from "next/link";

import { siteConfig } from "@/lib/site";

const footerLinks = [
  { label: "Privacy", href: "/privacy" },
  { label: "Terms", href: "/tos" },
  { label: "Support", href: "/support" },
  { label: "Source methodology", href: `${siteConfig.apiUrl}/openapi.json` },
];

export function SiteFooter() {
  return (
    <footer className="border-t border-border bg-background px-6 py-12">
      <div className="mx-auto grid max-w-6xl gap-8 md:grid-cols-[1fr_1.2fr]">
        <div>
          <p className="text-lg font-semibold">HantaAtlas</p>
          <p className="mt-3 max-w-md text-sm leading-6 text-muted-foreground">
            Informational public-health surveillance for iPhone. Not diagnosis,
            treatment, personal risk prediction, or emergency guidance.
          </p>
        </div>
        <div className="flex flex-col gap-5 md:items-end">
          <div className="flex flex-wrap gap-x-5 gap-y-3 text-sm text-muted-foreground">
            {footerLinks.map((link) => (
              <Link className="transition-colors hover:text-foreground" href={link.href} key={link.href}>
                {link.label}
              </Link>
            ))}
            <a className="transition-colors hover:text-foreground" href={`mailto:${siteConfig.supportEmail}`}>
              Contact
            </a>
          </div>
          <p className="text-xs leading-5 text-muted-foreground">
            Background video: Mikhail Nilov via Pexels. Pexels license allows
            free use and modification; no endorsement implied.
          </p>
        </div>
      </div>
    </footer>
  );
}
