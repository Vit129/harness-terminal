import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Single source of truth for app-wide keyboard shortcuts.
/// Both `MainMenuBuilder` (menu key equivalents) and the terminal welcome banner
/// read from this registry — change once, reflected everywhere.
public struct BannerShortcut: Codable, Sendable {
    public let key: String
    public let description: String
    public let showInBanner: Bool

    public init(key: String, description: String, showInBanner: Bool = true) {
        self.key = key
        self.description = description
        self.showInBanner = showInBanner
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        description = try c.decode(String.self, forKey: .description)
        showInBanner = try c.decodeIfPresent(Bool.self, forKey: .showInBanner) ?? true
    }

    private enum CodingKeys: String, CodingKey {
        case key, description, showInBanner
    }
}

// MARK: - Structured keybinding

/// A modifier set that maps to both display glyphs and NSEvent.ModifierFlags.
public struct MenuModifiers: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let command = MenuModifiers(rawValue: 1 << 0)
    public static let shift   = MenuModifiers(rawValue: 1 << 1)
    public static let option  = MenuModifiers(rawValue: 1 << 2)
    public static let control = MenuModifiers(rawValue: 1 << 3)

    /// Display string: "⌘⇧⌥⌃" order matches macOS convention.
    public var displayString: String {
        var s = ""
        if contains(.command) { s += "⌘" }
        if contains(.shift)   { s += "⇧" }
        if contains(.option)  { s += "⌥" }
        if contains(.control) { s += "⌃" }
        return s
    }

    #if canImport(AppKit)
    public var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if contains(.command) { flags.insert(.command) }
        if contains(.shift)   { flags.insert(.shift) }
        if contains(.option)  { flags.insert(.option) }
        if contains(.control) { flags.insert(.control) }
        return flags
    }
    #endif
}

/// A single keybinding that both menu and banner can consume.
public struct Keybinding: Sendable {
    /// The identifier used to look up this binding (e.g. "newSession", "closePane").
    public let id: String
    /// Human-readable menu title.
    public let title: String
    /// Modifier keys.
    public let modifiers: MenuModifiers
    /// The key character for NSMenuItem.keyEquivalent (lowercase letter, or special char).
    public let keyChar: String
    /// Human-readable key label for banner display (e.g. "T", "⇧W", "←").
    /// If nil, derived from keyChar uppercased.
    public let keyLabel: String?
    /// Whether to show on the welcome banner.
    public let showInBanner: Bool

    public init(
        id: String, title: String,
        modifiers: MenuModifiers, keyChar: String,
        keyLabel: String? = nil, showInBanner: Bool = true
    ) {
        self.id = id
        self.title = title
        self.modifiers = modifiers
        self.keyChar = keyChar
        self.keyLabel = keyLabel
        self.showInBanner = showInBanner
    }

    /// Full display string for banner/UI: "⌘T", "⌘⇧W", "⌘←"
    public var displayKey: String {
        modifiers.displayString + (keyLabel ?? keyChar.uppercased())
    }
}

// MARK: - Registry

public enum BannerShortcutRegistry {
    // MARK: Keybindings — THE single source of truth

    public static let newSession = Keybinding(
        id: "newSession", title: "New Session",
        modifiers: .command, keyChar: "t")

    public static let closePane = Keybinding(
        id: "closePane", title: "Close Pane",
        modifiers: .command, keyChar: "w")

    public static let closeTab = Keybinding(
        id: "closeTab", title: "Close Tab",
        modifiers: [.command, .shift], keyChar: "w")

    public static let splitRight = Keybinding(
        id: "splitRight", title: "Split Right",
        modifiers: .command, keyChar: "d")

    public static let splitDown = Keybinding(
        id: "splitDown", title: "Split Down",
        modifiers: [.command, .shift], keyChar: "d")

    public static let previousPane = Keybinding(
        id: "previousPane", title: "Previous Pane",
        modifiers: .command, keyChar: "[")

    public static let nextPane = Keybinding(
        id: "nextPane", title: "Next Pane",
        modifiers: .command, keyChar: "]")

    public static let previousSession = Keybinding(
        id: "previousSession", title: "Previous Session",
        modifiers: [.command, .shift], keyChar: "[")

    public static let nextSession = Keybinding(
        id: "nextSession", title: "Next Session",
        modifiers: [.command, .shift], keyChar: "]")

    public static let moveSessionLeft = Keybinding(
        id: "moveSessionLeft", title: "Move Session Left",
        modifiers: .command, keyChar: "\u{F702}", keyLabel: "←")

    public static let moveSessionRight = Keybinding(
        id: "moveSessionRight", title: "Move Session Right",
        modifiers: .command, keyChar: "\u{F703}", keyLabel: "→")

    public static let commandPalette = Keybinding(
        id: "commandPalette", title: "Command Palette",
        modifiers: .command, keyChar: "p")

    public static let scrollbackSearch = Keybinding(
        id: "scrollbackSearch", title: "Find in Scrollback",
        modifiers: .command, keyChar: "f")

    public static let findInFiles = Keybinding(
        id: "findInFiles", title: "Find in Files…",
        modifiers: [.command, .shift], keyChar: "f")

    public static let browserPane = Keybinding(
        id: "browserPane", title: "Open Browser Pane",
        modifiers: .command, keyChar: "b")

    public static let commandPrompt = Keybinding(
        id: "commandPrompt", title: "Command Prompt",
        modifiers: .command, keyChar: ";")

    public static let toggleSidebar = Keybinding(
        id: "toggleSidebar", title: "Toggle Sidebar",
        modifiers: .command, keyChar: "\\")

    public static let runScript = Keybinding(
        id: "runScript", title: "Run Script",
        modifiers: .command, keyChar: "r")

    public static let stopScript = Keybinding(
        id: "stopScript", title: "Stop Script",
        modifiers: .command, keyChar: ".")

    public static let hintMode = Keybinding(
        id: "hintMode", title: "Hint Mode (Open Link)",
        modifiers: [.command, .shift], keyChar: "u")

    public static let composer = Keybinding(
        id: "composer", title: "Composer",
        modifiers: [.command, .shift], keyChar: "e",
        showInBanner: false)

    public static let recipes = Keybinding(
        id: "recipes", title: "Recipes…",
        modifiers: [.command, .shift], keyChar: "r",
        showInBanner: false)

    public static let jumpToDirectory = Keybinding(
        id: "jumpToDirectory", title: "Jump to Directory…",
        modifiers: [.command, .shift], keyChar: "j",
        showInBanner: false)

    public static let toggleViMode = Keybinding(
        id: "toggleViMode", title: "Toggle Vi Mode",
        modifiers: [.command, .control], keyChar: "v",
        showInBanner: false)

    public static let floatingPane = Keybinding(
        id: "floatingPane", title: "Floating Terminal",
        modifiers: [.command, .option], keyChar: "f",
        showInBanner: false)

    public static let tabOverview = Keybinding(
        id: "tabOverview", title: "Tab Overview",
        modifiers: [.command, .shift], keyChar: "\\",
        showInBanner: false)

    public static let forkTab = Keybinding(
        id: "forkTab", title: "Fork Tab",
        modifiers: [.command, .shift], keyChar: "k",
        showInBanner: false)

    // MARK: - Banner shortcuts (legacy format for terminal banner rendering)

    /// All registered shortcuts for banner display, derived from keybindings above.
    public static let shortcuts: [BannerShortcut] = [
        .init(key: "", description: "Sessions", showInBanner: true),
        .init(key: "\(newSession.displayKey)", description: "new tab"),
        .init(key: "\(splitRight.displayKey) / \(splitDown.displayKey)", description: "split right / split down"),
        .init(key: "\(closePane.displayKey) / \(closeTab.displayKey)", description: "close pane (or tab) / force close tab"),
        .init(key: "", description: "Navigation", showInBanner: true),
        .init(key: "⌘1–9 / ⌘⇧[ / ⌘⇧]", description: "switch / prev / next session"),
        .init(key: "\(previousPane.displayKey) / \(nextPane.displayKey) / ⌘←→", description: "navigate & reorder panes"),
        .init(key: "", description: "Search & Navigate", showInBanner: true),
        .init(key: commandPalette.displayKey, description: "fuzzy file / directory jump (zoxide)"),
        .init(key: jumpToDirectory.displayKey, description: "frecency dir picker — ↩ cd · ⌘↩ new tab (zoxide)"),
        .init(key: recipes.displayKey, description: "run a saved command recipe"),
        .init(key: findInFiles.displayKey, description: "find in files"),
        .init(key: "\(commandPrompt.displayKey)", description: "command prompt · try: find, grep, cd"),
        .init(key: "", description: "Shell", showInBanner: true),
        .init(key: "z <dir>", description: "smart cd — same list as ⌘⇧J"),
        .init(key: "fd <pattern>", description: "find files by name"),
        .init(key: "rg <pattern>", description: "search file contents (ripgrep)"),
        .init(key: "bat <file>", description: "cat with syntax highlighting + line numbers"),
        .init(key: "eza --git", description: "modern ls — colors, icons, git status"),
        .init(key: "jq '.key'", description: "parse & query JSON"),
        .init(key: "ctrl+r", description: "fuzzy shell history search (fzf)"),
        .init(key: "ctrl+t", description: "fuzzy pick file → paste path (fzf)"),
        .init(key: "fd | fzf", description: "find → narrow — pipe anything into fzf"),
        .init(key: "kouen-cli ping", description: "script Kouen from any shell"),
        .init(key: "kouen cc run", description: "run Claude Code headlessly, no pane needed"),
    ]

    /// Only shortcuts flagged for the banner.
    public static var bannerShortcuts: [BannerShortcut] {
        shortcuts.filter(\.showInBanner)
    }
}
