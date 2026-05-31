struct ScalarEncodingContainer: SingleValueEncodingContainer {
    let ref: ValueRef
    let options: EncodingOptions
    let codingPath: [CodingKey]

    func encodeNil() throws { ref.storage = .scalar(.null) }
    func encode(_ value: Bool) throws { ref.storage = .scalar(.bool(value)) }
    func encode(_ value: String) throws { ref.storage = .scalar(.string(value)) }
    func encode(_ value: Double) throws { ref.storage = .scalar(ScalarEncoder.number(String(value))) }
    func encode(_ value: Float) throws { ref.storage = .scalar(ScalarEncoder.number(String(value))) }

    func encode(_ value: Int) throws { encodeInteger(value) }
    func encode(_ value: Int8) throws { encodeInteger(value) }
    func encode(_ value: Int16) throws { encodeInteger(value) }
    func encode(_ value: Int32) throws { encodeInteger(value) }
    func encode(_ value: Int64) throws { encodeInteger(value) }
    func encode(_ value: UInt) throws { encodeInteger(value) }
    func encode(_ value: UInt8) throws { encodeInteger(value) }
    func encode(_ value: UInt16) throws { encodeInteger(value) }
    func encode(_ value: UInt32) throws { encodeInteger(value) }
    func encode(_ value: UInt64) throws { encodeInteger(value) }

    func encode<T: Encodable>(_ value: T) throws {
        ref.storage = .scalar(try options.lower(value, codingPath: codingPath))
    }

    private func encodeInteger<T: FixedWidthInteger>(_ value: T) {
        ref.storage = .scalar(ScalarEncoder.number(String(value)))
    }
}
