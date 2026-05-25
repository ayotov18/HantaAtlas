export type SignalMediaType = "IMAGE" | "VIDEO" | "EMBED";
export type SignalMediaStatus = "FOUND" | "NONE" | "FAILED";

export interface SignalMediaResult {
    status: SignalMediaStatus;
    type: SignalMediaType | null;
    url: string | null;
    thumbnailUrl: string | null;
    provider: string | null;
    sourceUrl: string | null;
    width: number | null;
    height: number | null;
}

const USER_AGENT = "HantaAtlas-worker/1.0 (+https://api.thehantaapp.com)";

export function extractMediaFromRaw(raw: unknown, sourceUrl: string): SignalMediaResult | null {
    if (!raw || typeof raw !== "object") return null;
    const record = raw as Record<string, unknown>;
    const provider = providerFromUrl(sourceUrl);
    const mediaUrl = firstString(record.mediaUrl);
    const mediaType = firstString(record.mediaType)?.toLowerCase() ?? "";
    if (mediaUrl) {
        const url = absolutize(mediaUrl, sourceUrl);
        const thumb = firstString(record.mediaThumbnailUrl);
        const thumbnailUrl = thumb ? absolutize(thumb, sourceUrl) : null;
        if (url && mediaType.startsWith("video/")) {
            return found("VIDEO", url, thumbnailUrl, provider, sourceUrl, numberValue(record.mediaWidth), numberValue(record.mediaHeight));
        }
        if (url && (mediaType.startsWith("image/") || thumbnailUrl || looksLikeImageUrl(url))) {
            return found("IMAGE", url, thumbnailUrl ?? url, provider, sourceUrl, numberValue(record.mediaWidth), numberValue(record.mediaHeight));
        }
    }

    const image = firstString(
        record.image,
        record.banner_image,
        record.mediaThumbnailUrl
    );
    if (image) {
        const url = absolutize(image, sourceUrl);
        if (url) {
            return found("IMAGE", url, url, provider, sourceUrl, numberValue(record.mediaWidth), numberValue(record.mediaHeight));
        }
    }

    const attachments = Array.isArray(record.attachments) ? record.attachments : [];
    for (const attachment of attachments) {
        if (!attachment || typeof attachment !== "object") continue;
        const item = attachment as Record<string, unknown>;
        const rawUrl = firstString(item.url);
        const url = rawUrl ? absolutize(rawUrl, sourceUrl) : null;
        if (!url) continue;
        const mime = firstString(item.mime_type, item.mimeType, item.type)?.toLowerCase() ?? "";
        if (mime.startsWith("video/")) {
            const thumb = firstString(item.image, item.thumbnailUrl);
            return found("VIDEO", url, thumb ? absolutize(thumb, sourceUrl) : null, provider, sourceUrl, null, null);
        }
        if (mime.startsWith("image/") || looksLikeImageUrl(url)) {
            return found("IMAGE", url, url, provider, sourceUrl, null, null);
        }
    }

    return null;
}

export async function enrichSignalMedia(sourceUrl: string, raw?: unknown): Promise<SignalMediaResult> {
    const rawMedia = extractMediaFromRaw(raw, sourceUrl);
    if (rawMedia) return rawMedia;

    let timeout: ReturnType<typeof setTimeout> | null = null;
    try {
        const controller = new AbortController();
        timeout = setTimeout(() => controller.abort(), 4_000);
        const response = await fetch(sourceUrl, {
            redirect: "follow",
            signal: controller.signal,
            headers: {
                "user-agent": USER_AGENT,
                "accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/*;q=0.8,video/*;q=0.7,*/*;q=0.5"
            }
        });
        if (timeout) clearTimeout(timeout);
        timeout = null;

        if (!response.ok) {
            return none("FAILED", sourceUrl);
        }

        const finalUrl = response.url || sourceUrl;
        const contentType = response.headers.get("content-type")?.toLowerCase() ?? "";
        if (contentType.startsWith("image/")) {
            return found("IMAGE", finalUrl, finalUrl, providerFromUrl(finalUrl), finalUrl, null, null);
        }
        if (contentType.startsWith("video/")) {
            return found("VIDEO", finalUrl, null, providerFromUrl(finalUrl), finalUrl, null, null);
        }
        if (!contentType.includes("html") && !contentType.includes("xml") && contentType !== "") {
            return none("NONE", finalUrl);
        }

        const html = await response.text();
        return extractMediaFromHtml(html, finalUrl) ?? none("NONE", finalUrl);
    } catch {
        return none("FAILED", sourceUrl);
    } finally {
        if (timeout) clearTimeout(timeout);
    }
}

export function extractMediaFromHtml(html: string, sourceUrl: string): SignalMediaResult | null {
    const provider = providerFromUrl(sourceUrl);
    const image = firstMeta(html, [
        "og:image:secure_url",
        "og:image:url",
        "og:image",
        "twitter:image:src",
        "twitter:image",
        "thumbnail"
    ]) ?? extractJsonLdImage(html);
    const video = firstMeta(html, [
        "og:video:secure_url",
        "og:video:url",
        "og:video",
        "twitter:player:stream"
    ]);
    const embed = firstMeta(html, ["twitter:player"]);
    const width = numberValue(firstMeta(html, ["og:image:width", "twitter:image:width"]));
    const height = numberValue(firstMeta(html, ["og:image:height", "twitter:image:height"]));

    if (video) {
        const url = absolutize(video, sourceUrl);
        if (url) {
            const thumb = image ? absolutize(image, sourceUrl) : null;
            return found("VIDEO", url, thumb, provider, sourceUrl, width, height);
        }
    }

    if (embed) {
        const url = absolutize(embed, sourceUrl);
        if (url) {
            const thumb = image ? absolutize(image, sourceUrl) : null;
            return found("EMBED", url, thumb, provider, sourceUrl, width, height);
        }
    }

    if (image) {
        const url = absolutize(image, sourceUrl);
        if (url) {
            return found("IMAGE", url, url, provider, sourceUrl, width, height);
        }
    }

    return null;
}

function found(
    type: SignalMediaType,
    url: string,
    thumbnailUrl: string | null,
    provider: string | null,
    sourceUrl: string,
    width: number | null,
    height: number | null
): SignalMediaResult {
    return {
        status: "FOUND",
        type,
        url,
        thumbnailUrl,
        provider,
        sourceUrl,
        width,
        height
    };
}

function none(status: "NONE" | "FAILED", sourceUrl: string): SignalMediaResult {
    return {
        status,
        type: null,
        url: null,
        thumbnailUrl: null,
        provider: providerFromUrl(sourceUrl),
        sourceUrl,
        width: null,
        height: null
    };
}

function firstMeta(html: string, keys: string[]): string | null {
    const wanted = new Set(keys.map((key) => key.toLowerCase()));
    const tags = html.match(/<meta\b[^>]*>/gi) ?? [];
    for (const tag of tags) {
        const key = readAttr(tag, "property") ?? readAttr(tag, "name") ?? readAttr(tag, "itemprop");
        if (!key || !wanted.has(key.toLowerCase())) continue;
        const content = readAttr(tag, "content");
        if (content) return decodeHtml(content);
    }
    return null;
}

function extractJsonLdImage(html: string): string | null {
    const scripts = html.match(/<script\b[^>]*application\/ld\+json[^>]*>[\s\S]*?<\/script>/gi) ?? [];
    for (const script of scripts) {
        const body = script.replace(/^<script\b[^>]*>/i, "").replace(/<\/script>$/i, "").trim();
        try {
            const parsed = JSON.parse(body);
            const image = findImageValue(parsed);
            if (image) return image;
        } catch {
            continue;
        }
    }
    return null;
}

function findImageValue(value: unknown): string | null {
    if (!value) return null;
    if (typeof value === "string") return value;
    if (Array.isArray(value)) {
        for (const item of value) {
            const foundValue = findImageValue(item);
            if (foundValue) return foundValue;
        }
        return null;
    }
    if (typeof value !== "object") return null;

    const record = value as Record<string, unknown>;
    for (const key of ["image", "thumbnailUrl", "thumbnail"]) {
        const candidate = record[key];
        if (typeof candidate === "string") return candidate;
        if (Array.isArray(candidate) || (candidate && typeof candidate === "object")) {
            const foundValue = findImageValue(candidate);
            if (foundValue) return foundValue;
        }
    }
    if (typeof record.url === "string" && looksLikeImageUrl(record.url)) {
        return record.url;
    }
    return null;
}

function readAttr(tag: string, attr: string): string | null {
    const pattern = new RegExp(`\\b${attr}\\s*=\\s*("([^"]*)"|'([^']*)'|([^\\s>]+))`, "i");
    const match = tag.match(pattern);
    if (!match) return null;
    return match[2] ?? match[3] ?? match[4] ?? null;
}

function firstString(...values: unknown[]): string | null {
    for (const value of values) {
        if (typeof value === "string" && value.trim()) return value.trim();
    }
    return null;
}

function numberValue(value: unknown): number | null {
    if (typeof value === "number" && Number.isFinite(value)) return Math.trunc(value);
    if (typeof value !== "string") return null;
    const parsed = Number(value);
    return Number.isFinite(parsed) ? Math.trunc(parsed) : null;
}

function absolutize(value: string, baseUrl: string): string | null {
    try {
        const url = new URL(decodeHtml(value), baseUrl);
        if (url.protocol !== "http:" && url.protocol !== "https:") return null;
        return url.toString();
    } catch {
        return null;
    }
}

function providerFromUrl(value: string): string | null {
    try {
        return new URL(value).hostname.replace(/^www\./, "");
    } catch {
        return null;
    }
}

function looksLikeImageUrl(value: string): boolean {
    return /\.(avif|gif|jpe?g|png|webp)(\?|#|$)/i.test(value);
}

function decodeHtml(value: string): string {
    return value
        .replace(/&amp;/g, "&")
        .replace(/&quot;/g, "\"")
        .replace(/&#39;/g, "'")
        .replace(/&apos;/g, "'")
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .trim();
}
