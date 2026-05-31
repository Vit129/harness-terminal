import XCTest
@testable import HarnessCore

final class JSONOutputFormatterTests: XCTestCase {
    private let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    func testCompactByDefaultIsSingleLineWithSortedKeys() throws {
        let ws = WorkspaceSummary(id: id, name: "Default", tabCount: 2)
        let json = try JSONOutputFormatter.encode(ws)
        XCTAssertFalse(json.contains("\n"), "compact output must be a single line")
        // sortedKeys: id < name < tabCount alphabetically.
        let iID = json.range(of: "\"id\"")!.lowerBound
        let iName = json.range(of: "\"name\"")!.lowerBound
        let iTab = json.range(of: "\"tabCount\"")!.lowerBound
        XCTAssertTrue(iID < iName && iName < iTab, "keys must be sorted")
    }

    func testPrettyIndentsAndStaysSorted() throws {
        let ws = WorkspaceSummary(id: id, name: "Default", tabCount: 2)
        let pretty = try JSONOutputFormatter.encode(ws, pretty: true)
        XCTAssertTrue(pretty.contains("\n"), "pretty output must be multi-line")
        XCTAssertTrue(pretty.contains("  \"id\""), "pretty output must be indented")
        // Same data still parses to an equal object.
        XCTAssertEqual(
            try JSONSerialization.jsonObject(with: Data(pretty.utf8)) as? [String: Any] != nil,
            true
        )
    }

    func testDatesAreISO8601() throws {
        let when = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14T22:13:20Z
        let client = ClientSummary(id: id, label: "cli", attachedSurfaceIDs: [], connectedAt: when)
        let json = try JSONOutputFormatter.encode(client)
        XCTAssertTrue(json.contains("2023-11-14T22:13:20Z"), "dates must encode as ISO-8601: \(json)")
    }

    func testValidJSONAndRoundTripForRepresentativeModels() throws {
        // Each representative payload encodes to valid JSON and decodes back unchanged.
        try assertRoundTrips(WorkspaceSummary(id: id, name: "api", tabCount: 3))
        try assertRoundTrips(OptionEntry(scope: "global", target: nil, key: "status", value: "on"))
        try assertRoundTrips(DaemonStats(pid: 42, uptimeSeconds: 12.5, surfaceCount: 3,
                                         totalScrollbackBytes: 4096, clientCount: 1,
                                         subscriberCount: 2, snapshotRevision: 7))
        try assertRoundTrips(HookEntry(id: id, event: "after-new-tab",
                                       commandSource: "display-message hi", condition: nil))
    }

    /// Encode → assert valid JSON → decode (ISO-8601 dates) → re-encode and assert the JSON is
    /// unchanged. Re-encoding (with the formatter's sorted keys) is a deterministic round-trip
    /// check that works for any `Codable`, without requiring the model to be `Equatable`.
    private func assertRoundTrips<T: Codable>(_ value: T) throws {
        let json = try JSONOutputFormatter.encode(value)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: Data(json.utf8)),
                         "must be valid JSON: \(json)")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(T.self, from: Data(json.utf8))
        XCTAssertEqual(try JSONOutputFormatter.encode(decoded), json,
                       "decoding then re-encoding must reproduce the JSON")
    }
}
