// Top-level dispatcher. Routes a serial number to the correct decoder based on
// format detection: vintage serials have a digit at the year position; modern serials
// have a letter there, so VintageSerialDecoder.tryDecode naturally rejects them.

public enum SerialDecodeResult: Codable {
    case vintage(VintageSerialResult)
    case modern(ModernSerialResult)
    case unknown(String)
    case error(String)

    private enum CodingKeys: String, CodingKey {
        case type, vintage, modern, message
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .vintage(let r):
            try container.encode("vintage", forKey: .type)
            try container.encode(r, forKey: .vintage)
        case .modern(let r):
            try container.encode("modern", forKey: .type)
            try container.encode(r, forKey: .modern)
        case .unknown(let msg):
            try container.encode("unknown", forKey: .type)
            try container.encode(msg, forKey: .message)
        case .error(let msg):
            try container.encode("error", forKey: .type)
            try container.encode(msg, forKey: .message)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "vintage": self = .vintage(try container.decode(VintageSerialResult.self, forKey: .vintage))
        case "modern":  self = .modern(try container.decode(ModernSerialResult.self, forKey: .modern))
        case "error":   self = .error(try container.decode(String.self, forKey: .message))
        default:        self = .unknown(try container.decode(String.self, forKey: .message))
        }
    }
}

public struct AppleSerialDecoder {

    public static func decode(_ input: String) -> SerialDecodeResult {
        let normalized = VintageSerialDecoder.normalize(input)

        guard normalized.count >= 8 else {
            return .error("Serial too short (minimum 8 characters after normalization).")
        }

        // Try vintage first. Returns nil only when year char is non-digit,
        // which is the reliable signal that this is a modern-format serial.
        if let result = VintageSerialDecoder.tryDecode(normalized) {
            return .vintage(result)
        }

        // Modern formats identified by length after vintage decode failed.
        switch normalized.count {
        case 11:
            return .modern(ModernSerialDecoder.decode11(normalized))
        case 12:
            return .modern(ModernSerialDecoder.decode12(normalized))
        default:
            return .unknown("Serial length \(normalized.count) does not match any known Apple format.")
        }
    }
}
