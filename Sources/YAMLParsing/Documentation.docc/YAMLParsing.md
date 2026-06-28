# ``YAMLParsing``

YAML 1.2 Core-schema parsing and serialization built on the `StructuredDataCore` neutral representation.

## Overview

`YAMLParsing` makes YAML a first-class citizen alongside JSON in this package. ``YAMLDecoder`` conforms to the `StructuredDecoding` protocol from `StructuredDataCore`, so it drops in wherever a `JSONDecoder` is used — the call site does not need to change.

```swift
import YAMLParsing

struct AppConfig: Decodable {
    var apiUrl: String
    var retryCount: Int
}

let decoder = YAMLDecoder(
    decodingOptions: .init(keyStrategy: .convertFromSnakeCase)
)
let config = try decoder.decode(AppConfig.self, from: yamlData)
```

When you need the raw `StructuredValue` tree rather than a `Decodable` type, use ``YAMLParser`` directly. It supports both single documents and multi-document streams separated by `---` markers:

```swift
import YAMLParsing

// Single document
let value = try YAMLParser().parse(yamlData)

// Multi-document stream
let documents: [StructuredValue] = try YAMLParser().parseAll(yamlData)
```

The parser covers the JSON-superset Core subset that most external systems produce: block and flow mappings and sequences, plain, single-quoted, double-quoted, literal, and folded scalars, comments, and multi-document streams. Tags, anchors/aliases, and complex keys are passed through as plain text.

``YAMLSerializer`` is the inverse — it emits block-style YAML for non-empty collections and guarantees a round-trip: `parse(serialize(v)) == v` over the same Core subset.

```swift
import YAMLParsing

let yamlString = YAMLSerializer().string(from: structuredValue)
```

## Topics

### Decoding

- ``YAMLDecoder``

### Parsing and Serialization

- ``YAMLParser``
- ``YAMLSerializer``
