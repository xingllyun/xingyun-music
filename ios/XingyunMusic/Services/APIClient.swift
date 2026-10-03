import Foundation

/// HTTP 错误，携带状态码，供 Key 池识别 401/403/429。
struct HTTPError: Error, LocalizedError {
    let statusCode: Int
    let body: String

    var errorDescription: String? {
        "HTTP \(statusCode): \(body)"
    }

    var isAuthFailure: Bool { statusCode == 401 || statusCode == 403 }
    var isRateLimit: Bool { statusCode == 429 }
}

/// 统一网络客户端（URLSession async/await）。
final class APIClient {
    static let shared = APIClient()

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
    }

    /// 直接发送构造好的请求，返回 body 与响应。
    func post(_ request: URLRequest) async throws -> (Data, URLResponse) {
        var req = request
        req.httpMethod = "POST"
        return try await session.data(for: req)
    }

    /// 便捷 JSON POST。
    func postJSON(url: URL, headers: [String: String], body: Data) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProviderError.badResponse("非 HTTP 响应")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw HTTPError(statusCode: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        return (data, http)
    }

    /// 下载二进制（音频）。
    func download(url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw HTTPError(statusCode: code, body: "")
        }
        return data
    }
}

extension ProviderError {
    /// 将 HTTPError 映射为平台错误，供 Key 池判断是否可重试。
    static func http(_ e: HTTPError) -> ProviderError {
        switch e.statusCode {
        case 429: return .platform(code: "429", message: "请求过于频繁，已触发限流", retryable: true)
        case 401, 403: return .platform(code: "\(e.statusCode)", message: "鉴权失败（Key 无效或无权限）", retryable: false)
        case 400: return .platform(code: "400", message: e.body, retryable: false)
        default: return .platform(code: "\(e.statusCode)", message: e.body, retryable: e.statusCode >= 500)
        }
    }
}
