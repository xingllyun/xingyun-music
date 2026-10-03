import Foundation

/// 统一音乐抽象层协议（§4.3）。
/// UI 与业务层只依赖本协议，永远不直接调用某一家接口。
protocol MusicProvider {
    var id: String { get }
    func capabilities() -> ProviderCapabilities
    func listModels() -> [ModelInfo]
    func generate(_ req: MusicRequest, key: ApiKey) async throws -> MusicResult
    func healthCheck(key: ApiKey) async throws
}

// MARK: - 默认实现

extension MusicProvider {
    /// 默认健康检查：仅校验 Key 非空与格式。额度查询需按各平台官方余额接口扩展。
    func healthCheck(key: ApiKey) async throws {
        guard !key.secret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderError.invalidKey("API Key 为空")
        }
    }
}

// MARK: - 错误定义

enum ProviderError: Error, LocalizedError {
    case invalidKey(String)
    case badResponse(String)
    case platform(code: String, message: String, retryable: Bool)
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .invalidKey(let m): return "Key 无效：\(m)"
        case .badResponse(let m): return "响应异常：\(m)"
        case .platform(let code, let message, _): return "[\(code)] \(message)"
        case .unsupported(let m): return "不支持：\(m)"
        }
    }

    var isRetryable: Bool {
        if case .platform(_, _, let r) = self { return r }
        return false
    }

    /// 从错误中提取 HTTP 状态码（用于 Key 池区分 401/403/429）。
    var failureStatusCode: Int? {
        if case .platform(let code, _, _) = self { return Int(code) }
        return nil
    }
}

// MARK: - Provider 注册表（§4.4）

final class ProviderRegistry {
    static let shared = ProviderRegistry()
    private var providers: [String: MusicProvider] = [:]

    private init() {}

    func register(_ provider: MusicProvider) {
        providers[provider.id] = provider
    }

    func provider(for id: String) -> MusicProvider? {
        providers[id]
    }

    var all: [MusicProvider] {
        providers.values.sorted { $0.id < $1.id }
    }

    /// 已注册的平台 ID 列表
    var registeredIDs: [String] {
        providers.values.map(\.id).sorted()
    }
}

// MARK: - 预留扩展位（§4.4）

/// 未来端侧/本机模型，先空实现。
final class LocalProvider: MusicProvider {
    var id: String { ProviderID.local }

    func capabilities() -> ProviderCapabilities {
        ProviderCapabilities(providerId: id, supportedModes: [], supportedFormats: [],
                             minDurationSec: 0, maxDurationSec: 0, isAsync: false,
                             supportedGenres: [], supportedMoods: [], supportedTimbres: [])
    }

    func listModels() -> [ModelInfo] { [] }

    func generate(_ req: MusicRequest, key: ApiKey) async throws -> MusicResult {
        throw ProviderError.unsupported("本地模型尚未实现")
    }
}

/// 兼容 OpenAI 风格网关，先空实现。
final class GenericOpenAIProvider: MusicProvider {
    var id: String { ProviderID.genericOpenAI }

    func capabilities() -> ProviderCapabilities {
        ProviderCapabilities(providerId: id, supportedModes: [], supportedFormats: [],
                             minDurationSec: 0, maxDurationSec: 0, isAsync: false,
                             supportedGenres: [], supportedMoods: [], supportedTimbres: [])
    }

    func listModels() -> [ModelInfo] { [] }

    func generate(_ req: MusicRequest, key: ApiKey) async throws -> MusicResult {
        throw ProviderError.unsupported("OpenAI 风格网关尚未实现")
    }
}
