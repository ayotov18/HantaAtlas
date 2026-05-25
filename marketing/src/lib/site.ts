export const siteConfig = {
  name: "HantaAtlas",
  url: process.env.NEXT_PUBLIC_SITE_URL ?? "https://thehantaapp.com",
  appStoreUrl: process.env.NEXT_PUBLIC_APP_STORE_URL ?? "#app-store",
  supportEmail: "support@thehantaapp.com",
  apiUrl: process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3000",
  description:
    "HantaAtlas is a source-backed hantavirus and Ebola outbreak tracker app for maps, country alerts, saved watchlists, and public-health signal context.",
};

export const appleSystemFont =
  '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Helvetica Neue", Arial, sans-serif';
