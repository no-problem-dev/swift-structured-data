# Getting Started with StructuredDataCore

Add swift-structured-data to your package and start decoding JSON, YAML, or XML with a single unified API.

## Installation

Add the package to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", from: "1.0.0"),
],
```

Then add the targets you need:

```swift
targets: [
    .target(
        name: "MyTarget",
        dependencies: [
            .product(name: "StructuredDataCore", package: "swift-structured-data"),
            .product(name: "JSONParsing",         package: "swift-structured-data"),
            .product(name: "YAMLParsing",         package: "swift-structured-data"),
            .product(name: "XMLCoding",            package: "swift-structured-data"),
        ]
    ),
]
```

Import only the targets you use — each format library is independent, and `StructuredDataCore` is re-exported automatically.

## Basic Usage

### StructuredValue — the neutral representation

Every format parser produces a ``StructuredValue``, an enum with six cases: `.null`, `.bool`, `.number`, `.string`, `.array`, `.object`.

```swift
import StructuredDataCore

// Build a value with literals
let value: StructuredValue = [
    "name": "Alice",
    "age": 30,
    "active": true,
]

// Dynamic member access — never throws, missing paths return .null
let name = value.name.string          // "Alice"
let city = value.address.city.string  // nil  (missing path → .null → nil)

// Key-based typed accessors
let age  = value.int("age")           // 30
let flag = value.bool("active")       // true
```

### JSONDecoder — JSON to Codable

```swift
import JSONParsing

struct Article: Decodable {
    var title: String
    var viewCount: Int
}

let decoder = JSONDecoder(
    decodingOptions: .init(keyStrategy: .convertFromSnakeCase)
)
let article = try decoder.decode(Article.self, from: jsonData)
```

Use ``JSONDecoder`` as `any StructuredDecoding` to keep your code format-agnostic:

```swift
func parse<T: Decodable>(_ type: T.Type, from data: Data, decoder: any StructuredDecoding) throws -> T {
    try decoder.decode(type, from: data)
}
```

### YAMLDecoder — YAML to Codable

`YAMLDecoder` exposes the same ``StructuredDecoding`` protocol as `JSONDecoder`. Drop it in wherever a JSON decoder works:

```swift
import YAMLParsing

let decoder = YAMLDecoder(
    decodingOptions: .init(keyStrategy: .convertFromSnakeCase)
)
let config = try decoder.decode(AppConfig.self, from: yamlData)
```

`YAMLParser` also supports multi-document streams:

```swift
let documents: [StructuredValue] = try YAMLParser().parseAll(yamlData)
```

### XMLDocumentParser + XMLBuilder — XML trees

XML has its own richer model (`XMLElement` / `XMLNode`) that preserves attributes, mixed content, and CDATA.

```swift
import XMLCoding

// Parse an XML document
let root: XMLElement = try XMLDocumentParser().parse(xmlData)
let version = root.attribute("version")         // attribute lookup
let items = root.firstElement(named: "items")   // first matching child

// Build XML with a result builder (e.g. Anthropic prompt tags)
let prompt = XMLElement("prompt") {
    XMLElement("system", text: "You are a data analyst.")
    XMLElement("user") {
        XMLElement("question", text: userQuestion)
    }
}
let xmlString = prompt.rendered()
```

To project an XML tree into ``StructuredValue`` for Codable decoding, use `XMLElement.structuredValue` if provided by your application layer, or traverse the tree directly.

### Choosing the right parser

| Situation | Use |
|---|---|
| Typical REST/LLM JSON payload | `JSONDecoder` |
| LLM token stream (partial JSON) | `StreamingJSONParser` |
| Configuration files | `YAMLDecoder` |
| Anthropic XML prompt tags | `XMLDocumentParser` + `XMLBuilder` |
| Raw intermediate value | `JSONParser` / `YAMLParser` directly |
| Format-agnostic decode | `any StructuredDecoding` |
