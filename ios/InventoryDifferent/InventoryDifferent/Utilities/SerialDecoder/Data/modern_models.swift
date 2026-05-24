// Modern Apple Mac model lookup table.
// Generated from OpenCorePkg Utilities/macserial/modelinfo_autogen.h
// Run scripts/parse_modelinfo.py to regenerate this file from the upstream source.
//
// Key   = config code (last 3 chars of 11-char serial, or last 4 chars of 12-char serial)
// Value = (modelIdentifier, humanReadableName)

typealias ModernModelEntry = (identifier: String, name: String)

let modernModelCodes: [String: ModernModelEntry] = [
    // This table is populated by parse_modelinfo.py from OpenCorePkg modelinfo_autogen.h.
    // Placeholder entries to verify the lookup path works end-to-end:
    "HH27": ("MacBook10,1",     "MacBook (12-inch, 2017)"),
    "HH25": ("MacBook10,1",     "MacBook (12-inch, 2017)"),
    "J9XD": ("MacBook10,1",     "MacBook (12-inch, 2017)"),
    "9VN":  ("MacBook1,1",      "MacBook (13-inch, Late 2006)"),
    "U9B":  ("MacBook1,1",      "MacBook (13-inch, Late 2006)"),
    "18X":  ("MacBookAir1,1",   "MacBook Air (Original, Early 2008)"),
    "9G6":  ("Macmini4,1",      "Mac mini (Mid 2010)"),
    "F9VN": ("MacPro6,1",       "Mac Pro (Late 2013)"),
]

func lookupModernModel(_ configCode: String) -> (String?, String?) {
    guard let entry = modernModelCodes[configCode] else {
        return (nil, nil)
    }
    return (entry.identifier, entry.name)
}
