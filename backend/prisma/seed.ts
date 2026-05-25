import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const region = await prisma.countryRegion.upsert({
    where: { name: "South America" },
    update: {},
    create: { id: "region-south-america", name: "South America" }
  });

  const source = await prisma.source.upsert({
    where: { slug: "paho" },
    update: {},
    create: {
      id: "source-paho",
      slug: "paho",
      organisation: "PAHO",
      url: "https://www.paho.org/",
      sourceType: "official-alert",
      lastSuccessfulFetchAt: new Date("2026-05-08T09:41:00+03:00")
    }
  });

  const country = await prisma.country.upsert({
    where: { isoCode: "AR" },
    update: {},
    create: {
      id: "country-ar",
      isoCode: "AR",
      name: "Argentina",
      regionId: region.id
    }
  });

  await prisma.countrySnapshot.create({
    data: {
      countryId: country.id,
      sourceId: source.id,
      cases: 18,
      deaths: 4,
      confidenceLevel: "OFFICIAL_ALERT",
      reportingPeriodLabel: "Recent official alert",
      reportedAt: new Date("2026-05-05T12:00:00Z"),
      publishedAt: new Date("2026-05-07T12:00:00Z"),
      lastCheckedAt: new Date("2026-05-08T09:41:00+03:00"),
      sourceUrl: source.url,
      summary: "Official regional alert with confirmed cases and rural prevention guidance.",
      virusType: "Andes virus",
      limitations: "Alert-led public data; comparable national table not assumed."
    }
  });
}

main()
  .finally(async () => {
    await prisma.$disconnect();
  });

