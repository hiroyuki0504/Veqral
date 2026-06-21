import Foundation

public enum VeqralRedactor {
    private static let patterns: [(pattern: String, replacement: String)] = [
        (#"(?i)(authorization\s*[:=]\s*bearer\s+)[^\s'"]+"#, "$1[REDACTED]"),
        (#"(?i)([A-Z0-9_\-]*(?:token|api[_-]?key|secret|password|webhook)[A-Z0-9_\-]*)\s*[:=]\s*['"]?[^'"\s]+"#, "$1=[REDACTED]"),
        (#"https://discord(?:app)?\.com/api/webhooks/[0-9]+/[A-Za-z0-9._\-]+"#, "[REDACTED_DISCORD_WEBHOOK]"),
        (#"(?i)xox[baprs]-[A-Za-z0-9-]+"#, "[REDACTED_SLACK_TOKEN]"),
        (#"(?i)sk-or-[A-Za-z0-9_-]{12,}"#, "[REDACTED_OPENROUTER_KEY]"),
        (#"(?i)sk-[A-Za-z0-9_\-]{12,}"#, "[REDACTED_KEY]"),
        (#"(?i)gh[opusr]_[A-Za-z0-9_]+"#, "[REDACTED_GITHUB_TOKEN]"),
        (#"(?i)github_pat_[A-Za-z0-9_]+"#, "[REDACTED_GITHUB_TOKEN]")
    ]

    public static func redact(_ text: String) -> String {
        patterns.reduce(text) { output, rule in
            output.replacingOccurrences(
                of: rule.pattern,
                with: rule.replacement,
                options: .regularExpression
            )
        }
    }

    public static func redact(_ text: String, limit: Int) -> String {
        let output = redact(text)
        guard output.count > limit else { return output }
        return String(output.prefix(limit)) + "\n...（省略）"
    }
}
