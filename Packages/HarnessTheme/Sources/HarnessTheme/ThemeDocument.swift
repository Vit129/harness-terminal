import Foundation

/// Errors raised when reading or validating a `.harnesstheme` document.
public enum ThemeDocumentError: Error, Equatable {
    case unsupportedVersion(Int)
    case emptyName
    case wrongPaletteCount(Int)
    case malformed(String)
}

/// The shareable `.harnesstheme` file format — a versioned, human-readable JSON document
/// describing a full Harness theme: canvas colors, ANSI palette, and the appearance knobs
/// (opacity, blur, font, padding) plus whether the theme should recolor terminal output.
///
/// This is the unit of export/import/sharing. It is intentionally a superset of
/// `HarnessThemeDefinition` (which is colors-only): a document can seed both the catalog
/// definition and the user's appearance settings on import, and is produced from the
/// current theme + settings on export.
public struct ThemeDocument: Codable, Equatable, Sendable {
    /// Bumped only on incompatible schema changes; readers reject newer majors.
    public static let currentVersion = 1
    /// File extension and Uniform Type Identifier (registered in the app's Info.plist).
    public static let fileExtension = "harnesstheme"
    public static let uti = "com.robert.harness.theme"

    public var version: Int
    public var name: String
    public var author: String?
    public var colors: Colors
    public var appearance: Appearance?

    public init(
        version: Int = ThemeDocument.currentVersion,
        name: String,
        author: String? = nil,
        colors: Colors,
        appearance: Appearance? = nil
    ) {
        self.version = version
        self.name = name
        self.author = author
        self.colors = colors
        self.appearance = appearance
    }

    /// Canvas colors + the 16-entry ANSI palette.
    public struct Colors: Codable, Equatable, Sendable {
        public var background: RGBColor
        public var foreground: RGBColor
        public var cursor: RGBColor?
        public var cursorText: RGBColor?
        public var selectionBackground: RGBColor?
        public var selectionForeground: RGBColor?
        public var bold: RGBColor?
        public var palette: [RGBColor]

        public init(
            background: RGBColor,
            foreground: RGBColor,
            cursor: RGBColor? = nil,
            cursorText: RGBColor? = nil,
            selectionBackground: RGBColor? = nil,
            selectionForeground: RGBColor? = nil,
            bold: RGBColor? = nil,
            palette: [RGBColor]
        ) {
            self.background = background
            self.foreground = foreground
            self.cursor = cursor
            self.cursorText = cursorText
            self.selectionBackground = selectionBackground
            self.selectionForeground = selectionForeground
            self.bold = bold
            self.palette = palette
        }
    }

    /// Whole-window appearance the theme can carry. A minimal theme can omit these keys
    /// and inherit user settings; color metadata decodes to conservative sRGB defaults.
    public struct Appearance: Codable, Equatable, Sendable {
        public enum SourceColorSpace: String, Codable, Equatable, Sendable {
            case sRGB = "sRGB"
            case displayP3 = "displayP3"
        }

        public enum AppearanceKind: String, Codable, Equatable, Sendable {
            case dark
            case light
        }

        public enum ContrastGrade: String, Codable, Equatable, Sendable {
            case high
            case medium
            case low
        }

        public var backgroundOpacity: Double?
        public var backgroundBlur: Int?
        public var fontFamily: String?
        public var fontSize: Double?
        public var windowPaddingX: Double?
        public var windowPaddingY: Double?
        /// Source gamut of the authored theme colors. Missing values from v1 documents default
        /// to sRGB so existing community themes and shared files keep loading.
        public var sourceColorSpace: SourceColorSpace
        public var appearance: AppearanceKind?
        public var supportsWideGamut: Bool
        public var contrastGrade: ContrastGrade?
        /// When true, importing applies the full ANSI palette to terminal output (the
        /// "sync" mode); when false/nil the terminal keeps its standalone palette.
        public var applyToTerminalOutput: Bool?

        public init(
            backgroundOpacity: Double? = nil,
            backgroundBlur: Int? = nil,
            fontFamily: String? = nil,
            fontSize: Double? = nil,
            windowPaddingX: Double? = nil,
            windowPaddingY: Double? = nil,
            sourceColorSpace: SourceColorSpace = .sRGB,
            appearance: AppearanceKind? = nil,
            supportsWideGamut: Bool = false,
            contrastGrade: ContrastGrade? = nil,
            applyToTerminalOutput: Bool? = nil
        ) {
            self.backgroundOpacity = backgroundOpacity
            self.backgroundBlur = backgroundBlur
            self.fontFamily = fontFamily
            self.fontSize = fontSize
            self.windowPaddingX = windowPaddingX
            self.windowPaddingY = windowPaddingY
            self.sourceColorSpace = sourceColorSpace
            self.appearance = appearance
            self.supportsWideGamut = supportsWideGamut
            self.contrastGrade = contrastGrade
            self.applyToTerminalOutput = applyToTerminalOutput
        }

        private enum CodingKeys: String, CodingKey {
            case backgroundOpacity
            case backgroundBlur
            case fontFamily
            case fontSize
            case windowPaddingX
            case windowPaddingY
            case sourceColorSpace
            case appearance
            case supportsWideGamut
            case contrastGrade
            case applyToTerminalOutput
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity)
            backgroundBlur = try container.decodeIfPresent(Int.self, forKey: .backgroundBlur)
            fontFamily = try container.decodeIfPresent(String.self, forKey: .fontFamily)
            fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize)
            windowPaddingX = try container.decodeIfPresent(Double.self, forKey: .windowPaddingX)
            windowPaddingY = try container.decodeIfPresent(Double.self, forKey: .windowPaddingY)
            sourceColorSpace = try container.decodeIfPresent(SourceColorSpace.self, forKey: .sourceColorSpace) ?? .sRGB
            appearance = try container.decodeIfPresent(AppearanceKind.self, forKey: .appearance)
            supportsWideGamut = try container.decodeIfPresent(Bool.self, forKey: .supportsWideGamut) ?? false
            contrastGrade = try container.decodeIfPresent(ContrastGrade.self, forKey: .contrastGrade)
            applyToTerminalOutput = try container.decodeIfPresent(Bool.self, forKey: .applyToTerminalOutput)
        }
    }

    // MARK: - Conversion

    /// Build a document from a catalog definition (colors only) plus optional appearance.
    public init(
        definition: HarnessThemeDefinition,
        appearance: Appearance? = nil,
        author: String? = nil
    ) {
        self.init(
            name: definition.name,
            author: author,
            colors: Colors(
                background: definition.background,
                foreground: definition.foreground,
                cursor: definition.cursor,
                cursorText: definition.cursorText,
                selectionBackground: definition.selectionBackground,
                selectionForeground: definition.selectionForeground,
                bold: definition.bold,
                palette: definition.palette
            ),
            appearance: appearance
        )
    }

    /// The colors as a catalog definition (drops appearance).
    public var themeDefinition: HarnessThemeDefinition {
        HarnessThemeDefinition(
            name: name,
            background: colors.background,
            foreground: colors.foreground,
            cursor: colors.cursor,
            cursorText: colors.cursorText,
            selectionBackground: colors.selectionBackground,
            selectionForeground: colors.selectionForeground,
            bold: colors.bold,
            palette: colors.palette
        )
    }

    // MARK: - Encode / decode / validate

    /// Pretty, deterministic JSON suitable for sharing and diffing.
    public func encoded() throws -> Data {
        try validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// Decode and validate a document from `.harnesstheme` bytes.
    public static func decoded(from data: Data) throws -> ThemeDocument {
        let doc: ThemeDocument
        do {
            doc = try JSONDecoder().decode(ThemeDocument.self, from: data)
        } catch let error as ThemeDocumentError {
            throw error
        } catch {
            throw ThemeDocumentError.malformed(String(describing: error))
        }
        try doc.validated()
        return doc
    }

    /// Enforce invariants: supported version, non-empty name, exactly 16 palette entries.
    public func validated() throws {
        guard version >= 1, version <= ThemeDocument.currentVersion else {
            throw ThemeDocumentError.unsupportedVersion(version)
        }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ThemeDocumentError.emptyName
        }
        guard colors.palette.count == 16 else {
            throw ThemeDocumentError.wrongPaletteCount(colors.palette.count)
        }
    }
}
