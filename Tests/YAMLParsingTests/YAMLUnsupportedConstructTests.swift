import Foundation
import Testing
import StructuredDataCore
@testable import YAMLParsing

/// The constructs this parser does not implement, and the guarantee that it says so.
///
/// Each case here used to parse. Not fail — parse, into a value the document does not contain:
/// `!!str 42` into the number 42, an alias into null, an explicit key into a scalar. A reader that
/// answers a question it cannot answer is worse than one that refuses, because the caller has no
/// way to notice. These tests exist to keep the refusal.
struct YAMLUnsupportedConstructTests {
    private let parser = YAMLParser()

    private func kind(of error: any Error) -> ParseError.Kind? {
        (error as? ParseError)?.kind
    }

    // MARK: - Tags

    @Test("タグは無視されず拒否される（!!str 42 が数値 42 にならない）")
    func rejectsTags() throws {
        let error = try #require(throws: ParseError.self) {
            try parser.parse("value: !!str 42")
        }
        #expect(kind(of: error) == .unsupportedConstruct("tag '!!str'"))
    }

    @Test("独自タグも拒否される")
    func rejectsCustomTags() {
        #expect(throws: ParseError.self) { try parser.parse("value: !myType foo") }
        #expect(throws: ParseError.self) { try parser.parse("value: !<tag:example.com,2000:x> foo") }
    }

    // MARK: - Anchors and aliases

    @Test("アンカーは拒否される")
    func rejectsAnchors() throws {
        let error = try #require(throws: ParseError.self) {
            try parser.parse("base: &defaults 1")
        }
        #expect(kind(of: error) == .unsupportedConstruct("anchor '&defaults'"))
    }

    /// The one that hurt most: an alias is a reference to a value stated elsewhere in the same
    /// document, and null is not that value.
    @Test("エイリアスは null にならず拒否される")
    func rejectsAliases() throws {
        let error = try #require(throws: ParseError.self) {
            try parser.parse("copy: *defaults")
        }
        #expect(kind(of: error) == .unsupportedConstruct("alias '*defaults'"))
    }

    @Test("マージキー（<<: *base）も拒否される")
    func rejectsMergeKeys() {
        #expect(throws: ParseError.self) {
            try parser.parse("""
            defaults:
              retries: 3
            service:
              <<: *defaults
              name: api
            """)
        }
    }

    @Test("シーケンス要素の中のエイリアスも拒否される")
    func rejectsAliasInSequenceEntry() {
        #expect(throws: ParseError.self) {
            try parser.parse("""
            items:
              - *first
              - second
            """)
        }
    }

    @Test("キーに書かれたエイリアスも拒否される")
    func rejectsAliasUsedAsKey() {
        #expect(throws: ParseError.self) { try parser.parse("*key: value") }
    }

    @Test("フロー記法の中のエイリアス・タグ・アンカーも拒否される")
    func rejectsPropertiesInFlowContext() {
        #expect(throws: ParseError.self) { try parser.parse("items: [*first, second]") }
        #expect(throws: ParseError.self) { try parser.parse("items: {a: *first}") }
        #expect(throws: ParseError.self) { try parser.parse("items: [!!str 42]") }
        #expect(throws: ParseError.self) { try parser.parse("items: [&anchor 42]") }
    }

    // MARK: - Complex keys

    @Test("明示キー（?）は平文スカラーとして読まれず拒否される")
    func rejectsComplexKeys() throws {
        let error = try #require(throws: ParseError.self) {
            try parser.parse("""
            ? [a, b]
            : value
            """)
        }
        #expect(kind(of: error) == .unsupportedConstruct("explicit key '?'"))
    }

    @Test("マッピングの途中に現れた明示キーも拒否される")
    func rejectsComplexKeyAfterAnEntry() {
        #expect(throws: ParseError.self) {
            try parser.parse("""
            first: 1
            ? [a, b]
            : value
            """)
        }
    }

    // MARK: - Directives

    @Test("%TAG ディレクティブは拒否される")
    func rejectsTagDirective() throws {
        let error = try #require(throws: ParseError.self) {
            try parser.parse("%TAG !e! tag:example.com,2000:\n---\na: 1")
        }
        #expect(kind(of: error) == .unsupportedConstruct("%TAG directive"))
    }

    /// Under 1.1 the Norway problem is back: `no` is a boolean. Reading a 1.1 document with 1.2
    /// Core resolution and saying nothing is how a country code turns into `false`.
    @Test("1.2 以外の %YAML は拒否される")
    func rejectsForeignYAMLVersion() throws {
        let error = try #require(throws: ParseError.self) {
            try parser.parse("%YAML 1.1\n---\ncountry: no")
        }
        #expect(kind(of: error) == .unsupportedConstruct("%YAML directive naming version '1.1'"))
    }

    @Test("%YAML 1.2 は通る（このパーサの解決規則と一致するため）")
    func acceptsMatchingYAMLVersion() throws {
        let value = try parser.parse("%YAML 1.2\n---\ncountry: no")
        #expect(value.country.string == "no")
    }

    // MARK: - What must keep working

    /// The refusals are narrow on purpose: `!`, `&` and `*` cannot begin a plain scalar in YAML,
    /// but they are ordinary characters anywhere else, and quoting settles the matter entirely.
    @Test("記号を含むだけの普通のスカラーは今までどおり読める")
    func ordinaryScalarsAreUnaffected() throws {
        let value = try parser.parse("""
        excited: hello!
        math: 2 * 3
        quoted: "*not-an-alias"
        also: '&not-an-anchor'
        question: what?
        """)
        #expect(value.excited.string == "hello!")
        #expect(value.math.string == "2 * 3")
        #expect(value.quoted.string == "*not-an-alias")
        #expect(value.also.string == "&not-an-anchor")
        #expect(value.question.string == "what?")
    }

    /// The serializer's quoting rule now carries the round-trip. It already quotes any scalar
    /// starting with an indicator character, which is what keeps a string like `*base` from being
    /// written back as an alias — previously that misread as null, and now it would throw, so this
    /// is the test that says the two halves still agree.
    @Test("指示子で始まる文字列も serialize → parse で戻る")
    func serializerKeepsIndicatorStringsReadable() throws {
        let original = StructuredValue.object([
            "alias": .string("*base"),
            "tag": .string("!!str"),
            "anchor": .string("&defaults"),
            "question": .string("? explicit"),
            "directive": .string("%YAML 1.1"),
        ])

        let text = YAMLSerializer().string(from: original)
        #expect(try parser.parse(text) == original)
    }

    @Test("ブロックスカラーの中身は解釈されない")
    func blockScalarContentIsNotInspected() throws {
        let value = try parser.parse("""
        script: |
          echo *glob
          test ! -f x
        """)
        #expect(value.script.string == "echo *glob\ntest ! -f x\n")
    }
}
