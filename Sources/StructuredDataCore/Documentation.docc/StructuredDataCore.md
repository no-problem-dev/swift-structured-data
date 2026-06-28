# ``StructuredDataCore``

Format-neutral structured data representation and Codable bridge shared by JSON, YAML, and XML targets.

## Overview

`StructuredDataCore` defines the intermediate representation that all format parsers converge on: ``StructuredValue``. Every format module in this package — `JSONParsing`, `YAMLParsing`, and `XMLCoding` — produces or consumes a `StructuredValue`, and the single decoding backbone in `StructuredDataCore` turns it into any `Decodable` type. Swapping JSON for YAML at the call site requires changing only one import.

```swift
import StructuredDataCore
import JSONParsing

// Parse JSON into the neutral representation
let value = try JSONParser().parse(jsonData)

// Extract values directly
let name: String? = value.user.name.string          // dynamic member access
let age: Int? = value.int("age")                    // key-based typed accessor

// Decode into a Codable type via the shared bridge
struct User: Decodable { var name: String; var age: Int }
let user = try value.decode(User.self)
```

The architecture is split into two layers:

- **Layer 1 — Parsing**: each format target implements ``DataParser`` and produces a `StructuredValue` without performing any `Codable` type coercion.
- **Layer 2 — Decoding**: ``StructuredDecoder`` composes a `DataParser` with the shared decoding backbone, exposing the ``StructuredDecoding`` protocol so call sites stay format-agnostic.

```swift
// Format-agnostic decode — swap JSONDecoder for YAMLDecoder with no other changes
func load<T: Decodable>(_ type: T.Type, from data: Data, using decoder: any StructuredDecoding) throws -> T {
    try decoder.decode(type, from: data)
}
```

The four modules divide responsibilities as follows. `StructuredDataCore` owns the neutral intermediate representation and the `Codable` bridge — it is the only dependency the other three modules share. `JSONParsing` provides `JSONDecoder` and `JSONEncoder` for ordinary REST/LLM payloads, `JSONParser` for direct `StructuredValue` access, and `StreamingJSONParser` for token-by-token LLM output. `YAMLParsing` covers YAML 1.2 Core-schema documents via `YAMLDecoder` and `YAMLParser`, plus a matching `YAMLSerializer` for round-tripping. `XMLCoding` takes a different approach: it preserves the full XML tree — elements, attributes, mixed content, CDATA — through `XMLDocumentParser`, `XMLElement`, and `XMLBuilder`, rather than flattening XML into `StructuredValue`.

## Topics

### Essentials

- <doc:GettingStarted>

### Intermediate Representation

- ``StructuredValue``
- ``StructuredNumber``
- ``OrderedObject``

### Parsing and Serialization Contracts

- ``DataParser``
- ``DataSerializer``
- ``StructuredDecoding``
- ``StructuredEncoding``
- ``StructuredDecoder``
- ``StructuredEncoder``

### Options and Configuration

- ``DecodingOptions``
- ``EncodingOptions``
- ``DateCodingStrategy``
- ``DuplicateKeyPolicy``

### Error Handling

- ``ParseError``
- ``SourceLocation``

### Property Wrappers

- ``Default``
- ``DefaultValueProvider``
- ``DefaultProviders``
- ``LosslessValue``
- ``LossyArray``
