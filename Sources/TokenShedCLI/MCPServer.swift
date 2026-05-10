import TokenShedCore
import Foundation

struct MCPServer {
    func run() async throws {
        while let line = readLine(strippingNewline: true) {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            do {
                if let response = try await handle(line) {
                    write(response)
                }
            } catch {
                let request = try? JSONDecoder().decode(JSONRPCRequest.self, from: Data(line.utf8))
                write(JSONRPCResponse(
                    id: request?.id ?? .null,
                    result: nil,
                    error: JSONRPCError(code: -32603, message: error.localizedDescription)
                ))
            }
        }
    }

    private func handle(_ line: String) async throws -> JSONRPCResponse? {
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: Data(line.utf8))

        switch request.method {
        case "initialize":
            return JSONRPCResponse(id: request.id, result: initializeResult(for: request), error: nil)
        case "notifications/initialized":
            return nil
        case "ping":
            return JSONRPCResponse(id: request.id, result: .object([:]), error: nil)
        case "tools/list":
            return JSONRPCResponse(id: request.id, result: toolsListResult(), error: nil)
        case "tools/call":
            return JSONRPCResponse(id: request.id, result: try await callTool(params: request.params), error: nil)
        default:
            return JSONRPCResponse(
                id: request.id,
                result: nil,
                error: JSONRPCError(code: -32601, message: "Unknown method: \(request.method)")
            )
        }
    }

    private func initializeResult(for request: JSONRPCRequest) -> JSONValue {
        let protocolVersion = request.params?.objectValue?["protocolVersion"]?.stringValue ?? "2024-11-05"

        return .object([
            "protocolVersion": .string(protocolVersion),
            "capabilities": .object([
                "tools": .object([:])
            ]),
            "serverInfo": .object([
                "name": .string("tokenshed"),
                "version": .string("1.0.0")
            ])
        ])
    }

    private func toolsListResult() -> JSONValue {
        .object([
            "tools": .array([
                tool(
                    name: "summarize_log",
                    description: "Summarize noisy logs locally and return relevant excerpts, redactions, and a suggested coding-agent prompt.",
                    required: ["text"],
                    properties: [
                        "text": .object(["type": .string("string")]),
                        "backend": .object(["type": .string("string"), "enum": .array(BackendKind.allCases.map { .string($0.rawValue) })]),
                        "budgetTokens": .object(["type": .string("integer"), "default": .number(2500)])
                    ]
                ),
                tool(
                    name: "extract_failures",
                    description: "Extract likely failure chunks from logs without using a language model.",
                    required: ["text"],
                    properties: [
                        "text": .object(["type": .string("string")])
                    ]
                ),
                tool(
                    name: "redact_text",
                    description: "Redact API keys, bearer tokens, JWTs, and env-style secrets locally.",
                    required: ["text"],
                    properties: [
                        "text": .object(["type": .string("string")])
                    ]
                ),
                tool(
                    name: "prepare_debug_prompt",
                    description: "Prepare a compact prompt for Codex or Claude Code from noisy local output.",
                    required: ["text"],
                    properties: [
                        "text": .object(["type": .string("string")]),
                        "backend": .object(["type": .string("string"), "enum": .array(BackendKind.allCases.map { .string($0.rawValue) })]),
                        "budgetTokens": .object(["type": .string("integer"), "default": .number(2500)])
                    ]
                )
            ])
        ])
    }

    private func tool(name: String, description: String, required: [String], properties: [String: JSONValue]) -> JSONValue {
        .object([
            "name": .string(name),
            "description": .string(description),
            "inputSchema": .object([
                "type": .string("object"),
                "required": .array(required.map { .string($0) }),
                "properties": .object(properties)
            ])
        ])
    }

    private func callTool(params: JSONValue?) async throws -> JSONValue {
        guard let params = params?.objectValue,
              let name = params["name"]?.stringValue else {
            throw CLIError("Missing MCP tool name.")
        }

        let arguments = params["arguments"]?.objectValue ?? [:]

        switch name {
        case "summarize_log":
            let result = try await summarize(arguments: arguments)
            recordMetrics(result.metrics)
            return textContent(MarkdownRenderer().render(result.summary))
        case "extract_failures":
            let text = try requiredString("text", in: arguments)
            let redacted = SecretRedactor().redact(text)
            let chunks = LogChunker().chunks(from: redacted.text).prefix(10)
            let body = chunks.map {
                "Lines \($0.startLine)-\($0.endLine):\n\($0.text)"
            }.joined(separator: "\n\n---\n\n")
            return textContent(body.isEmpty ? "No obvious failure signals found." : body)
        case "redact_text":
            let text = try requiredString("text", in: arguments)
            return textContent(SecretRedactor().redact(text).text)
        case "prepare_debug_prompt":
            let result = try await summarize(arguments: arguments)
            recordMetrics(result.metrics)
            return textContent(result.summary.suggestedPrompt)
        default:
            throw CLIError("Unknown MCP tool: \(name)")
        }
    }

    private func summarize(arguments: [String: JSONValue]) async throws -> MetricsResult {
        let text = try requiredString("text", in: arguments)
        let backend = backend(from: arguments["backend"]?.stringValue)
        let budget = arguments["budgetTokens"]?.intValue ?? 2500

        return try await MetricsRunner().run(
            document: ContextDocument(source: .inline, rawText: text),
            options: SummaryOptions(backend: backend, budgetTokens: budget)
        )
    }

    private func backend(from rawValue: String?) -> BackendKind {
        guard let rawValue, let backend = BackendKind(rawValue: rawValue) else {
            return .auto
        }

        return backend
    }

    private func requiredString(_ key: String, in arguments: [String: JSONValue]) throws -> String {
        guard let value = arguments[key]?.stringValue else {
            throw CLIError("Missing required string argument: \(key)")
        }

        return value
    }

    private func textContent(_ text: String) -> JSONValue {
        .object([
            "content": .array([
                .object([
                    "type": .string("text"),
                    "text": .string(text)
                ])
            ])
        ])
    }

    private func write(_ response: JSONRPCResponse) {
        guard let data = try? JSONEncoder().encode(response),
              let line = String(data: data, encoding: .utf8) else {
            return
        }

        FileHandle.standardOutput.write(Data((line + "\n").utf8))
    }

    private func recordMetrics(_ metrics: SummaryMetrics) {
        do {
            try MetricsStore().append(metrics)
        } catch {
            FileHandle.standardError.write(Data("tokenshed: could not record metrics: \(error.localizedDescription)\n".utf8))
        }
    }
}

struct JSONRPCRequest: Decodable {
    let id: JSONValue
    let method: String
    let params: JSONValue?

    private enum CodingKeys: String, CodingKey {
        case id
        case method
        case params
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(JSONValue.self, forKey: .id) ?? .null
        method = try container.decode(String.self, forKey: .method)
        params = try container.decodeIfPresent(JSONValue.self, forKey: .params)
    }
}

struct JSONRPCResponse: Encodable {
    let jsonrpc = "2.0"
    let id: JSONValue
    let result: JSONValue?
    let error: JSONRPCError?
}

struct JSONRPCError: Encodable {
    let code: Int
    let message: String
}

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            if value.rounded() == value {
                try container.encode(Int(value))
            } else {
                try container.encode(value)
            }
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self {
            value
        } else {
            nil
        }
    }

    var intValue: Int? {
        if case .number(let value) = self {
            Int(value)
        } else {
            nil
        }
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self {
            value
        } else {
            nil
        }
    }
}
