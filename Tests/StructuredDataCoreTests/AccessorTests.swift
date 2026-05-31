import Testing
@testable import StructuredDataCore

struct AccessorTests {
    private let value: StructuredValue = [
        "user": ["name": "Ada", "roles": ["admin", "dev"]],
        "active": true,
        "count": 3,
    ]

    @Test
    func dynamicMemberChaining() {
        #expect(value.user.name.string == "Ada")
        #expect(value.user.roles[0].string == "admin")
        #expect(value.active.bool == true)
        #expect(value.count.int == 3)
    }

    @Test
    func missingPathsAreNull() {
        #expect(value.user.missing.isNull)
        #expect(value.user.roles[99].isNull)
        #expect(value.nonexistent.deeper.string == nil)
    }

    @Test
    func typedSubscriptDecode() {
        #expect(value["count", as: Int.self] == 3)
        #expect(value["user", as: Int.self] == nil)
    }

    @Test
    func orderPreservedInObject() {
        guard case .object(let object) = value else { Issue.record("expected object"); return }
        #expect(object.keys == ["user", "active", "count"])
    }
}
