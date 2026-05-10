import Foundation

public struct LogChunker: Sendable {
    public let windowSize: Int
    public let contextRadius: Int

    public init(windowSize: Int = 80, contextRadius: Int = 5) {
        self.windowSize = windowSize
        self.contextRadius = contextRadius
    }

    public func chunks(from text: String) -> [ContextChunk] {
        let lines = text.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return [] }

        let signalLines = lines.indices.compactMap { index -> Int? in
            let signals = Self.signals(in: lines[index])
            return signals.isEmpty ? nil : index
        }

        if signalLines.isEmpty {
            return stride(from: 0, to: lines.count, by: windowSize).map { start in
                makeChunk(lines: lines, start: start, end: min(start + windowSize - 1, lines.count - 1))
            }
        }

        var ranges: [ClosedRange<Int>] = []
        for index in signalLines {
            let start = max(0, index - contextRadius)
            let end = min(lines.count - 1, index + contextRadius)
            if let last = ranges.last, start <= last.upperBound + 1 {
                ranges[ranges.count - 1] = last.lowerBound...max(last.upperBound, end)
            } else {
                ranges.append(start...end)
            }
        }

        return ranges.map { range in
            makeChunk(lines: lines, start: range.lowerBound, end: range.upperBound)
        }.sorted { $0.score > $1.score }
    }

    private func makeChunk(lines: [String], start: Int, end: Int) -> ContextChunk {
        let slice = lines[start...end]
        let signals = Array(Set(slice.flatMap(Self.signals))).sorted { $0.rawValue < $1.rawValue }
        let score = Self.score(signals: signals, text: slice.joined(separator: "\n"))

        return ContextChunk(
            text: slice.joined(separator: "\n"),
            startLine: start + 1,
            endLine: end + 1,
            signals: signals,
            score: score
        )
    }

    private static func signals(in line: String) -> [ContextSignal] {
        let lower = line.lowercased()
        var signals: [ContextSignal] = []

        if lower.contains("error") || lower.contains("fatal") || lower.contains("panic") {
            signals.append(.error)
        }
        if lower.contains("fail") {
            signals.append(.failure)
        }
        if lower.contains("exception") || lower.contains("caused by") || lower.contains("traceback") {
            signals.append(.exception)
        }
        if line.range(of: #"^\s+at\s+[\w.$_]+\("#, options: .regularExpression) != nil {
            signals.append(.stackTrace)
        }
        if line.range(of: #"\b\w+\.(swift|kt|java|js|ts|tsx|py|go|rs|c|cpp|m):\d+"#, options: .regularExpression) != nil {
            signals.append(.fileReference)
            signals.append(.compilerDiagnostic)
        }
        if lower.contains("test") && lower.contains("fail") {
            signals.append(.testFailure)
        }

        return signals
    }

    private static func score(signals: [ContextSignal], text: String) -> Double {
        var score = Double(signals.count)
        if signals.contains(.exception) { score += 2.0 }
        if signals.contains(.testFailure) { score += 1.5 }
        if signals.contains(.compilerDiagnostic) { score += 1.5 }
        if text.lowercased().contains("root cause") { score += 1.0 }
        return score
    }
}

