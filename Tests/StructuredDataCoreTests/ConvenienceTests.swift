import Foundation
import Testing
@testable import StructuredDataCore

struct ConvenienceTests {
    @Test
    func factories() {
        #expect(StructuredValue.int(5) == .number(.init(unchecked: "5")))
        #expect(StructuredValue.double(1.5) == .number(.init(unchecked: "1.5")))
        let object: StructuredValue = ["k": .string("v"), "n": .int(3)]
        #expect(object.n.int == 3)
        #expect(object.k.string == "v")
    }

    @Test
    func anyValueBridgeRoundTrips() {
        let value: StructuredValue = ["a": 1, "b": [true, "x"], "c": .null, "d": 2.5]
        let any = value.anyValue
        #expect((any as? [String: Any])?["a"] as? Int == 1)
        let back = StructuredValue(anyValue: any)
        #expect(back == value)
    }

    @Test
    func anyValueFromFoundationDetectsBool() {
        let value = StructuredValue(anyValue: ["flag": true, "count": 2])
        #expect(value.flag.bool == true)
        #expect(value.count.int == 2)
    }
}
