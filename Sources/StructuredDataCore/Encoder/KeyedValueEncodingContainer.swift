struct KeyedValueEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let object: ObjectRef
    let options: EncodingOptions
    let codingPath: [CodingKey]

    private func name(_ key: Key) -> String { options.keyStrategy.convert(key.stringValue) }

    private func append(_ key: Key, _ value: StructuredValue) {
        object.entries.append((name(key), ValueRef(.scalar(value))))
    }

    mutating func encodeNil(forKey key: Key) throws { append(key, .null) }
    mutating func encode(_ value: Bool, forKey key: Key) throws { append(key, .bool(value)) }
    mutating func encode(_ value: String, forKey key: Key) throws { append(key, .string(value)) }
    mutating func encode(_ value: Double, forKey key: Key) throws { append(key, ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: Float, forKey key: Key) throws { append(key, ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: Int, forKey key: Key) throws { append(key, ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: Int8, forKey key: Key) throws { append(key, ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: Int16, forKey key: Key) throws { append(key, ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: Int32, forKey key: Key) throws { append(key, ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: Int64, forKey key: Key) throws { append(key, ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: UInt, forKey key: Key) throws { append(key, ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: UInt8, forKey key: Key) throws { append(key, ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: UInt16, forKey key: Key) throws { append(key, ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: UInt32, forKey key: Key) throws { append(key, ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: UInt64, forKey key: Key) throws { append(key, ScalarEncoder.number(String(value))) }

    mutating func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        let lowered = try options.lower(value, codingPath: codingPath + [key])
        object.entries.append((name(key), ValueRef(.scalar(lowered))))
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type, forKey key: Key
    ) -> KeyedEncodingContainer<NestedKey> {
        let inner = ObjectRef()
        object.entries.append((name(key), ValueRef(.object(inner))))
        return KeyedEncodingContainer(
            KeyedValueEncodingContainer<NestedKey>(object: inner, options: options, codingPath: codingPath + [key])
        )
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let inner = ArrayRef()
        object.entries.append((name(key), ValueRef(.array(inner))))
        return UnkeyedValueEncodingContainer(array: inner, options: options, codingPath: codingPath + [key])
    }

    mutating func superEncoder() -> Encoder {
        let slot = ValueRef(.scalar(.null))
        object.entries.append(("super", slot))
        return ValueEncoder(options: options, codingPath: codingPath, root: slot)
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        let slot = ValueRef(.scalar(.null))
        object.entries.append((name(key), slot))
        return ValueEncoder(options: options, codingPath: codingPath + [key], root: slot)
    }
}
