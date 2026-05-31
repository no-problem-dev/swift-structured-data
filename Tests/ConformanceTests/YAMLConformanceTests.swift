import Foundation
import Testing
import StructuredDataCore
@testable import JSONParsing
@testable import YAMLParsing

/// Measures the YAML parser against the official `yaml/yaml-test-suite`
/// (`data-2022-01-17`, MIT). The parser targets the JSON-superset Core subset,
/// so this asserts a coverage floor and reports the actual rate rather than
/// claiming full conformance.
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
        // Floor for the documented Core subset against the full-spec suite, which
        // also exercises anchors, tags, complex keys, and directives.
        #expect(rate >= 0.33)
    }

    @Test
    func errorRejectionIsReported() {
        let errorCases = Self.cases.filter { $0.shouldError }
        var rejected = 0
        for testCase in errorCases where (try? YAMLParser().parse(testCase.yaml)) == nil {
            rejected += 1
        }
        print("YAML error-rejection: \(rejected)/\(errorCases.count)")
    }
}
