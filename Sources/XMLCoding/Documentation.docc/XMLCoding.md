# ``XMLCoding``

XML document parsing and declarative tree building, kept separate from the shared decoding bridge.

## Overview

`XMLCoding` takes a deliberately different approach from `JSONParsing` and `YAMLParsing`. Instead of flattening XML into a `StructuredValue`, it preserves the full richness of the format through a dedicated tree model — ``XMLElement`` and ``XMLNode``. Ordered attributes, mixed text and element content, CDATA sections, and comments all survive parsing intact.

``XMLDocumentParser`` parses a well-formed XML document into an ``XMLElement`` tree. It handles elements, attributes, text, CDATA, comments, and both predefined and numeric entity references; processing instructions, including the XML declaration, are recognized and skipped. DTD validation and namespace resolution are out of scope, so prefixes are preserved verbatim as part of element and attribute names.

```swift
import XMLCoding

let root = try XMLDocumentParser().parse(xmlData)

let version = root.attribute("version")                // "1.2"
let items = root.firstElement(named: "items")          // first <items> child
let allChildren = root.elements                        // every child element
let bodyText = root.firstElement(named: "body")?.text  // concatenated text content
```

To build XML — Anthropic-style tagged prompts, for instance — combine ``XMLBuilder`` with the convenience initializers on ``XMLElement``. The result builder supports conditionals, loops, and optional children.

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

``XMLSerializer`` gets the escaping right. It escapes `&`, `<`, and `>` in element content, and additionally escapes `"` in attribute values. Any ``XMLElement`` tree can be serialized to a `String` or to `Data`.

```swift
let serializer = XMLSerializer(options: XMLSerializer.Options(prettyPrinted: false))
let compact = serializer.string(from: prompt)
```

On macOS, `Foundation` vends its own `XMLElement`. Let type inference name the parser's result, as above, or write `XMLCoding.XMLElement` where an explicit annotation is unavoidable — an unqualified `XMLElement` annotation is ambiguous in a file that imports both modules.

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
