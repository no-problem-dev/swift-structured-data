import Testing
@testable import StructuredDataCore

struct PropertyWrapperTests {
    @Test
    func defaultFillsMissingAndNull() throws {
        struct Settings: Codable {
            @DefaultFalse var verbose: Bool
            @DefaultZero var retries: Int
            @DefaultEmptyArray<String> var tags: [String]
        }
        let empty = try (StructuredValue.object(.init())).decode(Settings.self)
        #expect(empty.verbose == false)
        #expect(empty.retries == 0)
        #expect(empty.tags == [])

        let nulls: StructuredValue = ["verbose": .null, "retries": .null]
        let decoded = try nulls.decode(Settings.self)
        #expect(decoded.verbose == false)
        #expect(decoded.retries == 0)
    }

    @Test
    func defaultRespectsPresentValue() throws {
        struct Settings: Codable { @DefaultTrue var enabled: Bool }
        let decoded = try (["enabled": false] as StructuredValue).decode(Settings.self)
        #expect(decoded.enabled == false)
    }

    @Test
    func lossyArrayDropsBadElements() throws {
        struct Holder: Codable { @LossyArray var ids: [Int] }
        let payload: StructuredValue = ["ids": [1, "oops", 3, .null, 5]]
        let holder = try payload.decode(Holder.self)
        #expect(holder.ids == [1, 3, 5])
    }

    @Test
    func lossyArrayDefaultsWhenMissing() throws {
        struct Holder: Codable { @LossyArray var ids: [Int] }
        let holder = try (StructuredValue.object(.init())).decode(Holder.self)
        #expect(holder.ids == [])
    }

    @Test
    func losslessValueAcceptsStringAndNumber() throws {
        struct Row: Codable {
            @LosslessValue var id: Int
            @LosslessValue var ratio: Double
        }
        let stringForm: StructuredValue = ["id": "42", "ratio": "3.5"]
        let a = try stringForm.decode(Row.self)
        #expect(a.id == 42)
        #expect(a.ratio == 3.5)

        let numberForm: StructuredValue = ["id": 7, "ratio": 1.5]
        let b = try numberForm.decode(Row.self)
        #expect(b.id == 7)
        #expect(b.ratio == 1.5)
    }
}
