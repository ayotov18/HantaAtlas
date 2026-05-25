import { siteConfig } from "@/lib/site";

export const softwareApplicationJsonLd = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "HantaAtlas",
  applicationCategory: "HealthApplication",
  operatingSystem: "iOS",
  url: siteConfig.url,
  offers: {
    "@type": "Offer",
    price: "0",
    priceCurrency: "USD",
    availability: "https://schema.org/PreOrder",
  },
  description: siteConfig.description,
};

export const websiteJsonLd = {
  "@context": "https://schema.org",
  "@type": "WebSite",
  name: "HantaAtlas",
  url: siteConfig.url,
  potentialAction: {
    "@type": "SearchAction",
    target: `${siteConfig.url}/?q={search_term_string}`,
    "query-input": "required name=search_term_string",
  },
};

export const faqJsonLd = {
  "@context": "https://schema.org",
  "@type": "FAQPage",
  mainEntity: [
    {
      "@type": "Question",
      name: "Is HantaAtlas medical advice?",
      acceptedAnswer: {
        "@type": "Answer",
        text: "No. HantaAtlas is informational public-health surveillance. It is not diagnosis, treatment, a personal risk predictor, or a replacement for medical advice.",
      },
    },
    {
      "@type": "Question",
      name: "Which diseases does HantaAtlas track?",
      acceptedAnswer: {
        "@type": "Answer",
        text: "Hantavirus and Ebola. You can view both together or focus on either one, with source-backed signals, confidence labels, and country context for each.",
      },
    },
    {
      "@type": "Question",
      name: "Where does the app get its data?",
      acceptedAnswer: {
        "@type": "Answer",
        text: "The app summarizes public-health and source-backed signals with source organizations, links, dates, confidence labels, and limitations visible in the product.",
      },
    },
    {
      "@type": "Question",
      name: "Can I track country alerts?",
      acceptedAnswer: {
        "@type": "Answer",
        text: "Yes. Users can save countries and, when enabled, receive opt-in alerts for relevant public-health signals.",
      },
    },
  ],
};
