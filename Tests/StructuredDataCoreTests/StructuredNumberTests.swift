import Testing
@testable import StructuredDataCore

struct StructuredNumberTests {
    @Test
    func preservesArbitraryPrecisionText() {
        let big = StructuredNumber(unchecked: "9223372036854775808")
        #expect(big.int64 == nil)
        #expect(big.text == "9223372036854775808")
        #expect(big.uint64 == 9223372036854775808)
    }

    @Test(arguments: [
        ("1", "1.0"), ("1", "1e0"), ("100", "1e2"), ("1", "100e-2"),
        ("0", "-0"), ("0.0", "0"), ("12000", "1.2e4"), ("-5", "-5.00"),
    ])
    func numericEquality(_ pair: (String, String)) {
        #expect(StructuredNumber(unchecked: pair.0) == StructuredNumber(unchecked: pair.1))
    }

    @Test(arguments: [("1", "2"), ("1", "10"), ("1.5", "1.6"), ("-1", "1")])
    func numericInequality(_ pair: (String, String)) {
        #expect(StructuredNumber(unchecked: pair.0) != StructuredNumber(unchecked: pair.1))
    }

    @Test
    func validation() {
        #expect(StructuredNumber(validating: "1.5e10") != nil)
        #expect(StructuredNumber(validating: "01") == nil)
        #expect(StructuredNumber(validating: "1.") == nil)
        #expect(StructuredNumber(validating: ".5") == nil)
        #expect(StructuredNumber(validating: "+1") == nil)
        #expect(StructuredNumber(validating: "1e") == nil)
    }
}
