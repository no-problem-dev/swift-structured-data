struct UnkeyedValueEncodingContainer: UnkeyedEncodingContainer {
    let array: ArrayRef
    let options: EncodingOptions
    let codingPath: [CodingKey]

    var count: Int { array.elements.count }

    private func append(_ value: StructuredValue) {
        array.elements.append(ValueRef(.scalar(value)))
    }

    mutating func encodeNil() throws { append(.null) }
    mutating func encode(_ value: Bool) throws { append(.bool(value)) }
    mutating func encode(_ value: String) throws { append(.string(value)) }
    mutating func encode(_ value: Double) throws { append(ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: Float) throws { append(ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: Int) throws { append(ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: Int8) throws { append(ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: Int16) throws { append(ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: Int32) throws { append(ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: Int64) throws { append(ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: UInt) throws { append(ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: UInt8) throws { append(ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: UInt16) throws { append(ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: UInt32) throws { append(ScalarEncoder.number(String(value))) }
    mutating func encode(_ value: UInt64) throws { append(ScalarEncoder.number(String(value))) }

    mutating func encode<T: Encodable>(_ value: T) throws {
        let slot = ValueRef(.scalar(.null))
        array.elements.append(slot)
        try value.encode(to: ValueEncoder(options: options, codingPath: codingPath + [IndexKey(count - 1)], root: slot))
    }

    mutating func nestedContainer<NestedKey: CodingKey>(
        keyedBy keyType: NestedKey.Type
    ) -> KeyedEncodingContainer<NestedKey> {
        let inner = ObjectRef()
        array.elements.append(ValueRef(.object(inner)))
        return KeyedEncodingContainer(
            KeyedValueEncodingContainer<NestedKey>(object: inner, options: options, codingPath: codingPath)
        )
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let inner = ArrayRef()
        array.elements.append(ValueRef(.array(inner)))
        return UnkeyedValueEncodingContainer(array: inner, options: options, codingPath: codingPath)
    }

    mutating func superEncoder() -> Encoder {
        let slot = ValueRef(.scalar(.null))
        array.elements.append(slot)
        return ValueEncoder(options: options, codingPath: codingPath, root: slot)
    }
}
