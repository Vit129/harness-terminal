import Foundation

public enum ThemeDiagnostics {
    private static let esc = "\u{1B}["
    private static let reset = "\u{1B}[0m"

    public static func colorCheck() -> String {
        var lines: [String] = [
            "Harness color-check",
            "ANSI 0-15",
        ]
        lines.append(ansiSwatches())
        lines.append("")
        lines.append("256-color cube")
        lines.append(colorCube())
        lines.append("")
        lines.append("Grayscale ramp")
        lines.append(grayscaleRamp())
        lines.append("")
        lines.append("Truecolor primaries")
        lines.append(truecolorPrimaries())
        lines.append("")
        lines.append("Gradients")
        lines.append(gradient(name: "black_to_red", red: 255, green: 0, blue: 0))
        lines.append(gradient(name: "black_to_green", red: 0, green: 255, blue: 0))
        lines.append(gradient(name: "black_to_blue", red: 0, green: 0, blue: 255))
        lines.append(gradient(name: "black_to_white", red: 255, green: 255, blue: 255))
        lines.append("")
        lines.append("Text attributes")
        lines.append("\(esc)1mbold\(reset) \(esc)2mfaint\(reset) \(esc)3mitalic\(reset) \(esc)4munderline\(reset) \(esc)7minverse\(reset)")
        lines.append("")
        lines.append("Foreground/background combinations")
        lines.append("\(esc)38;5;15;48;5;1m fg15/bg1 \(reset) \(esc)38;5;0;48;5;3m fg0/bg3 \(reset) \(esc)38;2;255;255;255;48;2;0;64;128m truecolor fg/bg \(reset)")
        return lines.joined(separator: "\n") + "\n"
    }

    public static func themePreview(_ theme: HarnessThemeDefinition) -> String {
        let lines: [String] = [
            "Harness theme-preview",
            "Theme: \(theme.name)",
            "PROMPTS",
            "\(fg(theme.palette[10]))user@mac\(reset) \(fg(theme.palette[12]))~/Code/harness\(reset) \(fg(theme.palette[13]))git:(main)\(reset) $ swift test",
            "\(fg(theme.foreground))harness-cli attach-window --session work\(reset)",
            "",
            "GIT / BUILD",
            "\(fg(theme.palette[2]))[ok]\(reset) branch main is clean",
            "\(fg(theme.palette[3]))[warn]\(reset) 2 files changed, review before commit",
            "\(fg(theme.palette[1]))[fail]\(reset) Tests failed in HarnessTerminalRendererTests",
            "\(fg(theme.palette[4]))[info]\(reset) Renderer stats: cells=7680 glyphs=7680 bg=7680",
            "",
            "DIAGNOSTICS",
            "\(fg(theme.palette[1]))error:\(reset) missing required --surface id",
            "\(fg(theme.palette[3]))warning:\(reset) fallback font used for one glyph",
            "\(fg(theme.palette[4]))info:\(reset) colorRendering=accurate sourceColorSpace=sRGB",
            "",
            "AGENTS",
            "\(fg(theme.palette[6]))running\(reset) codex is editing renderer tests",
            "\(fg(theme.palette[3]))waiting for approval\(reset) claude-code requests shell access",
            "\(fg(theme.palette[1]))failed\(reset) cursor hook returned exit 1",
            "\(fg(theme.palette[2]))complete\(reset) pi finished build summary",
            "",
            "SELECTION / SEARCH",
            "\(bg(theme.selectionBackground ?? theme.palette[4]))\(fg(theme.selectionForeground ?? theme.foreground)) selected text \(reset)",
            "\(bg(theme.palette[3]))\(fg(theme.background)) search hit \(reset)",
            "",
            "ANSI SWATCHES",
            themePaletteSwatches(theme),
        ]
        return lines.joined(separator: "\n") + "\n"
    }

    private static func ansiSwatches() -> String {
        (0 ..< 16).map { index in
            let code = index < 8 ? 40 + index : 100 + (index - 8)
            return String(format: "%2d %@  %@", index, "\(esc)\(code)m", reset)
        }.joined(separator: " ")
    }

    private static func colorCube() -> String {
        var rows: [String] = []
        for r in 0 ..< 6 {
            for g in 0 ..< 6 {
                var row = ""
                for b in 0 ..< 6 {
                    let index = 16 + (36 * r) + (6 * g) + b
                    row += "\(esc)48;5;\(index)m  \(reset)"
                }
                rows.append(row)
            }
            if r != 5 { rows.append("") }
        }
        return rows.joined(separator: "\n")
    }

    private static func grayscaleRamp() -> String {
        (232 ... 255).map { "\(esc)48;5;\($0)m  \(reset)" }.joined()
    }

    private static func truecolorPrimaries() -> String {
        [
            ("red", 255, 0, 0),
            ("green", 0, 255, 0),
            ("blue", 0, 0, 255),
            ("cyan", 0, 255, 255),
            ("magenta", 255, 0, 255),
            ("yellow", 255, 255, 0),
            ("white", 255, 255, 255),
        ].map { name, r, g, b in
            "\(esc)48;2;\(r);\(g);\(b)m \(name) \(reset)"
        }.joined(separator: " ")
    }

    private static func gradient(name: String, red: Int, green: Int, blue: Int) -> String {
        var line = "\(name) "
        for step in 0 ... 15 {
            let fraction = Double(step) / 15.0
            let r = Int((Double(red) * fraction).rounded())
            let g = Int((Double(green) * fraction).rounded())
            let b = Int((Double(blue) * fraction).rounded())
            line += "\(esc)48;2;\(r);\(g);\(b)m  \(reset)"
        }
        return line
    }

    private static func themePaletteSwatches(_ theme: HarnessThemeDefinition) -> String {
        theme.palette.enumerated().map { index, color in
            String(format: "%2d ", index) + "\(bg(color))  \(reset)"
        }.joined(separator: " ")
    }

    private static func fg(_ color: RGBColor) -> String {
        "\(esc)38;2;\(color.red);\(color.green);\(color.blue)m"
    }

    private static func bg(_ color: RGBColor) -> String {
        "\(esc)48;2;\(color.red);\(color.green);\(color.blue)m"
    }
}
