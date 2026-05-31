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

/// An `Encoder` that lowers any `Encodable` into a `StructuredValue`.
///
/// The mirror image of ``ValueDecoder``: one implementation, reused by every
/// format serializer. Encoding mutates a shared reference tree so nested and
/// super encoders write into their own slot, then ``finalize()`` resolves it.
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
    /// Encodes a single `Encodable` into an immutable `StructuredValue`.
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
