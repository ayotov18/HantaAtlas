import { describe, expect, it } from "vitest";
import { buildApp } from "../src/app.js";

describe("HantaAtlas API", () => {
  it("returns summary with official source context", async () => {
    const app = buildApp();
    const response = await app.inject({ method: "GET", url: "/v1/summary" });
    expect(response.statusCode).toBe(200);
    const payload = response.json();
    expect(payload.latestAlert.confidenceLevel).toBe("OFFICIAL_ALERT");
    await app.close();
  });

  it("returns country details by ISO code", async () => {
    const app = buildApp();
    const response = await app.inject({ method: "GET", url: "/v1/countries/AR" });
    expect(response.statusCode).toBe(200);
    expect(response.json().virusType).toBe("Andes virus");
    await app.close();
  });

  it("returns the full country list", async () => {
    const app = buildApp();
    const response = await app.inject({ method: "GET", url: "/v1/countries" });
    expect(response.statusCode).toBe(200);
    const payload = response.json();
    expect(Array.isArray(payload)).toBe(true);
    const isoCodes = payload.map((country: { isoCode: string }) => country.isoCode);
    expect(isoCodes).toContain("AR");
    expect(isoCodes).toContain("CL");
    expect(isoCodes).toContain("US");
  });
});

