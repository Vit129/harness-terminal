import Foundation

public enum TreeSitterGrammarBundle {
    public static let languages: [String] = [
        "swift",
        "python",
        "typescript",
        "javascript",
        "json",
        "yaml",
        "markdown",
        "rust",
        "go",
    ]

    public static func resourceURL(for language: String) -> URL? {
        Bundle.module.url(
            forResource: language,
            withExtension: "json",
            subdirectory: "TreeSitterGrammars"
        )
    }
}
