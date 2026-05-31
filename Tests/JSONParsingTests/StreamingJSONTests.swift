import Foundation
import Testing
import StructuredDataCore
@testable import JSONParsing

struct StreamingJSONTests {
    @Test
    func revealsFieldsAsObjectStreams() {
        var parser = StreamingJSONParser()
        parser.consume(#"{"name":"Ad"#)
        #expect(parser.snapshot().name.string == "Ad")

        parser.consume(#"a","age":3"#)
        #expect(parser.snapshot().name.string == "Ada")

        parser.consume("6}")
        #expect(parser.snapshot().age.int == 36)
    }

    @Test
    func dropsTrailingIncompleteToken() {
        var parser = StreamingJSONParser()
        parser.consume(#"{"items":[1,2,3],"flag":tr"#)
        let snapshot = parser.snapshot()
        #expect(snapshot.items[2].int == 3)
        #expect(snapshot.flag.isNull)
    }

    @Test
    func handlesPartialNestedStructures() {
        var parser = StreamingJSONParser()
        parser.consume(#"{"user":{"roles":["admin","de"#)
        let snapshot = parser.snapshot()
        #expect(snapshot.user.roles[0].string == "admin")
        #expect(snapshot.user.roles[1].string == "de")
    }

    @Test
    func snapshotKeyCountIsMonotonic() {
        let full = #"{"a":1,"b":2,"c":3,"d":4}"#
        var parser = StreamingJSONParser()
        var previousCount = 0
        for character in full {
            parser.consume(String(character))
            let count = parser.snapshot().objectValue?.count ?? 0
            #expect(count >= previousCount)
            previousCount = count
        }
        #expect(previousCount == 4)
    }

    @Test
    func finishStrictlyParsesCompleteDocument() throws {
        var parser = StreamingJSONParser()
        parser.consume(#"{"ok":true}"#)
        let value = try parser.finish()
        #expect(value.ok.bool == true)
    }

    @Test
    func finishRejectsIncompleteDocument() {
        var parser = StreamingJSONParser()
        parser.consume(#"{"ok":tr"#)
        #expect(throws: ParseError.self) { try parser.finish() }
    }
}
