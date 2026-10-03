import Foundation

// MARK: - 创作模式（§4.1 mode）

enum CreationMode: String, Codable, CaseIterable, Identifiable {
    case customLyrics = "custom_lyrics"
    case autoLyrics = "auto_lyrics"
    case instrumental = "instrumental"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .customLyrics: return "自定义歌词"
        case .autoLyrics: return "自动写词"
        case .instrumental: return "纯音乐"
        }
    }
}

// MARK: - 音频格式 / 性别

enum AudioFormat: String, Codable, CaseIterable, Identifiable {
    case mp3, wav, flac, m4a
    var id: String { rawValue }
    var mimeType: String {
        switch self {
        case .mp3: return "audio/mpeg"
        case .wav: return "audio/wav"
        case .flac: return "audio/flac"
        case .m4a: return "audio/mp4"
        }
    }
}

enum Gender: String, Codable, CaseIterable {
    case female, male
    var displayName: String {
        switch self {
        case .female: return "女声"
        case .male: return "男声"
        }
    }
}

// MARK: - 水印配置（§4.1 watermark）

struct WatermarkConfig: Codable, Equatable {
    var aiLabel: Bool
    var copyright: Bool
    var verifyAfter: Bool

    static let `default` = WatermarkConfig(aiLabel: true, copyright: true, verifyAfter: true)
}

// MARK: - 标准生成请求（§4.1 MusicRequest）

struct MusicRequest: Codable {
    var providerId: String            // tencent / alibaba / volcano
    var modelId: String               // 内部模型 ID
    var mode: CreationMode
    var lyrics: String?               // 歌词正文，\n 分行，带结构标签
    var prompt: String?               // 风格/情绪/场景
    var gender: Gender?
    var genre: String?
    var mood: String?
    var timbre: String?
    var durationSec: Int?             // 火山 30–240，其余按平台能力
    var outFormat: AudioFormat
    var sampleRate: Int?
    var bitrate: Int?
    var watermark: WatermarkConfig
    var keyRef: String?               // 指定 Key，不指定则由 Key 池自动分配

    init(providerId: String,
         modelId: String,
         mode: CreationMode,
         lyrics: String? = nil,
         prompt: String? = nil,
         gender: Gender? = nil,
         genre: String? = nil,
         mood: String? = nil,
         timbre: String? = nil,
         durationSec: Int? = nil,
         outFormat: AudioFormat = .mp3,
         sampleRate: Int? = 44100,
         bitrate: Int? = 256000,
         watermark: WatermarkConfig = .default,
         keyRef: String? = nil) {
        self.providerId = providerId
        self.modelId = modelId
        self.mode = mode
        self.lyrics = lyrics
        self.prompt = prompt
        self.gender = gender
        self.genre = genre
        self.mood = mood
        self.timbre = timbre
        self.durationSec = durationSec
        self.outFormat = outFormat
        self.sampleRate = sampleRate
        self.bitrate = bitrate
        self.watermark = watermark
        self.keyRef = keyRef
    }
}

// MARK: - 标准生成结果（§4.2 MusicResult）

enum MusicResultStatus: String, Codable {
    case success, processing, failed
}

struct MusicUsage: Codable {
    var amount: Double
    var unit: String
    var providerTokens: Int?
}

struct MusicError: Codable {
    var code: String
    var message: String
    var retryable: Bool
}

struct MusicResult: Codable {
    var status: MusicResultStatus
    var audioUrl: String?
    var audioData: Data?
    var durationMs: Int?
    var sampleRate: Int?
    var channels: Int?
    var bitrate: Int?
    var fileSize: Int?
    var usage: MusicUsage?
    var rawId: String?
    var traceId: String?
    var error: MusicError?
}

// MARK: - Provider 能力声明（§4.3 capabilities）

struct ProviderCapabilities: Codable {
    var providerId: String
    var supportedModes: [CreationMode]
    var supportedFormats: [AudioFormat]
    var minDurationSec: Int
    var maxDurationSec: Int
    var isAsync: Bool
    var supportedGenres: [String]
    var supportedMoods: [String]
    var supportedTimbres: [String]
}

// MARK: - 模型信息（§4.3 listModels）

struct ModelInfo: Codable, Identifiable {
    var internalId: String
    var defaultName: String
    var tags: [String]
    var id: String { internalId }
}

// MARK: - API Key（§6.1）

enum ApiKeyStatus: String, Codable {
    case active, disabled, cooldown
}

struct ApiKey: Codable, Identifiable, Equatable {
    var id: String
    var providerId: String
    var label: String
    var secret: String          // 加密后存 Keychain；火山为 "AK:SK" 组合
    var status: ApiKeyStatus
    var enabled: Bool
    var quotaUsed: Double
    var quotaLimit: Double?
    var lastUsedAt: Date?
    var failCount: Int
    var notes: String

    init(id: String = UUID().uuidString,
         providerId: String,
         label: String,
         secret: String,
         status: ApiKeyStatus = .active,
         enabled: Bool = true,
         quotaUsed: Double = 0,
         quotaLimit: Double? = nil,
         lastUsedAt: Date? = nil,
         failCount: Int = 0,
         notes: String = "") {
        self.id = id
        self.providerId = providerId
        self.label = label
        self.secret = secret
        self.status = status
        self.enabled = enabled
        self.quotaUsed = quotaUsed
        self.quotaLimit = quotaLimit
        self.lastUsedAt = lastUsedAt
        self.failCount = failCount
        self.notes = notes
    }

    /// 掩码显示（§6.3）
    var maskedSecret: String {
        guard secret.count > 6 else { return String(repeating: "*", count: secret.count) }
        let head = secret.prefix(4)
        let tail = secret.suffix(4)
        return "\(head)****\(tail)"
    }
}

// MARK: - 平台标识常量

enum ProviderID {
    static let tencent = "tencent"
    static let alibaba = "alibaba"
    static let volcano = "volcano"
    static let local = "local"
    static let genericOpenAI = "generic_openai"
}

/// 平台显示名。
func platformDisplayName(_ id: String) -> String {
    switch id {
    case ProviderID.tencent: return "腾讯云 TokenHub"
    case ProviderID.alibaba: return "阿里云百炼"
    case ProviderID.volcano: return "火山引擎"
    case ProviderID.local: return "本地模型"
    case ProviderID.genericOpenAI: return "OpenAI 网关"
    default: return id
    }
}
