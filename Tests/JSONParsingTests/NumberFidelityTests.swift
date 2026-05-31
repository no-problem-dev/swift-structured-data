import Foundation
import Testing
import StructuredDataCore
@testable import JSONParsing

/// Regression table for the Foundation `JSONDecoder` number defects that
/// motivate this library (swift-foundation #613/#812, SR-7054/SR-6440). The
/// raw-text number model must read each of these losslessly and without crashing.
struct NumberFidelityTests {
    private let parser = JSONParser()

    @Test
    func preservesInt64BoundaryWithoutSilentClamp() throws {
        let belowMin = try parser.parse("-9223372036854775809").numberValue
        #expect(belowMin?.int64 == nil)
        #expect(belowMin?.text == "-9223372036854775809")
    }

    @Test
    func exactIntegersAroundTwoToFiftyThree() throws {
        #expect(try parser.parse("9007199254740991").numberValue?.int64 == 9007199254740991)
        #expect(try parser.parse("9007199254740993").numberValue?.int64 == 9007199254740993)
    }

    @Test
    func hugeExponentParsesWithoutCrash() throws {
        let value = try parser.parse("1147e02864").numberValue
        #expect(value?.text == "1147e02864")
        #expect(value?.double == .infinity)
    }

    @Test
    func overflowingMagnitudeYieldsInfinityNotError() throws {
        #expect(try parser.parse("1e400").numberValue?.double == .infinity)
    }

    @Test
    func decimalKeepsMorePrecisionThanDouble() throws {
        let number = try parser.parse("46.984765").numberValue
        #expect(number?.decimal == Decimal(string: "46.984765"))
        #expect(number?.text == "46.984765")
    }
}
