# Getting Started

Add swift-structured-data to your package and decode JSON, YAML, and XML through one API.

## Installation

Add the package to the dependencies in your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/no-problem-dev/swift-structured-data.git", from: "2.0.0"),
],
```

Then add the products you need to a target.

```swift
targets: [
    .target(
        name: "MyTarget",
        dependencies: [
            .product(name: "StructuredDataCore", package: "swift-structured-data"),
            .product(name: "JSONParsing",        package: "swift-structured-data"),
            .product(name: "YAMLParsing",        package: "swift-structured-data"),
            .product(name: "XMLCoding",          package: "swift-structured-data"),
        ]
    ),
]
```

The format libraries are independent of one another, so depend only on the ones you use. Each one is built on `StructuredDataCore` but does not re-export it, so any file that names a core type directly — ``StructuredValue``, ``DecodingOptions``, or a protocol such as ``StructuredDecoding`` — must import `StructuredDataCore` as well.

## Basic Usage

### StructuredValue — the neutral representation

Every format parser produces a ``StructuredValue``: an enum with six cases — `.null`, `.bool`, `.number`, `.string`, `.array`, and `.object`.

```swift
import StructuredDataCore

// Build a value from literals.
let value: StructuredValue = [
    "name": "Alice",
    "age": 30,
    "active": true,
]

// Dynamic member lookup — never throws. A missing path surfaces as .null.
let name = value.name.string          // "Alice"
let city = value.address.city.string  // nil (missing path → .null → nil)

// Typed key-based accessors.
let age  = value.int("age")           // 30
let flag = value.bool("active")       // true
```

### JSONDecoder — JSON into Codable

```swift
import StructuredDataCore
import JSONParsing

struct Article: Decodable {
    var title: String
    var viewCount: Int
}

let decoder = JSONDecoder(
    decodingOptions: DecodingOptions(keyStrategy: .convertFromSnakeCase)
)
let article = try decoder.decode(Article.self, from: jsonData)
```

Accepting `any StructuredDecoding` keeps your own code format-independent.

```swift
func parse<T: Decodable>(_ type: T.Type, from data: Data, decoder: any StructuredDecoding) throws -> T {
    try decoder.decode(type, from: data)
}
```

### YAMLDecoder — YAML into Codable

`YAMLDecoder` exposes the same ``StructuredDecoding`` protocol as `JSONDecoder`, so it drops into any place the JSON decoder already works.

```swift
import StructuredDataCore
import YAMLParsing

let decoder = YAMLDecoder(
    decodingOptions: DecodingOptions(keyStrategy: .convertFromSnakeCase)
)
let config = try decoder.decode(AppConfig.self, from: yamlData)
```

`YAMLParser` also reads multi-document streams.

```swift
let documents: [StructuredValue] = try YAMLParser().parseAll(yamlData)
```

### XMLDocumentParser and XMLBuilder — the XML tree

XML has a richer model of its own — `XMLElement` and `XMLNode` — that preserves attributes, mixed content, and CDATA.

```swift
import XMLCoding

// Parse an XML document.
let root = try XMLDocumentParser().parse(xmlData)
let version = root.attribute("version")         // read an attribute
let items = root.firstElement(named: "items")   // first matching child element

// Build XML with the result builder (for example, Anthropic prompt tags).
let prompt = XMLElement("prompt") {
    XMLElement("system", text: "You are a data analyst.")
    XMLElement("user") {
        XMLElement("question", text: userQuestion)
    }
}
let xmlString = prompt.rendered()
```

`XMLCoding` deliberately stays outside the `Codable` bridge: there is no built-in projection from an XML tree to a ``StructuredValue``. If you need one, write it in your application layer against the shape of your documents, or walk the tree directly.

### Choosing a parser

| Situation | What to use |
|---|---|
| Ordinary REST or LLM JSON payloads | `JSONDecoder` |
| LLM token streams (partial JSON) | `StreamingJSONParser` |
| Configuration files | `YAMLDecoder` |
| Anthropic XML prompt tags | `XMLDocumentParser` and `XMLBuilder` |
| Raw intermediate values | `JSONParser` or `YAMLParser` directly |
| Format-independent decoding | `any StructuredDecoding` |
