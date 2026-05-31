import Foundation

/// The single encoder behind every `harness-cli … --json` command, so the machine-readable
/// contract is uniform: keys are always sorted (stable diffs / deterministic output), dates are
/// ISO-8601, and output is compact by default — `--pretty` opts into indentation. Keeping this in
/// HarnessCore (not the CLI) means the CLI shim stays thin and the JSON shape is unit-testable.
public enum JSONOutputFormatter {
    /// Encode any `Encodable` payload to a JSON string. Compact (single line) unless `pretty`.
    /// `sortedKeys` is always on so two runs of the same data are byte-identical, and dates use
    /// ISO-8601 to match `AgentListFormatter` and the on-disk stores.
    public static func encode<T: Encodable>(_ value: T, pretty: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = pretty ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}
