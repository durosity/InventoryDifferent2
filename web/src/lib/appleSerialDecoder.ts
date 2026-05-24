// TypeScript port of the Apple serial number decoder.
// Mirrors tools/serial-decoder/Sources/SerialDecoderLib/ logic exactly.
// Keep in sync when adding vintage model codes or updating the modern table.

import { modernModelCodes } from "./modernModels";

// ── Types ─────────────────────────────────────────────────────────────────────

export interface VintageSerialResult {
    type: "vintage";
    serial: string;
    factoryCode: string;
    factory?: string;
    year: number;
    week: number;
    modelCode: string;
    modelName?: string;
    warnings: string[];
}

export interface ModernSerialResult {
    type: "modern";
    serial: string;
    format: string;
    factoryCode: string;
    configCode: string;
    modelIdentifier?: string;
    modelName?: string;
    warnings: string[];
}

export type SerialDecodeResult =
    | VintageSerialResult
    | ModernSerialResult
    | { type: "unknown"; message: string }
    | { type: "error"; message: string };

// ── Vintage decoder ───────────────────────────────────────────────────────────

const knownFactories: Record<string, string> = {
    F: "Fremont, California, USA",
    C: "Cork, Ireland",
    CK: "Cork, Ireland",
};

// Vintage model codes. Mirrors vintage_model_codes.swift exactly.
const vintageModelCodes: Record<string, string | null> = {
    // Mac 128K / 512K / Plus
    "M0001": "Macintosh 128K",
    "M0001P": "Macintosh 128K / 512K",
    "M0001W": "Macintosh 512K",
    "M0001WP": "Macintosh 512Ke",
    "0001WP": "Macintosh 512Ke",
    "M0001ED": "Macintosh 512Ke",
    "M0001A": "Macintosh Plus",
    "M0001AP": "Macintosh Plus (European)",
    "M0420": "Macintosh Classic",
    "M0421": "Macintosh Classic",
    "M0422": "Macintosh Classic, Revision A",
    // SE / SE FDHD
    "M5010": "Macintosh SE",
    "M5011": "Macintosh SE FDHD",
    "M5910X": "Macintosh SE",
    "B01": "Macintosh SE FDHD",
    "B02": "Macintosh SE FDHD",
    "B03": "Macintosh SE FDHD",
    "B47": "20th Anniversary Macintosh",
    // SE/30
    "M5119": "Macintosh SE/30",
    "M5390": "Macintosh SE/30",
    "M5392": "Macintosh SE/30",
    "K01": "Macintosh SE/30",
    "K02": "Macintosh SE/30",
    "KA1": "Macintosh SE/30",
    "KH1": "Macintosh SE/30",
    "KAT": "Macintosh SE/30",
    "AK02": "Macintosh SE/30",
    // Mac II family
    "M5030": "Macintosh II",
    "M5404": "Macintosh II",
    "M5880": "Macintosh Plus",
    "M5880X": "Macintosh Plus",
    "C40": "Macintosh IIfx",
    "3B1": "Macintosh IIvi",
    "3BF": "Macintosh IIvx",
    // Classic / Classic II
    "D04": "Macintosh Classic",
    "D10": "Macintosh Classic",
    "D11": "Macintosh Classic",
    "V23": "Macintosh Classic",
    "D22": "Macintosh Classic II",
    "D23": "Macintosh Classic II",
    "D24": "Macintosh Classic II",
    "M1542": "Macintosh Classic II",
    "D39": "Macintosh Performa 200",
    // LC / LC III / Performa
    "L02": "Macintosh LC",
    "L13": "Macintosh LC",
    "1PT": "Macintosh LC (Performa)",
    "CF07": "Macintosh LC II",
    "VA1": "Macintosh LC III",
    "VA2": "Macintosh LC III",
    "L0Y": "Macintosh Performa 450",
    "10Y": "Macintosh Performa 450",
    // Quadra / Centris
    "1XS": "Macintosh Quadra 610",
    "2D9": "Macintosh Quadra 650",
    "1M1": "Macintosh Quadra 650",
    "1LZ": "Macintosh Quadra 650",
    "CC2": "Macintosh Quadra 650",
    "CC5": "Macintosh Centris 650",
    "C82": "Macintosh Quadra 700",
    "CC7": "Macintosh Quadra 800",
    "20C": "Macintosh Quadra 660 AV",
    // Portable / PowerBook
    "DM59": "Macintosh Portable",
    "M61": "Macintosh Portable (BackLit)",
    "11P": "PowerBook Duo 270c",
    "15E": "PowerBook 165",
    "492": "PowerBook 160c",
    "4ZP": "PowerBook 190cs",
    // PowerMac
    "41Y": "Power Macintosh 6100/60",
    "44H": "Power Macintosh 7100/80",
    "G20": "Macintosh TV",
    "M3459": "20th Anniversary Macintosh",
    "M3548": "Power Macintosh 6500/225",
    "9CL": "Power Macintosh 6500/225",
    // Apple IIgs
    "A2S6000": "Apple IIgs (ROM 01)",
    "A2S6001": "Apple IIgs (ROM 3)",
    // Unresolved
    "DZ4": null,
};

function normalize(input: string): string {
    return input.toUpperCase().replace(/[^A-Z0-9]/g, "");
}

function tryDecodeVintage(normalized: string): VintageSerialResult | null {
    if (normalized.length < 8) return null;

    let pos = 0;
    const warnings: string[] = [];

    // Factory code (1 or 2 chars)
    let factoryCode: string;
    if (normalized.startsWith("CK")) {
        factoryCode = "CK";
        pos = 2;
    } else {
        factoryCode = normalized[0];
        pos = 1;
    }
    const factory = knownFactories[factoryCode];
    if (!factory) {
        warnings.push(`Unknown factory code '${factoryCode}' — location not in lookup table.`);
    }

    // Year char — must be a digit for vintage format
    const yearChar = normalized[pos];
    if (!/^\d$/.test(yearChar)) return null;
    const year = 1980 + parseInt(yearChar, 10);
    pos++;
    if (year >= 1989) {
        warnings.push("Serials from 1989 onward may use a changed Apple serial format; old-style decoding may be ambiguous.");
    }

    // Week (2 digits)
    if (pos + 2 > normalized.length) return null;
    const weekStr = normalized.slice(pos, pos + 2);
    if (!/^\d{2}$/.test(weekStr)) return null;
    const week = parseInt(weekStr, 10);
    pos += 2;
    if (week < 1 || week > 53) {
        warnings.push(`Week ${week} is outside valid range 1–53.`);
    }

    // Production code (3 base-34 chars)
    if (pos + 3 > normalized.length) return null;
    pos += 3;

    // Model code — everything remaining
    const modelCode = normalized.slice(pos);
    const modelName = vintageModelCodes[modelCode] ?? undefined;

    return {
        type: "vintage",
        serial: normalized,
        factoryCode,
        factory,
        year,
        week,
        modelCode,
        modelName: modelName === null ? undefined : modelName,
        warnings,
    };
}

// ── Modern decoder ────────────────────────────────────────────────────────────

function lookupModern(configCode: string): { identifier?: string; name?: string } {
    const entry = modernModelCodes[configCode];
    if (!entry) return {};
    return { identifier: entry[0] || undefined, name: entry[1] || undefined };
}

function decode11(normalized: string): ModernSerialResult {
    const configCode = normalized.slice(-3);
    const factoryCode = normalized.slice(0, 2);
    const { identifier, name } = lookupModern(configCode);
    const warnings: string[] = [];
    if (!identifier && !name) {
        warnings.push(`Config code '${configCode}' not found in modern model database.`);
    }
    return {
        type: "modern",
        serial: normalized,
        format: "11-char (1989–2010)",
        factoryCode,
        configCode,
        modelIdentifier: identifier,
        modelName: name,
        warnings,
    };
}

function decode12(normalized: string): ModernSerialResult {
    const configCode = normalized.slice(-4);
    const factoryCode = normalized.slice(0, 2);
    const { identifier, name } = lookupModern(configCode);
    const warnings: string[] = [];
    if (!identifier && !name) {
        warnings.push(
            `Config code '${configCode}' not found in modern model database. ` +
            `This may be a post-April 2021 serial, which is cryptographically randomized and cannot be decoded.`
        );
    }
    return {
        type: "modern",
        serial: normalized,
        format: "12-char (2010–2021)",
        factoryCode,
        configCode,
        modelIdentifier: identifier,
        modelName: name,
        warnings,
    };
}

// ── Top-level dispatcher ──────────────────────────────────────────────────────

function tryDecodeModern(normalized: string): ModernSerialResult | null {
    switch (normalized.length) {
        case 11: return decode11(normalized);
        case 12: return decode12(normalized);
        default: return null;
    }
}

export function decodeAppleSerial(input: string): SerialDecodeResult {
    const normalized = normalize(input);

    if (normalized.length < 8) {
        return { type: "error", message: "Serial too short (minimum 8 characters after normalization)." };
    }

    const vintage = tryDecodeVintage(normalized);
    const modern = tryDecodeModern(normalized);

    if (vintage && modern) {
        // Both matched — pick the more specific result (modern wins on tie)
        if (vintage.modelName && !modern.modelName) return vintage;
        if (!vintage.modelName && modern.modelName) return modern;
        if (vintage.modelName && modern.modelName) return modern;
        return vintage; // neither has a name — prefer vintage metadata
    }
    if (vintage) return vintage;
    if (modern) return modern;

    return { type: "unknown", message: `Serial length ${normalized.length} does not match any known Apple format.` };
}

// Convenience: return just the model name (or undefined if not identified).
export function decodeSerialModelName(input: string): string | undefined {
    const result = decodeAppleSerial(input);
    if (result.type === "vintage" || result.type === "modern") {
        return result.modelName;
    }
    return undefined;
}
