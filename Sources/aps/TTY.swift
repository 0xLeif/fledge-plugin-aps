import Foundation

/// Minimal TTY awareness (issue #33, git porcelain rule): pretty for humans
/// when interactive, frozen plain output when piped. Machine shapes never
/// carry ANSI; human styling is additive only.
#if os(Windows)
import ucrt
#endif

enum TTY {
    /// True when stdout is a terminal (not a pipe or file).
    /// Windows uses MSVCRT `_isatty`/`_fileno` (FileHandle.fileDescriptor
    /// is unavailable there).
    static var stdoutIsTTY: Bool {
        #if os(Windows)
        return _isatty(_fileno(stdout)) != 0
        #else
        return isatty(FileHandle.standardOutput.fileDescriptor) == 1
        #endif
    }

    /// True when stderr is a terminal.
    static var stderrIsTTY: Bool {
        #if os(Windows)
        return _isatty(_fileno(stderr)) != 0
        #else
        return isatty(FileHandle.standardError.fileDescriptor) == 1
        #endif
    }

    /// Color is emitted only on a TTY and never when NO_COLOR is set (any value).
    static var colorEnabled: Bool {
        stdoutIsTTY && ProcessInfo.processInfo.environment["NO_COLOR"] == nil
    }

    enum Style {
        static func bold(_ text: String) -> String { apply("\u{1B}[1m", to: text) }
        static func red(_ text: String) -> String { apply("\u{1B}[31m", to: text) }
        static func green(_ text: String) -> String { apply("\u{1B}[32m", to: text) }

        private static func apply(_ escape: String, to text: String) -> String {
            guard TTY.colorEnabled else { return text }
            return escape + text + "\u{1B}[0m"
        }
    }

    /// Aligned columns for human tables (e.g. `keys` on a TTY).
    /// Pads every column except the last to the widest row plus two spaces.
    static func table(header: [String], rows: [[String]]) -> String {
        let all = [header] + rows
        let widths = header.indices.map { column in
            all.map { $0.count > column ? $0[column].count : 0 }.max() ?? 0
        }
        func line(_ cells: [String]) -> String {
            cells.enumerated().map { index, cell in
                index == cells.count - 1
                    ? cell
                    : cell.padding(toLength: widths[index] + 2, withPad: " ", startingAt: 0)
            }.joined()
        }
        let lines = [Style.bold(line(header))] + rows.map { line($0) }
        return lines.joined(separator: "\n")
    }
}
