import Foundation

public enum VeqralInteractionKind: String, Codable, Sendable, Equatable {
    case choice
    case message
}

public struct VeqralInteractionChoice: Codable, Sendable, Equatable {
    public var value: String
    public var label: String

    public init(value: String, label: String) {
        self.value = value
        self.label = label
    }
}

public struct VeqralDetectedInteraction: Codable, Sendable, Equatable {
    public var kind: VeqralInteractionKind
    public var prompt: String
    public var choices: [VeqralInteractionChoice]

    public init(kind: VeqralInteractionKind, prompt: String, choices: [VeqralInteractionChoice] = []) {
        self.kind = kind
        self.prompt = prompt
        self.choices = choices
    }
}

public enum VeqralInteractionDetector {
    public static func detect(in text: String) -> VeqralDetectedInteraction? {
        let lines = cleanedLines(from: text)
        guard !lines.isEmpty else { return nil }

        let optionMatches = lines.enumerated().compactMap { index, line -> (Int, VeqralInteractionChoice)? in
            guard let choice = choice(from: line) else { return nil }
            return (index, choice)
        }
        if optionMatches.count >= 2 {
            let firstChoiceIndex = optionMatches[0].0
            let prompt = promptLine(before: firstChoiceIndex, in: lines) ?? lines.first ?? "Choose an option"
            return VeqralDetectedInteraction(
                kind: .choice,
                prompt: prompt,
                choices: optionMatches.map(\.1)
            )
        }

        let joined = lines.joined(separator: "\n")
        let lower = joined.lowercased()
        if isFreeformPrompt(lower) {
            return VeqralDetectedInteraction(kind: .message, prompt: joined, choices: [])
        }
        return nil
    }

    private static func cleanedLines(from text: String) -> [String] {
        text
            .replacingOccurrences(of: #"\u001B\[[0-9;?]*[ -/]*[@-~]"#, with: "", options: .regularExpression)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func choice(from line: String) -> VeqralInteractionChoice? {
        let patterns = [
            #"^\[([0-9A-Za-z])\]\s+(.+)$"#,
            #"^\(?([0-9A-Za-z])\)?[\.)]\s+(.+)$"#,
            #"^-\s*([0-9A-Za-z])\s*[:\-]\s+(.+)$"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = regex.firstMatch(in: line, range: range), match.numberOfRanges == 3,
                  let valueRange = Range(match.range(at: 1), in: line),
                  let labelRange = Range(match.range(at: 2), in: line) else { continue }
            let value = String(line[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let label = String(line[labelRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, !label.isEmpty else { continue }
            return VeqralInteractionChoice(value: value, label: String(label.prefix(160)))
        }
        return nil
    }

    private static func promptLine(before firstChoiceIndex: Int, in lines: [String]) -> String? {
        guard firstChoiceIndex > 0 else { return nil }
        let noise = ["choose", "select", "enter choice", "pick", "option", "選択", "番号"]
        return lines[..<firstChoiceIndex].reversed().first { line in
            let lower = line.lowercased()
            guard choice(from: line) == nil else { return false }
            return !noise.contains { lower == $0 || lower.hasPrefix($0 + ":") }
        }
    }

    private static func isFreeformPrompt(_ lower: String) -> Bool {
        let markers = [
            "please type your answer",
            "type your answer",
            "enter your answer",
            "send a message",
            "enter a message",
            "reply with",
            "waiting for user",
            "need input",
            "question:",
            "回答してください",
            "入力してください",
            "メッセージを送",
            "返答してください",
            "質問:"
        ]
        return markers.contains { lower.contains($0) }
    }
}
