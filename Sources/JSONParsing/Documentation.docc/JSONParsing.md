# ``JSONParsing``

A JSON parsing and encoding stack built on the package's neutral intermediate representation.

## Overview

`JSONParsing` provides this package's complete JSON codec stack. At the top sits ``JSONDecoder``, a thin composition of the low-level parser and the shared decoding backbone in `StructuredDataCore`. Because ``JSONDecoder`` conforms to the `StructuredDecoding` protocol that `StructuredDataCore` defines, you can inject it anywhere a format-independent decoder is expected, and later substitute `YAMLDecoder` without touching the rest of your code.

```swift
import StructuredDataCore
import JSONParsing

struct Config: Codable {
    var host: String
    var port: Int
    var debug: Bool
}

let decoder = JSONDecoder(
    decodingOptions: DecodingOptions(keyStrategy: .convertFromSnakeCase)
)
let config = try decoder.decode(Config.self, from: jsonData)
```

Use ``JSONParser`` when you need the intermediate `StructuredValue` itself — for example, to inspect a loosely typed payload before deciding which model to decode it into.

```swift
import JSONParsing

let value = try JSONParser().parse(jsonData)
let kind = value.type.string          // dynamic member lookup, never throws
let count = value.int("itemCount")    // typed key accessor
```

``StreamingJSONParser`` handles LLM token streams. It accumulates chunks and exposes the best interpretation so far through `snapshot()`, which never throws. Once the stream completes, `finish()` parses the accumulated buffer strictly.

```swift
var streaming = StreamingJSONParser()
for chunk in tokenStream {
    streaming.consume(chunk)
    let partial = streaming.snapshot()   // render partial UI here
}
let final = try streaming.finish()
```

Encoding mirrors decoding. ``JSONEncoder`` conforms to the `StructuredEncoding` protocol and uses ``JSONSerializer`` internally.

```swift
let encoder = JSONParsing.JSONEncoder()
let data = try encoder.encode(config)
let string = try encoder.string(from: config)
```

``JSONDecoder`` and ``JSONEncoder`` share their names with the Foundation types. In a file that also imports `Foundation`, an unqualified `JSONEncoder()` resolves to Foundation's, so qualify the module name whenever the call is ambiguous. `JSONDecoder(decodingOptions:)` above needs no qualification because Foundation's decoder has no matching initializer.

## Topics

### Decoding and Encoding

- ``JSONDecoder``
- ``JSONEncoder``

### Parsing and Serialization

- ``JSONParser``
- ``JSONSerializer``
- ``JSONParsingOptions``

### Streaming

- ``StreamingJSONParser``
