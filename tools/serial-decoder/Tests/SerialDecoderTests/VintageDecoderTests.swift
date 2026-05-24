import XCTest
@testable import SerialDecoderLib

final class VintageDecoderTests: XCTestCase {

    // MARK: - Core spec example

    func testSpecExample_F9472LNB02() {
        let result = VintageSerialDecoder.decode("F9472LNB02")
        guard case .success(let r) = result else { XCTFail("Expected success"); return }
        XCTAssertEqual(r.serial, "F9472LNB02")
        XCTAssertEqual(r.factoryCode, "F")
        XCTAssertEqual(r.factory, "Fremont, California, USA")
        XCTAssertEqual(r.yearDigit, "9")
        XCTAssertEqual(r.year, 1989)
        XCTAssertEqual(r.week, 47)
        XCTAssertEqual(r.productionCode, "2LN")
        XCTAssertEqual(r.productionNumber, 3014)
        XCTAssertEqual(r.modelCode, "B02")
        XCTAssertEqual(r.modelName, "Macintosh SE FDHD")
        XCTAssert(r.warnings.contains(where: { $0.contains("1989") }))
    }

    // MARK: - Factory codes

    func testFactory_CK() {
        let result = VintageSerialDecoder.decode("CK5221KAM0001W")
        guard case .success(let r) = result else { XCTFail("Expected success"); return }
        XCTAssertEqual(r.factoryCode, "CK")
        XCTAssertEqual(r.factory, "Cork, Ireland")
        XCTAssertEqual(r.year, 1985)
        XCTAssertEqual(r.week, 22)
        XCTAssertEqual(r.modelCode, "M0001W")
        XCTAssertEqual(r.modelName, "Macintosh 512K")
    }

    func testFactory_unknownWarnsDontReject() {
        let result = VintageSerialDecoder.decode("E9460MBM5392")
        guard case .success(let r) = result else { XCTFail("Expected success"); return }
        XCTAssertNil(r.factory)
        XCTAssert(r.warnings.contains(where: { $0.contains("Unknown factory") }))
    }

    // MARK: - Model lookups

    func testModel_Mac128K() {
        let result = VintageSerialDecoder.decode("F441604M0001")
        guard case .success(let r) = result else { XCTFail(); return }
        XCTAssertEqual(r.modelCode, "M0001")
        XCTAssertEqual(r.modelName, "Macintosh 128K")
    }

    func testModel_MacPlus() {
        let result = VintageSerialDecoder.decode("F846FHRM0001A")
        guard case .success(let r) = result else { XCTFail(); return }
        XCTAssertEqual(r.modelCode, "M0001A")
        XCTAssertEqual(r.modelName, "Macintosh Plus")
    }

    func testModel_MacSE() {
        let result = VintageSerialDecoder.decode("F7385QDM5010")
        guard case .success(let r) = result else { XCTFail(); return }
        XCTAssertEqual(r.modelCode, "M5010")
        XCTAssertEqual(r.modelName, "Macintosh SE")
    }

    func testModel_MacSEFDHD() {
        let result = VintageSerialDecoder.decode("F7180Y9M5011")
        guard case .success(let r) = result else { XCTFail(); return }
        XCTAssertEqual(r.modelCode, "M5011")
        XCTAssertEqual(r.modelName, "Macintosh SE FDHD")
    }

    func testModel_MacII() {
        let result = VintageSerialDecoder.decode("F8050NGM5030")
        guard case .success(let r) = result else { XCTFail(); return }
        XCTAssertEqual(r.modelCode, "M5030")
        XCTAssertEqual(r.modelName, "Macintosh II")
    }

    func testModel_MacSE30() {
        let result = VintageSerialDecoder.decode("F9058ECM5119")
        guard case .success(let r) = result else { XCTFail(); return }
        XCTAssertEqual(r.modelCode, "M5119")
        XCTAssertEqual(r.modelName, "Macintosh SE/30")
    }

    func testModel_AppleIIgs() {
        let result = VintageSerialDecoder.decode("E838G8CA2S6000")
        guard case .success(let r) = result else { XCTFail(); return }
        XCTAssertEqual(r.modelCode, "A2S6000")
        XCTAssertEqual(r.modelName, "Apple IIgs (ROM 01)")
    }

    func testModel_unknownReturnsNil() {
        let result = VintageSerialDecoder.decode("F64423SM0001E")
        guard case .success(let r) = result else { XCTFail(); return }
        XCTAssertEqual(r.modelCode, "M0001E")
        XCTAssertNil(r.modelName)
    }

    // MARK: - Base-34 production decode

    func testBase34_2LN_equals_3014() {
        let result = VintageSerialDecoder.decode("F9472LNB02")
        guard case .success(let r) = result else { XCTFail(); return }
        XCTAssertEqual(r.productionNumber, 3014)
    }

    // MARK: - Normalization

    func testNormalizationLowercaseAndDashes() {
        let result = VintageSerialDecoder.decode("f438-1c3-m0001")
        guard case .success(let r) = result else { XCTFail(); return }
        XCTAssertEqual(r.serial, "F4381C3M0001")
        XCTAssertEqual(r.modelCode, "M0001")
    }

    // MARK: - Validation / rejection

    func testReject_tooShort() {
        let result = VintageSerialDecoder.decode("F4381C3")
        guard case .failure(let err) = result else { XCTFail("Expected failure"); return }
        guard case .tooShort = err else { XCTFail("Expected tooShort"); return }
    }

    func testReject_yearNotDigit() {
        // SG prefix: G is not a digit — vintage decoder should reject
        XCTAssertNil(VintageSerialDecoder.tryDecode("SG303054C2C"))
    }

    func testReject_weekNotDigits() {
        let result = VintageSerialDecoder.decode("F9X72LNB02")
        guard case .failure(let err) = result else { XCTFail("Expected failure"); return }
        guard case .weekNotDigits = err else { XCTFail("Expected weekNotDigits, got \(err)"); return }
    }

    // MARK: - Dispatcher routing

    func testDispatcher_routesVintageCorrectly() {
        let result = AppleSerialDecoder.decode("F9472LNB02")
        guard case .vintage = result else { XCTFail("Expected vintage route"); return }
    }

    func testDispatcher_routesModern11Correctly() {
        let result = AppleSerialDecoder.decode("SG303054C2C")
        guard case .modern = result else { XCTFail("Expected modern route"); return }
    }

    func testDispatcher_routesModern12Correctly() {
        let result = AppleSerialDecoder.decode("SYM9363YW9G6")
        guard case .modern = result else { XCTFail("Expected modern route"); return }
    }

    func testDispatcher_rejectsTooShort() {
        let result = AppleSerialDecoder.decode("F4381C3")
        guard case .error = result else { XCTFail("Expected error"); return }
    }
}
