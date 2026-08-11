# ``StructuredDataCore``

A format-independent representation for structured data, and the decoding bridge every format target shares.

## Overview

`StructuredDataCore` defines ``StructuredValue``, the intermediate representation that every parser in this package converges on. The `JSONParsing` and `YAMLParsing` modules produce and consume `StructuredValue`, and a single decoding backbone in `StructuredDataCore` turns it into any `Decodable` type. Swapping JSON for YAML at a call site is a one-line import change.

```swift
import StructuredDataCore
import JSONParsing

// Parse JSON into the neutral representation.
let value = try JSONParser().parse(jsonData)

// Read values directly.
let name: String? = value.user.name.string   // dynamic member lookup
let age: Int? = value.int("age")             // typed key-based accessor

// Decode into a Codable type through the shared bridge.
struct User: Decodable { var name: String; var age: Int }
let user = try value.decode(User.self)
```

The architecture has two layers.

- **Layer 1 — parsing**: a format target implements ``DataParser`` and produces a `StructuredValue` without performing any `Codable` conversion.
- **Layer 2 — decoding**: ``StructuredDecoder`` composes a `DataParser` with the shared decoding backbone and exposes a format-independent entry point to call sites as the ``StructuredDecoding`` protocol.

```swift
// Format-independent decoding — substituting YAMLDecoder for JSONDecoder changes nothing else.
func load<T: Decodable>(_ type: T.Type, from data: Data, using decoder: any StructuredDecoding) throws -> T {
    try decoder.decode(type, from: data)
}
```

The four modules divide as follows. `StructuredDataCore` holds the neutral representation and the `Codable` bridge, and is the only dependency the other three share. `JSONParsing` provides `JSONDecoder` and `JSONEncoder` for ordinary REST and LLM payloads, `JSONParser` for working with `StructuredValue` directly, and `StreamingJSONParser` for token-by-token LLM output. `YAMLParsing` handles YAML documents with `YAMLDecoder` and `YAMLParser`, resolving plain scalars with the YAML 1.2 Core schema, and adds `YAMLSerializer` for round-tripping. `XMLCoding` takes a deliberately different route: rather than flattening XML into a `StructuredValue`, it preserves the full XML tree — elements, attributes, mixed content, and CDATA — through `XMLDocumentParser`, `XMLElement`, and `XMLBuilder`, and stands apart from the `Codable` bridge entirely.

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Modules>

### Intermediate Representation

- ``StructuredValue``
- ``StructuredNumber``
- ``OrderedObject``

### Parsing and Serialization Protocols

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

### Default Value Shorthands

- ``DefaultFalse``
- ``DefaultTrue``
- ``DefaultZero``
- ``DefaultEmptyString``
- ``DefaultEmptyArray``
