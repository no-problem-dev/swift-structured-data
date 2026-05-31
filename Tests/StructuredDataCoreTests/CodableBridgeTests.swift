import Testing
@testable import StructuredDataCore

private struct Address: Codable, Equatable {
    var city: String
    var zip: String
}

private struct Person: Codable, Equatable {
    var name: String
    var age: Int
    var emails: [String]
    var address: Address
    var nickname: String?
}

struct CodableBridgeTests {
    private let value: StructuredValue = [
        "name": "Ada",
        "age": 36,
        "emails": ["ada@example.com", "a@b.io"],
        "address": ["city": "London", "zip": "NW1"],
    ]

    @Test
    func decodesNestedType() throws {
        let person = try value.decode(Person.self)
        #expect(person == Person(
            name: "Ada", age: 36,
            emails: ["ada@example.com", "a@b.io"],
            address: Address(city: "London", zip: "NW1"),
            nickname: nil
        ))
    }

    @Test
    func roundTripsThroughEncoder() throws {
        let person = Person(
            name: "Grace", age: 50, emails: ["g@navy.mil"],
            address: Address(city: "NYC", zip: "10001"), nickname: "Amazing"
        )
        let encoded = try StructuredValue.encoding(person)
        let decoded = try encoded.decode(Person.self)
        #expect(decoded == person)
    }

    @Test
    func keyStrategyConvertsSnakeCase() throws {
        struct Row: Codable, Equatable { var firstName: String; var lastInteraction: Int }
        let payload: StructuredValue = ["first_name": "Lin", "last_interaction": 7]
        let row = try payload.decode(Row.self, options: .init(keyStrategy: .convertFromSnakeCase))
        #expect(row == Row(firstName: "Lin", lastInteraction: 7))
    }

    @Test
    func missingKeyThrows() {
        let payload: StructuredValue = ["name": "x"]
        #expect(throws: DecodingError.self) { try payload.decode(Person.self) }
    }

    @Test
    func arbitraryPrecisionDecodesToDecimalNotDouble() throws {
        let payload: StructuredValue = ["value": .number(.init(unchecked: "9223372036854775808"))]
        struct Holder: Codable { var value: UInt64 }
        let holder = try payload.decode(Holder.self)
        #expect(holder.value == 9223372036854775808)
    }
}
