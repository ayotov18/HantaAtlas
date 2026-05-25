import { describe, expect, it } from "vitest";
import { classifyPostType } from "../src/classifier.js";

describe("classifyPostType — 7-bucket post-type taxonomy", () => {
    it("classifies a fatal headline as DEATH", () => {
        const result = classifyPostType(
            "Hantavirus death confirmed in Argentina, two more in critical condition",
            null,
            "LOCAL"
        );
        expect(result).toBe("DEATH");
    });

    it("classifies multilingual death keywords (Spanish: muerte)", () => {
        const result = classifyPostType(
            "Confirman muerte por hantavirus en Patagonia",
            null,
            "LOCAL"
        );
        expect(result).toBe("DEATH");
    });

    it("classifies a confirmed-case headline as CASE_CONFIRMED", () => {
        const result = classifyPostType(
            "Spain reports first lab-confirmed hantavirus case in Alicante",
            null,
            "LOCAL"
        );
        expect(result).toBe("CASE_CONFIRMED");
    });

    it("classifies an imported case as CASE_IMPORTED via category", () => {
        const result = classifyPostType(
            "UK traveller returning from South America falls ill",
            null,
            "IMPORTED"
        );
        expect(result).toBe("CASE_IMPORTED");
    });

    it("classifies a suspected case as CASE_SUSPECTED", () => {
        const result = classifyPostType(
            "España analiza un caso sospechoso de hantavirus tras detectar a una persona",
            null,
            "MEDIA"
        );
        // Spanish "caso sospechoso" hits the suspected list.
        expect(result).toBe("CASE_SUSPECTED");
    });

    it("classifies an advisory as OFFICIAL_RESPONSE via category", () => {
        const result = classifyPostType(
            "Travel advisory issued for return travellers from affected regions",
            null,
            "RESPONSE"
        );
        expect(result).toBe("OFFICIAL_RESPONSE");
    });

    it("classifies an expert prediction as EXPERT_VOICE", () => {
        const result = classifyPostType(
            "Experts warn hantavirus cases could rise across Europe this winter",
            null,
            "MEDIA"
        );
        expect(result).toBe("EXPERT_VOICE");
    });

    it("falls back to PUBLIC_DISCOURSE for generic media mentions", () => {
        const result = classifyPostType(
            "What is hantavirus? A primer from our health desk",
            null,
            "MEDIA"
        );
        expect(result).toBe("PUBLIC_DISCOURSE");
    });

    it("DEATH wins over CASE_CONFIRMED when both match (precedence)", () => {
        const result = classifyPostType(
            "Health Ministry confirms 8 hantavirus cases in Argentina, 3 deaths",
            null,
            "LOCAL"
        );
        expect(result).toBe("DEATH");
    });

    it("CASE_CONFIRMED wins over EXPERT_VOICE (precedence)", () => {
        const result = classifyPostType(
            "Lab-confirmed hantavirus case prompts expert warnings",
            null,
            "LOCAL"
        );
        expect(result).toBe("CASE_CONFIRMED");
    });
});
