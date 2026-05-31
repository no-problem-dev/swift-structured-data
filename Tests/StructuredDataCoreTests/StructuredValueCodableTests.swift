import Foundation
import Testing
@testable import StructuredDataCore

/// `StructuredValue` must round-trip through Foundation's coders so it can stand
/// in for ad-hoc `JSONValue` enums used as Codable pass-through payloads.
struct StructuredValueCodableTests {
    @Test
    func roundTripsThroughFoundationCoders() throws {
        let value: StructuredValue = [
            "name": "tool_use",
            "count": 3,
            "ratio": 1.5,
            "active": true,
            "tags": ["a", "b"],
            "nested": ["x": .null],
        ]
        let data = try Foundation.JSONEncoder().encode(value)
        let decoded = try Foundation.JSONDecoder().decode(StructuredValue.self, from: data)
        #expect(decoded == value)
    }

    @Test
    func embedsInOtherCodableTypes() throws {
        struct Envelope: Codable, Equatable {
            var id: String
            var input: StructuredValue
        }
        let envelope = Envelope(id: "1", input: ["city": "Tokyo", "days": 5])
        let data = try Foundation.JSONEncoder().encode(envelope)
        let decoded = try Foundation.JSONDecoder().decode(Envelope.self, from: data)
        #expect(decoded == envelope)
        #expect(decoded.input.city.string == "Tokyo")
    }

}
