// Decodes pre-1989-style Apple Mac serial numbers.
// Format: [factory][year][week][production(3)][model_code]
// Sources: myoldmac.net decoder, MacRumors serial format thread, user inventory confirmation.

public struct VintageSerialResult: Codable {
    public let serial: String
    public let factoryCode: String
    public let factory: String?
    public let yearDigit: String
    public let year: Int
    public let week: Int
    public let productionCode: String
    public let productionNumber: Int
    public let modelCode: String
    public let modelName: String?
    public let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case serial, factory, year, week, warnings
        case factoryCode = "factory_code"
        case yearDigit = "year_digit"
        case productionCode = "production_code"
        case productionNumber = "production_number"
        case modelCode = "model_code"
        case modelName = "model_name"
    }
}

// Base-34 alphabet (digits 0-9 + uppercase A-Z, excluding I and O)
private let base34Alphabet = Array("0123456789ABCDEFGHJKLMNPQRSTUVWXYZ")

private func base34Index(of char: Character) -> Int? {
    base34Alphabet.firstIndex(of: char)
}

private func decodeBase34(_ code: String) -> Int? {
    var total = 0
    for char in code {
        guard let index = base34Index(of: char) else { return nil }
        total = total * 34 + index
    }
    return total
}

private let knownFactories: [String: String] = [
    "F":  "Fremont, California, USA",
    "C":  "Cork, Ireland",
    "CK": "Cork, Ireland",
]

public enum VintageDecodeError: Error {
    case tooShort
    case yearNotDigit
    case weekNotDigits
    case invalidProductionCode
}

public enum VintageDecodeResult {
    case success(VintageSerialResult)
    case failure(VintageDecodeError)
}

public struct VintageSerialDecoder {

    /// Attempts to decode a serial as vintage format.
    /// Returns nil if the serial clearly isn't vintage format (year char is non-digit),
    /// allowing the dispatcher to fall through to a modern decoder.
    public static func tryDecode(_ normalized: String) -> VintageSerialResult? {
        switch decode(normalized) {
        case .success(let result): return result
        case .failure(let err):
            // Only fall through to modern decoder on yearNotDigit.
            // Other errors (tooShort, weekNotDigits, invalidProductionCode) mean
            // the serial looked vintage but was malformed — surface those to the caller.
            if case .yearNotDigit = err { return nil }
            return nil
        }
    }

    /// Full decode attempt. Returns a result or a typed error.
    public static func decode(_ input: String) -> VintageDecodeResult {
        let normalized = normalize(input)
        var pos = normalized.startIndex
        var warnings: [String] = []

        // Minimum: factory(1) + year(1) + week(2) + production(3) + model(1) = 8 chars
        guard normalized.count >= 8 else {
            return .failure(.tooShort)
        }

        // Factory code
        let factoryCode: String
        if normalized.hasPrefix("CK") {
            factoryCode = "CK"
            pos = normalized.index(pos, offsetBy: 2)
        } else {
            factoryCode = String(normalized[pos])
            pos = normalized.index(after: pos)
        }

        let factory = knownFactories[factoryCode]
        if factory == nil {
            warnings.append("Unknown factory code '\(factoryCode)' — location not in lookup table.")
        }

        // Year
        let yearChar = normalized[pos]
        guard yearChar.isNumber, let yearDigit = yearChar.wholeNumberValue else {
            return .failure(.yearNotDigit)
        }
        pos = normalized.index(after: pos)
        let year = 1980 + yearDigit
        if year >= 1989 {
            warnings.append("Serials from 1989 onward may use a changed Apple serial format; old-style decoding may be ambiguous.")
        }

        // Week (2 chars)
        guard normalized.index(pos, offsetBy: 2, limitedBy: normalized.endIndex) != nil else {
            return .failure(.tooShort)
        }
        let weekStr = String(normalized[pos ..< normalized.index(pos, offsetBy: 2)])
        guard weekStr.allSatisfy({ $0.isNumber }), let week = Int(weekStr) else {
            return .failure(.weekNotDigits)
        }
        pos = normalized.index(pos, offsetBy: 2)
        if week < 1 || week > 53 {
            warnings.append("Week \(week) is outside valid range 1–53.")
        }

        // Production code (3 chars, base-34)
        guard normalized.index(pos, offsetBy: 3, limitedBy: normalized.endIndex) != nil else {
            return .failure(.tooShort)
        }
        let productionCode = String(normalized[pos ..< normalized.index(pos, offsetBy: 3)])
        guard let productionNumber = decodeBase34(productionCode) else {
            return .failure(.invalidProductionCode)
        }
        pos = normalized.index(pos, offsetBy: 3)

        // Model code — everything remaining
        let modelCode = String(normalized[pos...])
        if modelCode.isEmpty {
            warnings.append("No model code found after production code.")
        }

        let modelName: String? = modelCode.isEmpty ? nil : lookupVintageModel(modelCode) ?? nil

        return .success(VintageSerialResult(
            serial: normalized,
            factoryCode: factoryCode,
            factory: factory,
            yearDigit: String(yearChar),
            year: year,
            week: week,
            productionCode: productionCode,
            productionNumber: productionNumber,
            modelCode: modelCode,
            modelName: modelName,
            warnings: warnings
        ))
    }

    public static func normalize(_ input: String) -> String {
        input
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}
