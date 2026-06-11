import Foundation
import Testing
import StructuredDataCore
@testable import YAMLParsing

@Suite("YAMLSerializer")
struct YAMLSerializerTests {
    private let serializer = YAMLSerializer()
    private let parser = YAMLParser()

    /// The core guarantee: parse ∘ serialize is identity over the Core subset.
    private func roundTrips(_ value: StructuredValue, _ comment: Comment? = nil) throws {
        let text = serializer.string(from: value)
        let reparsed = try parser.parse(text)
        #expect(reparsed == value, "round-trip failed for emitted:\n\(text)")
    }

    // MARK: - Scalars

    @Test("scalar roots round-trip")
    func scalarRoots() throws {
        try roundTrips(.null)
        try roundTrips(.bool(true))
        try roundTrips(.bool(false))
        try roundTrips(.number(StructuredNumber(unchecked: "42")))
        try roundTrips(.number(StructuredNumber(unchecked: "-3.14")))
        try roundTrips(.string("plain"))
    }

    @Test("strings that look like other types are quoted to stay strings")
    func ambiguousStringsQuoted() throws {
        // The critical metadata case: version "1.0" must remain a string.
        try roundTrips(.string("1.0"))
        try roundTrips(.string("42"))
        try roundTrips(.string("true"))
        try roundTrips(.string("false"))
        try roundTrips(.string("null"))
        try roundTrips(.string("~"))
        try roundTrips(.string(""))
        try roundTrips(.string("0x1F"))
    }

    @Test("strings with structural characters are quoted")
    func structuralStringsQuoted() throws {
        try roundTrips(.string("a: b"))         // colon-space
        try roundTrips(.string("trailing:"))
        try roundTrips(.string("- item"))        // leading indicator
        try roundTrips(.string("#hash"))
        try roundTrips(.string("has # comment"))
        try roundTrips(.string("[bracket"))
        try roundTrips(.string("{brace"))
        try roundTrips(.string("\"quote\""))
        try roundTrips(.string("'apostrophe'"))
        try roundTrips(.string("  leading space"))
        try roundTrips(.string("trailing space  "))
        try roundTrips(.string("line1\nline2"))  // newline → escaped in dquotes
        try roundTrips(.string("tab\there"))
        try roundTrips(.string("back\\slash"))
        try roundTrips(.string("|pipe"))
        try roundTrips(.string(">fold"))
    }

    @Test("unicode strings emit plain")
    func unicodeStrings() throws {
        try roundTrips(.string("技能 describe"))
        try roundTrips(.string("café"))
    }

    // MARK: - Collections

    @Test("empty collections use flow form")
    func emptyCollections() throws {
        #expect(serializer.string(from: .array([])) == "[]\n")
        #expect(serializer.string(from: .object(OrderedObject())) == "{}\n")
        try roundTrips(.array([]))
        try roundTrips(.object(OrderedObject()))
    }

    @Test("flat mapping round-trips and preserves key order")
    func flatMapping() throws {
        let obj = StructuredValue.object(OrderedObject([
            ("name", .string("pdf")),
            ("description", .string("Handle PDFs: extract, split")),
            ("count", .number(StructuredNumber(unchecked: "3"))),
            ("enabled", .bool(true)),
        ]))
        try roundTrips(obj)
        let text = serializer.string(from: obj)
        #expect(text.hasPrefix("name: pdf\n"))
    }

    @Test("nested mapping round-trips")
    func nestedMapping() throws {
        let obj = StructuredValue.object(OrderedObject([
            ("metadata", .object(OrderedObject([
                ("version", .string("1.0")),
                ("author", .string("ada")),
            ]))),
            ("name", .string("x")),
        ]))
        try roundTrips(obj)
    }

    @Test("sequences round-trip, scalar and nested")
    func sequences() throws {
        try roundTrips(.array([.string("a"), .string("b"), .number(StructuredNumber(unchecked: "1"))]))
        let nested = StructuredValue.object(OrderedObject([
            ("roles", .array([.string("admin"), .string("dev")])),
            ("matrix", .array([
                .array([.number(StructuredNumber(unchecked: "1")), .number(StructuredNumber(unchecked: "2"))]),
                .array([.number(StructuredNumber(unchecked: "3"))]),
            ])),
            ("people", .array([
                .object(OrderedObject([("name", .string("Mark")), ("hr", .number(StructuredNumber(unchecked: "65")))])),
                .object(OrderedObject([("name", .string("Sammy"))])),
            ])),
        ]))
        try roundTrips(nested)
    }

    // MARK: - SKILL.md frontmatter shape

    @Test("skill frontmatter shape round-trips with string-typed metadata")
    func skillFrontmatter() throws {
        let frontmatter = StructuredValue.object(OrderedObject([
            ("name", .string("deep-research")),
            ("description", .string("Run a multi-source investigation. Use when: thorough, cited research is needed.")),
            ("license", .string("Apache-2.0")),
            ("allowed-tools", .string("Bash(git:*) Read")),
            ("metadata", .object(OrderedObject([
                ("version", .string("1.0")),
                ("author", .string("no-problem")),
            ]))),
        ]))
        try roundTrips(frontmatter)
        // metadata.version must survive as the string "1.0", not the number 1.0.
        let reparsed = try parser.parse(serializer.string(from: frontmatter))
        #expect(reparsed.metadata.version.string == "1.0")
    }

    @Test("sortKeys orders mapping keys")
    func sortKeys() throws {
        let s = YAMLSerializer(options: .init(sortKeys: true))
        let obj = StructuredValue.object(OrderedObject([
            ("b", .string("2")), ("a", .string("1")), ("c", .string("3")),
        ]))
        let text = s.string(from: obj)
        #expect(text == "a: \"1\"\nb: \"2\"\nc: \"3\"\n")
    }
}
