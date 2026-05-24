// Vintage Apple serial number model code lookup table.
// Sources: user inventory (confirmed), myoldmac.net decoder v1.1/v1.2, known Apple product numbers.

let vintageModelCodes: [String: String?] = [
    // --- Mac 128K / 512K / Plus family ---
    "M0001":    "Macintosh 128K",
    "M0001P":   "Macintosh 128K / 512K",
    "M0001W":   "Macintosh 512K",
    "M0001WP":  "Macintosh 512K (European ED)",  // also "0001WP" below
    "0001WP":   "Macintosh 512Ke",
    "M0001ED":  "Macintosh 512Ke",
    "M0001A":   "Macintosh Plus",                 // confirmed: F846FHRM0001A
    "M0001AP":  "Macintosh Plus (European)",
    "M0420":    "Macintosh Classic",
    "M0421":    "Macintosh Classic",
    "M0422":    "Macintosh Classic, Revision A",

    // --- Mac SE / SE FDHD ---
    "M5010":    "Macintosh SE",                   // confirmed: F7385QDM5010, F8149B3M5010
    "M5011":    "Macintosh SE FDHD",              // confirmed: F7180Y9M5011, F80655FM5011
    "M5910X":   "Macintosh SE",
    "B01":      "Macintosh SE FDHD",
    "B02":      "Macintosh SE FDHD",              // confirmed: F9472LNB02
    "B03":      "Macintosh SE FDHD",
    "B47":      "20th Anniversary Macintosh",

    // --- Mac SE/30 ---
    "M5119":    "Macintosh SE/30",               // confirmed: F9058ECM5119 (Apple model# matches)
    "M5390":    "Macintosh SE/30",
    "M5392":    "Macintosh SE/30",               // confirmed: E9460MBM5392
    "K01":      "Macintosh SE/30",               // confirmed: F943F2VK01
    "K02":      "Macintosh SE/30",               // confirmed: F9231K8K02, F929F9KK02
    "KA1":      "Macintosh SE/30",
    "KH1":      "Macintosh SE/30",
    "KAT":      "Macintosh SE/30",
    "AK02":     "Macintosh SE/30",

    // --- Mac II family ---
    "M5030":    "Macintosh II",                  // confirmed: F8050NGM5030, F8406YNM5030
    "M5404":    "Macintosh II",
    "M5880":    "Macintosh Plus",                // myoldmac.net: M5880 = Mac Plus
    "M5880X":   "Macintosh Plus",
    "C40":      "Macintosh IIfx",
    "3B1":      "Macintosh IIvi",
    "3BF":      "Macintosh IIvx",

    // --- Mac Classic / Classic II ---
    "D04":      "Macintosh Classic",
    "D10":      "Macintosh Classic",
    "D11":      "Macintosh Classic",
    "V23":      "Macintosh Classic",
    "D22":      "Macintosh Classic II",
    "D23":      "Macintosh Classic II",
    "D24":      "Macintosh Classic II",
    "M1542":    "Macintosh Classic II",
    "D39":      "Macintosh Performa 200",

    // --- Mac LC / LC III / Performa ---
    "L02":      "Macintosh LC",
    "L13":      "Macintosh LC",
    "1PT":      "Macintosh LC (Performa)",
    "CF07":     "Macintosh LC II",
    "VA1":      "Macintosh LC III",
    "VA2":      "Macintosh LC III",
    "L0Y":      "Macintosh Performa 450",
    "10Y":      "Macintosh Performa 450",

    // --- Quadra / Centris ---
    "1XS":      "Macintosh Quadra 610",
    "2D9":      "Macintosh Quadra 650",
    "1M1":      "Macintosh Quadra 650",
    "1LZ":      "Macintosh Quadra 650",
    "CC2":      "Macintosh Quadra 650",
    "CC5":      "Macintosh Centris 650",
    "C82":      "Macintosh Quadra 700",
    "CC7":      "Macintosh Quadra 800",
    "20C":      "Macintosh Quadra 660 AV",

    // --- Portable / PowerBook ---
    "M61":      "Macintosh Portable (BackLit)",
    "492":      "PowerBook 160c",

    // --- PowerMac ---
    "41Y":      "Power Macintosh 6100/60",
    "44H":      "Power Macintosh 7100/80",
    "G20":      "Macintosh TV",
    "M3459":    "20th Anniversary Macintosh",
    "M3548":    "Power Macintosh 6500/225",
    "9CL":      "Power Macintosh 6500/225",

    // --- Apple IIgs ---
    // Apple II serial model codes ARE the Apple product numbers verbatim
    "A2S6000":  "Apple IIgs (ROM 01)",           // confirmed: E838G8CA2S6000
    "A2S6001":  "Apple IIgs (ROM 3)",

    // --- Unresolved stubs ---
    "DZ4":      nil,
]

func lookupVintageModel(_ code: String) -> String? {
    vintageModelCodes[code] ?? nil
}
