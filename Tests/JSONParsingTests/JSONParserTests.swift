import Testing
import StructuredDataCore
@testable import JSONParsing

struct JSONParserTests {
    private let parser = JSONParser()

    @Test
    func parsesTopLevelScalars() throws {
        #expect(try parser.parse("42") == .number(.init(unchecked: "42")))
        #expect(try parser.parse("\"hi\"") == .string("hi"))
        #expect(try parser.parse("true") == .bool(true))
        #expect(try parser.parse("null") == .null)
    }

    @Test
    func parsesNestedStructure() throws {
        let value = try parser.parse(#"{"a":[1,2,{"b":null}],"c":"x"}"#)
        #expect(value.a[2].b.isNull)
        #expect(value.c.string == "x")
        #expect(value.a[0].int == 1)
    }

    @Test
    func preservesObjectOrder() throws {
        let value = try parser.parse(#"{"z":1,"a":2,"m":3}"#)
        #expect(value.objectValue?.keys == ["z", "a", "m"])
    }

    @Test(arguments: ["01", "1.", ".5", "+1", "1e", "1.2.3", "0x1", "Infinity", "NaN"])
    func rejectsInvalidNumbers(_ text: String) {
        #expect(throws: ParseError.self) { try parser.parse(text) }
    }

    @Test(arguments: ["-0", "0", "1E10", "1.5e-3", "9223372036854775808", "1e400"])
    func acceptsValidNumbersIncludingArbitraryPrecision(_ text: String) throws {
        let value = try parser.parse(text)
        #expect(value.numberValue?.text == text)
    }

    @Test
    func rejectsTrailingCommaAndData() {
        #expect(throws: ParseError.self) { try parser.parse("[1,2,]") }
        #expect(throws: ParseError.self) { try parser.parse("{\"a\":1,}") }
        #expect(throws: ParseError.self) { try parser.parse("1 2") }
    }

    @Test
    func handlesStringEscapesAndSurrogatePairs() throws {
        #expect(try parser.parse(#""é""#) == .string("é"))
        #expect(try parser.parse(#""𝄞""#) == .string("𝄞"))
        #expect(try parser.parse(#""tab\there""#) == .string("tab\there"))
    }

    @Test
    func duplicateKeyPolicies() throws {
        let input = #"{"a":1,"a":2}"#
        let last = try JSONParser(options: .init(duplicateKeyPolicy: .lastWins)).parse(input)
        #expect(last.a.int == 2)
        let first = try JSONParser(options: .init(duplicateKeyPolicy: .firstWins)).parse(input)
        #expect(first.a.int == 1)
        #expect(throws: ParseError.self) {
            try JSONParser(options: .strict).parse(input)
        }
    }

    @Test
    func rejectsUnescapedControlCharacter() {
        #expect(throws: ParseError.self) { try parser.parse("\"line\nbreak\"") }
    }
}
