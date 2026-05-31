import Foundation
import Testing
import StructuredDataCore
@testable import YAMLParsing

struct YAMLParserTests {
    private let parser = YAMLParser()

    @Test
    func blockMappingAndSequence() throws {
        let yaml = """
        name: Ada
        roles:
          - admin
          - dev
        active: true
        """
        let value = try parser.parse(yaml)
        #expect(value.name.string == "Ada")
        #expect(value.roles[0].string == "admin")
        #expect(value.roles[1].string == "dev")
        #expect(value.active.bool == true)
    }

    @Test
    func sequenceOfMappingsCompactNotation() throws {
        let yaml = """
        - name: Mark
          hr: 65
        - name: Sammy
          hr: 63
        """
        let value = try parser.parse(yaml)
        #expect(value[0].name.string == "Mark")
        #expect(value[0].hr.int == 65)
        #expect(value[1].name.string == "Sammy")
    }

    @Test
    func norwayProblemIsFixed() throws {
        let value = try parser.parse("country: NO\nflag: no\nlit: on")
        #expect(value.country.string == "NO")
        #expect(value.flag.string == "no")
        #expect(value.lit.string == "on")
    }

    @Test
    func coreSchemaScalars() throws {
        let value = try parser.parse("""
        a: null
        b: ~
        c: true
        d: 42
        e: 0o17
        f: 0xFF
        g: 3.14
        h: hello
        """)
        #expect(value.a.isNull)
        #expect(value.b.isNull)
        #expect(value.c.bool == true)
        #expect(value.d.int == 42)
        #expect(value.e.int == 15)
        #expect(value.f.int == 255)
        #expect(value.g.double == 3.14)
        #expect(value.h.string == "hello")
    }

    @Test
    func flowCollections() throws {
        let value = try parser.parse("nums: [1, 2, 3]\nmap: {x: 1, y: 2}")
        #expect(value.nums[2].int == 3)
        #expect(value.map.x.int == 1)
        #expect(value.map.y.int == 2)
    }

    @Test
    func quotedScalarsAndComments() throws {
        let value = try parser.parse("""
        a: "quoted # not comment"
        b: 'single ''quote'''  # trailing comment
        c: plain  # comment
        """)
        #expect(value.a.string == "quoted # not comment")
        #expect(value.b.string == "single 'quote'")
        #expect(value.c.string == "plain")
    }

    @Test
    func literalBlockScalar() throws {
        let value = try parser.parse("""
        text: |
          line one
          line two
        """)
        #expect(value.text.string == "line one\nline two\n")
    }

    @Test
    func foldedBlockScalar() throws {
        let value = try parser.parse("""
        text: >
          line one
          line two
        """)
        #expect(value.text.string == "line one line two\n")
    }

    @Test
    func multiDocument() throws {
        let docs = try parser.parseAll(Data("---\na: 1\n---\nb: 2\n".utf8))
        #expect(docs.count == 2)
        #expect(docs[0].a.int == 1)
        #expect(docs[1].b.int == 2)
    }

    @Test
    func decodesIntoCodable() throws {
        struct Config: Codable, Equatable { var host: String; var port: Int; var tls: Bool }
        let config = try YAMLDecoder().decode(Config.self, from: "host: example.com\nport: 8080\ntls: true")
        #expect(config == Config(host: "example.com", port: 8080, tls: true))
    }
}
