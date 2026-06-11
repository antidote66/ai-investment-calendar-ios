import Foundation

struct WebClient {
    static let shared = WebClient()

    func data(from url: URL, timeout: TimeInterval = 20) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/json,*/*", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }

    func text(from url: URL, timeout: TimeInterval = 20) async throws -> String {
        let data = try await data(from: url, timeout: timeout)
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .init(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))))
            ?? ""
    }
}

enum HTMLTools {
    static func stripTags(_ value: String) -> String {
        let withoutBreaks = value
            .replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")
        let stripped = withoutBreaks.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return decodeEntities(stripped)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(_ value: String) -> String {
        var result = value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#x2f;", with: "/")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")

        let pattern = "&#(x?[0-9A-Fa-f]+);"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return result }
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed()
        for match in matches {
            guard let fullRange = Range(match.range(at: 0), in: result),
                  let numberRange = Range(match.range(at: 1), in: result) else { continue }
            let raw = String(result[numberRange])
            let value: UInt32?
            if raw.lowercased().hasPrefix("x") {
                value = UInt32(raw.dropFirst(), radix: 16)
            } else {
                value = UInt32(raw)
            }
            if let value, let scalar = UnicodeScalar(value) {
                result.replaceSubrange(fullRange, with: String(Character(scalar)))
            }
        }
        return result
    }

    static func matches(_ pattern: String, in text: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { match in
            (0..<match.numberOfRanges).compactMap { index in
                guard let range = Range(match.range(at: index), in: text) else { return nil }
                return String(text[range])
            }
        }
    }
}
