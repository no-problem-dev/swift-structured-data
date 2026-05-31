import Testing
@testable import XMLCoding

struct XMLCodingTests {
    @Test
    func buildsTaggedTree() {
        let element = XMLElement("instructions") {
            XMLElement("role", text: "data analyst")
            XMLElement("example") {
                XMLElement("input", text: "hi")
                XMLElement("output", text: "bye")
            }
        }
        #expect(element.name == "instructions")
        #expect(element.firstElement(named: "role")?.text == "data analyst")
        #expect(element.firstElement(named: "example")?.firstElement(named: "output")?.text == "bye")
    }

    @Test
    func serializesWithEscaping() {
        let element = XMLElement("note", text: "5 < 6 & \"q\"")
        let xml = element.rendered(options: .init(prettyPrinted: false))
        #expect(xml == "<note>5 &lt; 6 &amp; \"q\"</note>")
    }

    @Test
    func escapesAttributes() {
        let element = XMLElement(name: "a", attributes: [XMLAttribute("title", "x < \"y\"")])
        let xml = element.rendered(options: .init(prettyPrinted: false))
        #expect(xml == #"<a title="x &lt; &quot;y&quot;" />"#)
    }

    @Test
    func prettyPrintsNestedElements() {
        let element = XMLElement("root") {
            XMLElement("child", text: "v")
        }
        #expect(element.rendered() == "<root>\n  <child>v</child>\n</root>")
    }

    @Test
    func parsesWellFormedDocument() throws {
        let xml = #"<?xml version="1.0"?><root id="1"><child>text &amp; more</child><empty/></root>"#
        let element = try XMLDocumentParser().parse(xml)
        #expect(element.name == "root")
        #expect(element.attribute("id") == "1")
        #expect(element.firstElement(named: "child")?.text == "text & more")
        #expect(element.firstElement(named: "empty")?.children.isEmpty == true)
    }

    @Test
    func parsesCDATAAndComments() throws {
        let xml = "<root><!-- c --><data><![CDATA[<raw> & ]]></data></root>"
        let element = try XMLDocumentParser().parse(xml)
        #expect(element.firstElement(named: "data")?.text == "<raw> & ")
    }

    @Test
    func roundTripsBuildThenParse() throws {
        let built = XMLElement("p") {
            XMLElement("q", text: "a < b")
        }
        let xml = built.rendered(options: .init(prettyPrinted: false))
        let parsed = try XMLDocumentParser().parse(xml)
        #expect(parsed.firstElement(named: "q")?.text == "a < b")
    }
}
