import Foundation
import Testing
@testable import StructuredDataCore

struct DateCodingTests {
    private struct Event: Codable, Equatable {
        var name: String
        var at: Date
        var history: [Date]
    }

    private let whole = Date(timeIntervalSince1970: 1_700_000_000) // whole seconds

    @Test
    func deferredToDateIsDefaultAndUnchanged() throws {
        let value = try StructuredValue.encoding(whole)
        // Default strategy keeps Date's standard Double encoding.
        #expect(value.numberValue != nil)
        let back = try value.decode(Date.self)
        #expect(back == whole)
    }

    @Test(arguments: [
        DateCodingStrategy.iso8601,
        .iso8601WithFractional,
        .secondsSince1970,
        .millisecondsSince1970,
        .llmAPIDefault,
    ])
    func roundTripsWholeSeconds(_ strategy: DateCodingStrategy) throws {
        let enc = EncodingOptions(dateStrategy: strategy)
        let dec = DecodingOptions(dateStrategy: strategy)
        let value = try StructuredValue.encoding(whole, options: enc)
        let back = try value.decode(Date.self, options: dec)
        #expect(abs(back.timeIntervalSince1970 - whole.timeIntervalSince1970) < 0.001)
    }

    @Test
    func iso8601EncodesString() throws {
        let value = try StructuredValue.encoding(whole, options: .init(dateStrategy: .iso8601))
        #expect(value.stringValue == "2023-11-14T22:13:20Z")
    }

    @Test
    func llmAPIDefaultDecodesMultipleFormats() throws {
        let options = DecodingOptions(dateStrategy: .llmAPIDefault)
        #expect((try StructuredValue.string("2024-01-02T03:04:05Z").decode(Date.self, options: options)) != nil)
        #expect((try StructuredValue.string("2024-01-02T03:04:05.123Z").decode(Date.self, options: options)) != nil)
        let dateOnly = try StructuredValue.string("2024-01-15").decode(Date.self, options: options)
        #expect(dateOnly == Date(timeIntervalSince1970: 1_705_276_800)) // 2024-01-15T00:00:00Z
    }

    @Test
    func nestedDatesInKeyedAndUnkeyedContainers() throws {
        let options = (EncodingOptions(dateStrategy: .iso8601), DecodingOptions(dateStrategy: .iso8601))
        let event = Event(name: "launch", at: whole, history: [whole, whole])
        let value = try StructuredValue.encoding(event, options: options.0)
        #expect(value.at.string == "2023-11-14T22:13:20Z")
        #expect(value.history[0].string == "2023-11-14T22:13:20Z")
        let back = try value.decode(Event.self, options: options.1)
        #expect(back == event)
    }

    @Test
    func badDateThrows() {
        let options = DecodingOptions(dateStrategy: .iso8601)
        #expect(throws: DecodingError.self) {
            try StructuredValue.string("not a date").decode(Date.self, options: options)
        }
    }
}
