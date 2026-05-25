// Decodes 1989–2021 Apple serial numbers (11-char and 12-char formats).
// Data sourced from OpenCorePkg modelinfo_autogen.h (121 models, 10,000+ config codes).
// Run scripts/parse_modelinfo.py to regenerate modern_models.swift from the upstream file.
//
// 11-char format (1989–2010): AA B CC DDD EEE
//   AA  = factory (2 chars)
//   B   = year (letter, see yearLetters table)
//   CC  = week (2 digits)
//   DDD = unique identifier
//   EEE = model/config code (last 3 chars)
//
// 12-char format (2010–2021): AA B C D EEE FFFF
//   AA   = factory (2 chars)
//   B    = year (letter)
//   C    = plant-specific
//   D    = week
//   EEE  = unique identifier
//   FFFF = model/config code (last 4 chars)

public struct ModernSerialResult: Codable {
    public let serial: String
    public let format: String
    public let factoryCode: String
    public let configCode: String
    public let modelIdentifier: String?
    public let modelName: String?
    public let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case serial, format, warnings
        case factoryCode = "factory_code"
        case configCode = "config_code"
        case modelIdentifier = "model_identifier"
        case modelName = "model_name"
    }
}

public struct ModernSerialDecoder {

    public static func decode11(_ normalized: String) -> ModernSerialResult {
        let configCode = String(normalized.suffix(3))
        let factoryCode = String(normalized.prefix(2))
        let (modelId, modelName) = lookupModernModel(configCode)
        var warnings: [String] = []
        if modelId == nil && modelName == nil {
            warnings.append("Config code '\(configCode)' not found in modern model database.")
        }
        return ModernSerialResult(
            serial: normalized,
            format: "11-char (1989–2010)",
            factoryCode: factoryCode,
            configCode: configCode,
            modelIdentifier: modelId,
            modelName: modelName,
            warnings: warnings
        )
    }

    public static func decode12(_ normalized: String) -> ModernSerialResult {
        let configCode = String(normalized.suffix(4))
        let factoryCode = String(normalized.prefix(2))
        let (modelId, modelName) = lookupModernModel(configCode)
        var warnings: [String] = []
        if modelId == nil && modelName == nil {
            warnings.append("Config code '\(configCode)' not found in modern model database. This may be a post-April 2021 serial, which is cryptographically randomized and cannot be decoded.")
        }
        return ModernSerialResult(
            serial: normalized,
            format: "12-char (2010–2021)",
            factoryCode: factoryCode,
            configCode: configCode,
            modelIdentifier: modelId,
            modelName: modelName,
            warnings: warnings
        )
    }
}
