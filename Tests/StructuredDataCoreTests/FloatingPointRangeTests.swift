import Foundation
import Testing
@testable import StructuredDataCore

/// Where a floating-point read stops being a rounding and starts being a different number.
///
/// This package's whole argument is that a parser must not lose anything and that the loss happens
/// at the accessor, where it was asked for. Rounding `0.1` is that kind of loss: the double you get
/// is the nearest one to what the document said. Infinity is not — it is not near `1e400`, it is
/// not a quantity at all, and a caller who wrote `var ratio: Double` and got `inf` has no way to
/// tell it from a value that was genuinely enormous.
///
/// The integer side of the same container has always thrown for out-of-range. These tests hold the
/// floating-point side to the same line.
struct FloatingPointRangeTests {
    private struct Measurement: Codable {
        var value: Double
    }

    private struct SmallMeasurement: Codable {
        var value: Float
    }

    private func decode<T: Decodable>(_ type: T.Type, _ value: StructuredValue) throws -> T {
        try value.decode(type)
    }

    // MARK: - Overflow throws

    @Test("Double に収まらない大きさは infinity にならず throw する")
    func doubleOverflowThrows() throws {
        let document = StructuredValue.object(["value": .number(StructuredNumber(unchecked: "1e400"))])
        #expect(throws: DecodingError.self) {
            try decode(Measurement.self, document)
        }
    }

    @Test("負の側も同じ")
    func negativeDoubleOverflowThrows() {
        let document = StructuredValue.object(["value": .number(StructuredNumber(unchecked: "-1e400"))])
        #expect(throws: DecodingError.self) {
            try decode(Measurement.self, document)
        }
    }

    /// `1e300` is an unremarkable `Double` and no `Float` at all, so the same document decodes into
    /// one type and not the other. That is the target type's range talking, which is the point.
    @Test("Double には収まるが Float には収まらない値は Float でだけ throw する")
    func floatOverflowThrows() throws {
        let document = StructuredValue.object(["value": .number(StructuredNumber(unchecked: "1e300"))])
        #expect(try decode(Measurement.self, document).value == 1e300)
        #expect(throws: DecodingError.self) {
            try decode(SmallMeasurement.self, document)
        }
    }

    // MARK: - Rounding still happens

    @Test("丸めは throw しない（0.1 も 1e-400 もそのまま最も近い値になる）")
    func roundingIsNotOverflow() throws {
        let tenth = StructuredValue.object(["value": .number(StructuredNumber(unchecked: "0.1"))])
        #expect(try decode(Measurement.self, tenth).value == 0.1)

        // Underflow has a nearest representable value, and it is zero.
        let tiny = StructuredValue.object(["value": .number(StructuredNumber(unchecked: "1e-400"))])
        #expect(try decode(Measurement.self, tiny).value == 0)

        // Beyond 17 significant digits the tail is gone, silently, as it must be.
        let long = StructuredValue.object([
            "value": .number(StructuredNumber(unchecked: "3.14159265358979311599796346854")),
        ])
        #expect(try decode(Measurement.self, long).value == 3.141592653589793)
    }

    @Test("普通の値は今までどおり読める")
    func ordinaryValuesStillDecode() throws {
        let document = StructuredValue.object(["value": .number(StructuredNumber(unchecked: "1.5e2"))])
        #expect(try decode(Measurement.self, document).value == 150)
        #expect(try decode(SmallMeasurement.self, document).value == 150)
    }

    // MARK: - The accessors underneath

    @Test("緩い double は infinity のまま、exactDouble だけが nil を返す")
    func lenientAccessorIsUnchanged() {
        let huge = StructuredNumber(unchecked: "1e400")
        #expect(huge.double == .infinity)
        #expect(huge.exactDouble == nil)

        let ordinary = StructuredNumber(unchecked: "2.5")
        #expect(ordinary.double == 2.5)
        #expect(ordinary.exactDouble == 2.5)
        #expect(ordinary.exactFloat == 2.5)
    }

    /// Only `init(unchecked:)` can hold this, since no grammar here admits `nan` — but the lenient
    /// accessor turns it into a `Double` all the same, and the exact one refuses.
    @Test("数値でないテキストは exactDouble では nil")
    func textThatIsNotANumber() {
        let broken = StructuredNumber(unchecked: "nan")
        #expect(broken.double.isNaN)
        #expect(broken.exactDouble == nil)
    }
}
