package com.xingyun.music.model

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

enum class CreationMode(val wire: String, val displayName: String) {
    CUSTOM_LYRICS("custom_lyrics", "自定义歌词"),
    AUTO_LYRICS("auto_lyrics", "自动写词"),
    INSTRUMENTAL("instrumental", "纯音乐");
}

enum class AudioFormat(val wire: String) {
    MP3("mp3"), WAV("wav"), FLAC("flac"), M4A("m4a");
}

enum class Gender(val wire: String, val displayName: String) {
    FEMALE("female", "女声"), MALE("male", "男声");
}

@Serializable
data class WatermarkConfig(
    val aiLabel: Boolean = true,
    val copyright: Boolean = true,
    val verifyAfter: Boolean = true
)

@Serializable
data class MusicRequest(
    val providerId: String,
    val modelId: String,
    val mode: String,
    val lyrics: String? = null,
    val prompt: String? = null,
    val gender: String? = null,
    val genre: String? = null,
    val mood: String? = null,
    val timbre: String? = null,
    val durationSec: Int? = null,
    val outFormat: String = "mp3",
    val sampleRate: Int? = 44100,
    val bitrate: Int? = 256000,
    val watermark: WatermarkConfig = WatermarkConfig(),
    val keyRef: String? = null
)

@Serializable
data class MusicUsage(
    val amount: Double,
    val unit: String,
    val providerTokens: Int? = null
)

@Serializable
data class MusicError(
    val code: String,
    val message: String,
    val retryable: Boolean
)

@Serializable
data class MusicResult(
    val status: String,
    val audioUrl: String? = null,
    val durationMs: Int? = null,
    val sampleRate: Int? = null,
    val channels: Int? = null,
    val bitrate: Int? = null,
    val fileSize: Int? = null,
    val usage: MusicUsage? = null,
    val rawId: String? = null,
    val traceId: String? = null,
    val error: MusicError? = null
)

@Serializable
data class ProviderCapabilities(
    val providerId: String,
    val supportedModes: List<String>,
    val supportedFormats: List<String>,
    val minDurationSec: Int,
    val maxDurationSec: Int,
    val isAsync: Boolean,
    val supportedGenres: List<String>,
    val supportedMoods: List<String>,
    val supportedTimbres: List<String>
)

@Serializable
data class ModelInfo(
    val internalId: String,
    val defaultName: String,
    val tags: List<String>
)

@Serializable
data class ApiKey(
    val id: String = java.util.UUID.randomUUID().toString(),
    val providerId: String,
    val label: String,
    val secret: String,
    val status: String = "active",
    val enabled: Boolean = true,
    val quotaUsed: Double = 0.0,
    val quotaLimit: Double? = null,
    val lastUsedAt: Long? = null,
    val failCount: Int = 0,
    val notes: String = ""
) {
    val maskedSecret: String
        get() = if (secret.length <= 6) "*".repeat(secret.length)
        else secret.take(4) + "****" + secret.takeLast(4)
}

object ProviderID {
    const val TENCENT = "tencent"
    const val ALIBABA = "alibaba"
    const val VOLCANO = "volcano"
    const val LOCAL = "local"
    const val GENERIC_OPENAI = "generic_openai"
}

fun platformDisplayName(id: String): String = when (id) {
    ProviderID.TENCENT -> "腾讯云 TokenHub"
    ProviderID.ALIBABA -> "阿里云百炼"
    ProviderID.VOLCANO -> "火山引擎"
    ProviderID.LOCAL -> "本地模型"
    ProviderID.GENERIC_OPENAI -> "OpenAI 网关"
    else -> id
}

val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
