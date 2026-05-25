import { describe, expect, it } from "vitest";
import { extractMediaFromHtml, extractMediaFromRaw } from "../src/media-enrichment.js";

describe("media enrichment", () => {
    it("extracts Open Graph image metadata", () => {
        const media = extractMediaFromHtml(`
            <html>
                <head>
                    <meta property="og:image" content="/hero.jpg">
                    <meta property="og:image:width" content="1200">
                    <meta property="og:image:height" content="630">
                </head>
            </html>
        `, "https://publisher.example/story");

        expect(media?.status).toBe("FOUND");
        expect(media?.type).toBe("IMAGE");
        expect(media?.url).toBe("https://publisher.example/hero.jpg");
        expect(media?.width).toBe(1200);
        expect(media?.height).toBe(630);
    });

    it("extracts RSS media content from raw adapter items", () => {
        const media = extractMediaFromRaw({
            mediaUrl: "https://cdn.example/video.mp4",
            mediaThumbnailUrl: "https://cdn.example/thumb.jpg",
            mediaType: "video/mp4"
        }, "https://publisher.example/story");

        expect(media?.type).toBe("VIDEO");
        expect(media?.url).toBe("https://cdn.example/video.mp4");
        expect(media?.thumbnailUrl).toBe("https://cdn.example/thumb.jpg");
    });

    it("extracts JSON Feed image fields", () => {
        const media = extractMediaFromRaw({
            image: "https://publisher.example/image.webp"
        }, "https://publisher.example/story");

        expect(media?.type).toBe("IMAGE");
        expect(media?.thumbnailUrl).toBe("https://publisher.example/image.webp");
    });
});
