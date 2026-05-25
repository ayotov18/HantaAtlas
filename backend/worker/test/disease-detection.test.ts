import { describe, it, expect } from "vitest";
import { detectDisease, EBOLA_FILTER, HANTA_FILTER, TOPIC_FILTER_ANY } from "../src/disease-detection.js";

describe("detectDisease", () => {
    it("tags Ebola from ebola-specific terms", () => {
        expect(detectDisease("Ebola outbreak declared in DRC", "Zaire ebolavirus confirmed")).toBe("ebola");
        expect(detectDisease("EVD cases rise in Uganda", null)).toBe("ebola");
        expect(detectDisease("Sudan ebolavirus cluster", undefined)).toBe("ebola");
    });

    it("tags Hantavirus from hanta-specific terms", () => {
        expect(detectDisease("Hantavirus pulmonary syndrome cluster", "Andes virus")).toBe("hantavirus");
        expect(detectDisease("HFRS cases reported", null)).toBe("hantavirus");
        expect(detectDisease("Sin Nombre virus exposure", undefined)).toBe("hantavirus");
    });

    it("returns null for off-topic items", () => {
        expect(detectDisease("Cholera outbreak in coastal region", "measles vaccination drive")).toBeNull();
        expect(detectDisease("Seasonal influenza update", null)).toBeNull();
    });

    it("does NOT mis-tag Marburg or generic VHF as Ebola", () => {
        expect(detectDisease("Marburg virus disease case", null)).toBeNull();
    });

    it("breaks a both-mentioned tie by keyword density", () => {
        expect(detectDisease("Ebola and EVD spread fast; brief hantavirus note", null)).toBe("ebola");
        expect(detectDisease("Hantavirus HFRS surge; one ebola mention", null)).toBe("hantavirus");
    });

    it("union filter matches either disease but not unrelated topics", () => {
        expect(TOPIC_FILTER_ANY.test("ebola virus disease")).toBe(true);
        expect(TOPIC_FILTER_ANY.test("hantavirus")).toBe(true);
        expect(TOPIC_FILTER_ANY.test("dengue fever")).toBe(false);
    });

    it("per-disease filters are disjoint on specific terms", () => {
        expect(EBOLA_FILTER.test("ebolavirus")).toBe(true);
        expect(EBOLA_FILTER.test("hantavirus")).toBe(false);
        expect(HANTA_FILTER.test("puumala")).toBe(true);
        expect(HANTA_FILTER.test("ebolavirus")).toBe(false);
    });
});
