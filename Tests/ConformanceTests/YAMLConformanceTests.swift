import Foundation
import Testing
import StructuredDataCore
@testable import JSONParsing
@testable import YAMLParsing

/// Measures the YAML parser against the official `yaml/yaml-test-suite`
/// (`data-2022-01-17`, MIT). The parser targets the JSON-superset Core subset,
/// so this asserts coverage floors and reports the actual rates rather than
/// claiming full conformance.
///
/// Both numbers are floors on measurements, not targets. They are what the
/// README and the module documentation are allowed to say, so a change that
/// moves either has to move these too — which is the point at which someone
/// has to decide whether the claim outside still matches the code.
struct YAMLConformanceTests {
    struct Case {
        let id: String
        let yaml: Data
        let expectedJSON: Data?
        let shouldError: Bool
    }

    static let cases: [Case] = {
        guard let root = Bundle.module.resourceURL?
            .appendingPathComponent("Suites/yaml-test-suite") else { return [] }
        let dirs = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        return dirs.compactMap { dir -> Case? in
            let yamlURL = dir.appendingPathComponent("in.yaml")
            guard let yaml = try? Data(contentsOf: yamlURL) else { return nil }
            let jsonURL = dir.appendingPathComponent("in.json")
            let errorURL = dir.appendingPathComponent("error")
            let expectedJSON = try? Data(contentsOf: jsonURL)
            let shouldError = FileManager.default.fileExists(atPath: errorURL.path)
            return Case(id: dir.lastPathComponent, yaml: yaml, expectedJSON: expectedJSON, shouldError: shouldError)
        }
    }()

    @Test
    func valueMatchCoverageMeetsFloor() throws {
        let valueCases = Self.cases.filter { $0.expectedJSON != nil && !$0.shouldError }
        try #require(valueCases.count > 100)

        var matched = 0
        for testCase in valueCases {
            guard
                let actual = try? YAMLParser().parse(testCase.yaml),
                let expected = try? JSONParser().parse(testCase.expectedJSON!)
            else { continue }
            if actual == expected { matched += 1 }
        }
        let rate = Double(matched) / Double(valueCases.count)
        print("YAML value-match: \(matched)/\(valueCases.count) (\(Int(rate * 100))%)")
        // Floor for the documented Core subset against the full-spec suite, which also exercises
        // anchors, tags, complex keys, and directives. Measured 71/231 = 30%.
        //
        // It used to be 85/231, when a tag or an anchor was stripped and whatever was left got
        // parsed. Fourteen of those documents were ones the stripping happened to get right;
        // refusing them is the price of not getting the rest of them quietly wrong.
        #expect(rate >= 0.30)
    }

    /// The other half of the same claim, and the one that stops "a subset" from sliding into
    /// "accepts anything". A parser that never rejects is not lenient, it is unable to tell you
    /// that your document is broken.
    @Test
    func errorRejectionMeetsFloor() throws {
        let errorCases = Self.cases.filter { $0.shouldError }
        try #require(errorCases.count > 50)

        var rejected = 0
        for testCase in errorCases where (try? YAMLParser().parse(testCase.yaml)) == nil {
            rejected += 1
        }
        let rate = Double(rejected) / Double(errorCases.count)
        print("YAML error-rejection: \(rejected)/\(errorCases.count) (\(Int(rate * 100))%)")
        // Measured 33/78 = 42%, up from 23/78 once unsupported constructs began throwing.
        // Still a minority: this refuses what it cannot read, which is not the same as validating.
        #expect(rate >= 0.42)
    }
}
