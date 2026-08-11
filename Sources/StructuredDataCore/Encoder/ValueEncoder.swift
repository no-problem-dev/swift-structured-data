import Foundation
/// Mutable node used while an `Encoder` builds up a result tree.
final class ValueRef {
    enum Storage {
        case scalar(StructuredValue)
        case array(ArrayRef)
        case object(ObjectRef)
    }
    var storage: Storage
    init(_ storage: Storage) { self.storage = storage }

    var resolved: StructuredValue {
        switch storage {
        case .scalar(let value): return value
        case .array(let ref): return .array(ref.elements.map(\.resolved))
        case .object(let ref): return .object(OrderedObject(ref.entries.map { ($0.key, $0.value.resolved) }))
        }
    }
}

final class ArrayRef { var elements: [ValueRef] = [] }
final class ObjectRef { var entries: [(key: String, value: ValueRef)] = [] }

/// The encoder that turns any Swift value into a tree, shared by every format serializer.
///
/// The mirror of ``ValueDecoder``. Encoding mutates a tree of reference nodes so that nested and
/// super encoders can each hold on to their own slot and fill it in later, in whatever order the
/// `Encodable` implementations happen to run; ``finalize()`` resolves that tree into an immutable
/// value once the writing is done.
final class ValueEncoder: Encoder {
    let options: EncodingOptions
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }
    let root: ValueRef

    init(options: EncodingOptions, codingPath: [CodingKey] = [], root: ValueRef = ValueRef(.scalar(.null))) {
        self.options = options
        self.codingPath = codingPath
        self.root = root
    }

    func finalize() -> StructuredValue { root.resolved }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        KeyedEncodingContainer(
            KeyedValueEncodingContainer(object: objectRoot(), options: options, codingPath: codingPath)
        )
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        UnkeyedValueEncodingContainer(array: arrayRoot(), options: options, codingPath: codingPath)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        ScalarEncodingContainer(ref: root, options: options, codingPath: codingPath)
    }

    private func objectRoot() -> ObjectRef {
        if case .object(let ref) = root.storage { return ref }
        let ref = ObjectRef()
        root.storage = .object(ref)
        return ref
    }

    private func arrayRoot() -> ArrayRef {
        if case .array(let ref) = root.storage { return ref }
        let ref = ArrayRef()
        root.storage = .array(ref)
        return ref
    }
}

extension EncodingOptions {
    /// Encodes one value into an immutable tree, passing an existing tree and an intercepted date straight through.
    ///
    /// Floating-point values become text via `String(_:)`, which round-trips finite values exactly
    /// but writes a non-finite one as `inf` or `nan` — text no JSON parser accepts.
    func lower<T: Encodable>(_ value: T, codingPath: [CodingKey]) throws -> StructuredValue {
        if let value = value as? StructuredValue { return value }
        if let date = value as? Date, dateStrategy.interceptsDate { return dateStrategy.encode(date) }
        let encoder = ValueEncoder(options: self, codingPath: codingPath)
        try value.encode(to: encoder)
        return encoder.finalize()
    }
}

enum ScalarEncoder {
    static func number(_ text: String) -> StructuredValue { .number(StructuredNumber(unchecked: text)) }
}
