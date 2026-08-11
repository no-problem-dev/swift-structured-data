# Modules

Four modules, one shared backbone, and an honest account of what each parser accepts and rejects.

## Overview

Every format target parses into the same neutral value and hands it to the same decoding backbone.
That is the whole architecture: parsing and type conversion are separate layers, which is what lets
a number keep its precision until something asks for a concrete Swift type.

| Module | Role | Depends on |
|---|---|---|
| `StructuredDataCore` | ``StructuredValue``, ``StructuredNumber``, ``OrderedObject``, the `Decoder`/`Encoder` backbone, the property wrappers | Foundation only |
| `JSONParsing` | RFC 8259 parser and serializer, plus streaming and tolerant readers | `StructuredDataCore` |
| `YAMLParsing` | A YAML 1.2 Core subset that throws on the constructs it does not implement, with a serializer for round-tripping | `StructuredDataCore` |
| `XMLCoding` | A full XML tree and a declarative builder — deliberately not routed through ``StructuredValue`` | `StructuredDataCore` |

There is no re-export. A target that names a `StructuredDataCore` type directly — most obviously
one that injects `any StructuredDecoding` — imports `StructuredDataCore` as well as its format
module.

The split into two layers is why `JSONDecoder` and `YAMLDecoder` are interchangeable at a call
site: a **parser** (``DataParser``) turns bytes into ``StructuredValue`` and never touches
`Codable`; a **decoder** (``StructuredDecoder``) pairs a parser with the shared backbone and
presents ``StructuredDecoding``. Swapping formats is a change at the composition root.

## What each reader accepts and rejects

The three formats are not equally faithful to their specifications, and the differences are not
symmetric. JSON is strict and reports precisely where it stopped. YAML and XML are subsets, and a
subset has to decide what to do with the rest: here, both **refuse it rather than guess**. Neither
is a validator, so plenty of genuinely broken input still gets through — but nothing outside the
subset is quietly turned into a value the document does not contain.

### JSON — strict by default

`JSONParser` implements RFC 8259 as written. Comments, trailing commas, single-quoted strings,
unquoted keys, `NaN`, `Infinity`, and a leading zero such as `01` are all rejected. Top-level
scalars are accepted, as the RFC requires.

Two things the RFC leaves to the implementation are settings rather than assumptions.
``DuplicateKeyPolicy`` decides what a repeated key means — the default keeps the last one, and
`JSONParsingOptions.strict` takes the RFC 7493 line and rejects the document. `maximumDepth`
bounds recursion at 128 levels by default, so an adversarial document of nothing but open brackets
throws instead of exhausting the stack.

`StreamingJSONParser` and the tolerant reader behind it exist for one job: rendering an LLM
response while it is still arriving. Tolerance there is narrow and deliberate — truncation anywhere,
trailing commas, and anything after the top-level value. It still refuses comments, single quotes,
unquoted keys, `NaN` and `Infinity`; each of those simply ends the read, so `{'a':1}` yields an
empty object rather than an error. It also never throws, which means "parsed nothing" and "parsed
everything" look the same from the outside.

### YAML — a subset that says so

`YAMLParser` covers what configuration files actually use: block and flow collections, plain and
quoted scalars, literal and folded block scalars with chomping and explicit indent indicators,
comments, and multi-document streams.

What it does not cover **throws** ``ParseError/Kind/unsupportedConstruct(_:)``: tags, anchors and
aliases in either context, complex keys, `%TAG` directives, and `%YAML` directives naming any
version but 1.2. Each of these used to be stripped and whatever was left parsed, which turned
`!!str 42` into the number 42 and an alias into null — answers the document never gave, with
nothing in the result to mark them.

Two gaps stay silent because neither can be told apart from ordinary content: a tab used as
indentation counts as no indentation at all, so the line lands in the wrong parent, and a repeated
key is kept alongside the first rather than resolved by any policy.

Against the official YAML test suite this rejects 42% of the documents a conforming parser is
required to reject, and reproduces 30% of the values in the documents it should accept — the rest
being the constructs above. Refusing what it cannot read is not the same as validating what it can:
this remains a reader for input you control. Both figures are asserted as floors in
`ConformanceTests`.

`YAMLScalarResolver` follows the 1.2 **Core** schema, which is the one that fixed the Norway
problem: `yes`, `no`, `on` and `off` are strings. Only `true`/`True`/`TRUE` and
`false`/`False`/`FALSE` are booleans, matched exactly — `tRue` is a string. `.inf`, `.nan`, `.5` and
`+1.5` all fall through to string, because the float rule is the JSON grammar, which is narrower
than YAML's.

### XML — a tree, not a value

`XMLCoding` is the one module that does not lower into ``StructuredValue``. Elements, attributes,
text, CDATA and comments stay distinct and in document order, so mixed content round-trips —
and consequently there is no `Codable` bridge for XML.

It reads the document body, not the declarations around it. A `<!DOCTYPE …>` declaration is fatal
rather than ignored. Entities beyond the five built-ins and numeric references throw. Namespaces are
not resolved: a prefix stays part of the name and `xmlns` is an ordinary attribute. Input must be
UTF-8; no other encoding is detected, including one named in an XML declaration.

## Numbers, ordering, and error positions

Three cross-cutting behaviours are worth reading before you rely on them.

``StructuredNumber`` keeps the source text byte for byte — sign, exponent spelling, trailing zeros —
and converts only at the accessor you choose, so an integer too large for `Int64` survives and is
readable through `uint64` or `decimal`. Equality compares mathematical value rather than spelling,
so `1`, `1.0`, `1e0` and `100e-2` are one value and `-0` equals `0`; two equal numbers can
therefore serialize differently. YAML's `0o` and `0x` forms are the one exception to text
preservation — they are converted to decimal.

``OrderedObject`` preserves key order from parse through serialize, so a rewritten configuration
file does not reshuffle itself.

``ParseError`` carries a ``SourceLocation`` whose `line` and `column` are 1-based and `offset` is
0-based — and **all three count UTF-8 bytes, not characters**. A column on a line of Japanese text
is a byte position, not a caret position. Only the strict JSON scanner fills the location in; YAML
and XML leave it nil, so for those the error kind is the whole diagnostic. Failures after parsing —
a number that will not fit, a missing key — arrive as `DecodingError` instead.
