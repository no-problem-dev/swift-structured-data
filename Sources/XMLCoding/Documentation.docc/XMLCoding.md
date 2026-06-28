# ``XMLCoding``

XML document parsing and declarative tree construction, independent of the Codable bridge.

## Overview

`XMLCoding` takes a deliberately different approach from `JSONParsing` and `YAMLParsing`. Rather than flattening XML into a `StructuredValue`, it preserves the full richness of the format — ordered attributes, mixed text/element content, CDATA sections, and comments — through a dedicated tree model: ``XMLElement`` and ``XMLNode``.

``XMLDocumentParser`` parses a well-formed XML document into an ``XMLElement`` tree. It handles elements, attributes, text, CDATA, comments, processing instructions, and predefined and numeric entity references. DTD validation and namespace resolution are out of scope; prefixes are preserved verbatim.

```swift
import XMLCoding

let root: XMLElement = try XMLDocumentParser().parse(xmlData)

let version = root.attribute("version")              // "1.2"
let items = root.firstElement(named: "items")        // first <items> child
let allChildren = root.elements                      // all child elements
let bodyText = root.firstElement(named: "body")?.text  // concatenated text content
```

For building XML — for example, constructing Anthropic-style tagged prompts — use ``XMLBuilder`` together with the convenience initializers on ``XMLElement``. The result builder supports conditionals, loops, and optional children.

```swift
import XMLCoding

let prompt = XMLElement("prompt") {
    XMLElement("system", text: "You are a data analyst.")
    XMLElement("context") {
        XMLElement("dataset", text: datasetName)
        if includeSchema {
            XMLElement("schema", text: schemaDescription)
        }
    }
    XMLElement("user", text: userQuestion)
}

let xmlString = prompt.rendered()   // pretty-printed by default
```

``XMLSerializer`` handles escaping correctly: `&`, `<`, and `>` in element content, plus `"` in attribute values. You can serialize any ``XMLElement`` tree to a `String` or `Data`:

```swift
let serializer = XMLSerializer(options: .init(prettyPrinted: false))
let compact = serializer.string(from: prompt)
```

## Topics

### Tree Model

- ``XMLElement``
- ``XMLNode``
- ``XMLAttribute``

### Parsing

- ``XMLDocumentParser``

### Building and Serialization

- ``XMLBuilder``
- ``XMLSerializer``
