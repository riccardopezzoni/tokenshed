import Foundation

public struct OllamaBackend: LocalLanguageModel {
    public let name: String

    private let host: URL
    private let model: String
    private let session: URLSession

    public init(
        host: URL = URL(string: "http://127.0.0.1:11434")!,
        model: String = "llama3.2:3b",
        session: URLSession = .shared
    ) {
        self.host = host
        self.model = model
        self.session = session
        self.name = "ollama/\(model)"
    }

    public func isAvailable() async -> Bool {
        do {
            let url = host.appending(path: "api/tags")
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    public func summarize(request: SummaryRequest) async throws -> String {
        let excerpts = request.chunks.prefix(8).map {
            "Lines \($0.startLine)-\($0.endLine):\n\($0.text)"
        }.joined(separator: "\n\n---\n\n")

        let prompt = """
        You are a local coding-log condenser. Summarize the relevant failure from
        this output. Preserve exact file names, line numbers, exception names, and
        command names. Do not invent details.

        Output:
        1. Primary failure
        2. Likely cause, if clear
        3. Relevant excerpts to send to a coding agent
        4. Suggested prompt for Codex or Claude Code

        Use plain text. Do not use Markdown code fences.

        Excerpts:
        \(excerpts)
        """

        let url = host.appending(path: "api/generate")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(GenerateRequest(
            model: model,
            prompt: prompt,
            stream: false
        ))

        let (data, response) = try await session.data(for: urlRequest)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw TokenShedError.backendUnavailable("Ollama returned a non-200 response.")
        }

        return try JSONDecoder().decode(GenerateResponse.self, from: data).response
    }

    private struct GenerateRequest: Encodable {
        let model: String
        let prompt: String
        let stream: Bool
    }

    private struct GenerateResponse: Decodable {
        let response: String
    }
}
