import Foundation

/// 水印校验结果（§9.5 detect）。
struct WatermarkDetectResult: Codable {
    var aiLabel: Bool
    var ownerDev: UInt32
    var ownerMusic: UInt32
    var workId: UInt32
    var confidence: Double?
    var rawPayload: UInt32?
}

private struct EmbedResponse: Codable {
    var audioBase64: String
    var format: String?
    var modelVersion: String?
}

private struct DetectResponse: Codable {
    var aiLabel: Bool
    var ownerDev: UInt32
    var ownerMusic: UInt32
    var workId: UInt32
    var confidence: Double?
    var rawPayload: UInt32?
}

/// 水印微服务客户端（方案 A，§9.3 / §9.5）。
final class WatermarkClient {
    private let settings: AppSettings
    private let client = APIClient.shared

    init(settings: AppSettings) {
        self.settings = settings
    }

    private var baseURL: String {
        settings.watermarkServiceURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    /// 是否已配置水印服务地址。
    var isConfigured: Bool { !baseURL.isEmpty }

    /// 服务端返回 snake_case 字段，统一转换。
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    /// 加水印（同时可按目标格式转码，服务端 FFmpeg 完成）。
    func embed(audioData: Data, payload: WatermarkPayload, targetFormat: String) async throws -> Data {
        let body: [String: Any] = [
            "audio": audioData.base64EncodedString(),
            "payload": payload.encoded,
            "format": targetFormat
        ]
        let json = try JSONSerialization.data(withJSONObject: body)
        let url = try endpoint("/watermark/embed")
        let (data, _) = try await client.postJSON(url: url, headers: ["Content-Type": "application/json"], body: json)
        let resp = try Self.decoder.decode(EmbedResponse.self, from: data)
        guard let out = Data(base64Encoded: resp.audioBase64), !out.isEmpty else {
            throw PipelineError.watermarkFailed
        }
        return out
    }

    /// 校验水印。
    func detect(audioData: Data) async throws -> WatermarkDetectResult {
        let body: [String: Any] = ["audio": audioData.base64EncodedString()]
        let json = try JSONSerialization.data(withJSONObject: body)
        let url = try endpoint("/watermark/detect")
        let (data, _) = try await client.postJSON(url: url, headers: ["Content-Type": "application/json"], body: json)
        let resp = try Self.decoder.decode(DetectResponse.self, from: data)
        return WatermarkDetectResult(aiLabel: resp.aiLabel, ownerDev: resp.ownerDev,
                                     ownerMusic: resp.ownerMusic, workId: resp.workId,
                                     confidence: resp.confidence, rawPayload: resp.rawPayload)
    }

    private func endpoint(_ path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else {
            throw PipelineError.watermarkFailed
        }
        return url
    }
}

enum PipelineError: Error, LocalizedError {
    case downloadFailed
    case emptyAudio
    case watermarkFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .downloadFailed: return "音频下载失败"
        case .emptyAudio: return "音频为空或损坏"
        case .watermarkFailed: return "水印处理失败"
        case .writeFailed: return "文件写入失败"
        }
    }
}
