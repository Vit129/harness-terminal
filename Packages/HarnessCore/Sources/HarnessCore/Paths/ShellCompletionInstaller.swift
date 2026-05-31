import Foundation

/// Installs the fish completion script for `harness-cli` into
/// `~/.config/fish/completions/`. The script is generated from the canonical
/// `CLICommandCatalog` by `CompletionGenerator`, so the installed file, the
/// `harness-cli completions fish` output, and `Scripts/completions/harness-cli.fish`
/// are all the same one source — no hand-maintained command list to drift.
public enum ShellCompletionInstaller {
    /// The fish completion script — generated from the command catalog.
    public static var fishCompletionSource: String {
        CompletionGenerator.script(for: .fish)
    }

    /// Write the fish completion script to its standard location. Returns
    /// the installed URL or throws if write fails. Idempotent.
    @discardableResult
    public static func installFishCompletion() throws -> URL {
        try FileManager.default.createDirectory(
            at: HarnessPaths.fishCompletionDirectory,
            withIntermediateDirectories: true
        )
        try fishCompletionSource.write(
            to: HarnessPaths.fishCompletionURL,
            atomically: true,
            encoding: .utf8
        )
        return HarnessPaths.fishCompletionURL
    }
}
