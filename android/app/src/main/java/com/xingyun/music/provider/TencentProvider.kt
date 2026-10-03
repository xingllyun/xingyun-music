package com.xingyun.music.provider

import com.xingyun.music.model.ApiKey
import com.xingyun.music.model.ModelInfo
import com.xingyun.music.model.MusicRequest
import com.xingyun.music.model.MusicResult
import com.xingyun.music.model.MusicUsage
import com.xingyun.music.model.ProviderCapabilities
import com.xingyun.music.model.ProviderID
import com.xingyun.music.model.json
import com.xingyun.music.service.ApiClient
import com.xingyun.music.service.toProviderException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.*

/// 腾讯云 TokenHub · MiniMax Music（同步，§5.1，推荐先接）
class TencentProvider : MusicProvider {
    override val id = ProviderID.TENCENT
    private val endpoint = "https://tokenhub.tencentmaas.com/v1/wand/minimax-music/generation"

    override fun capabilities() = ProviderCapabilities(
        providerId = id,
        supportedModes = listOf("custom_lyrics", "auto_lyrics", "instrumental"),
        supportedFormats = listOf("mp3", "wav"),
        minDurationSec = 0, maxDurationSec = 0, isAsync = false,
        supportedGenres = emptyList(), supportedMoods = emptyList(), supportedTimbres = emptyList()
    )

    override fun listModels() = listOf(
        ModelInfo("minimax-music-v3.0", "MiniMax Music V3.0", listOf("人声自然", "首选")),
        ModelInfo("minimax-music-v2.6", "MiniMax Music V2.6", listOf("稳定"))
    )

    override suspend fun generate(req: MusicRequest, key: ApiKey): MusicResult = withContext(Dispatchers.IO) {
        val body = buildJsonObject {
            put("model", req.modelId)
            when (req.mode) {
                "instrumental" -> { put("is_instrumental", true); put("prompt", req.prompt ?: "") }
                "auto_lyrics" -> {
                    put("lyrics_optimizer", true)
                    req.prompt?.takeIf { it.isNotBlank() }?.let { put("prompt", it) }
                }
                else -> {
                    put("lyrics", req.lyrics ?: "")
                    req.prompt?.takeIf { it.isNotBlank() }?.let { put("prompt", it) }
                }
            }
            put("output_format", "url")
            put("audio_setting", buildJsonObject {
                put("format", if (req.outFormat == "wav") "wav" else "mp3")
                req.sampleRate?.let { put("sample_rate", it) }
                req.bitrate?.let { put("bitrate", it) }
            })
        }.toString()

        try {
            val resp = ApiClient.postJson(
                endpoint,
                mapOf("Authorization" to "Bearer ${key.secret}", "Content-Type" to "application/json"),
                body
            )
            parse(resp)
        } catch (e: ApiClient.HttpException) {
            throw e.toProviderException()
        }
    }

    private fun parse(text: String): MusicResult {
        val obj = json.parseToJsonElement(text).jsonObject
        val base = obj["base_resp"]?.jsonObject
        val code = base?.get("status_code")?.jsonPrimitive?.int ?: -1
        val data = obj["data"]?.jsonObject
        val status = data?.get("status")?.jsonPrimitive?.int
        if (code != 0 || status != 2) {
            val msg = base?.get("status_msg")?.jsonPrimitive?.content ?: "未知错误"
            throw ProviderException("$code", msg)
        }
        val extra = obj["extra_info"]?.jsonObject
        val usage = obj["usage"]?.jsonObject
        val tokens = usage?.get("total_tokens")?.jsonPrimitive?.int
        return MusicResult(
            status = "success",
            audioUrl = data?.get("audio")?.jsonPrimitive?.contentOrNull,
            durationMs = extra?.get("music_duration")?.jsonPrimitive?.int,
            sampleRate = extra?.get("music_sample_rate")?.jsonPrimitive?.int,
            channels = extra?.get("music_channel")?.jsonPrimitive?.int,
            bitrate = extra?.get("bitrate")?.jsonPrimitive?.int,
            fileSize = extra?.get("music_size")?.jsonPrimitive?.int,
            usage = tokens?.let { MusicUsage(it.toDouble(), "tokens", it) },
            traceId = obj["trace_id"]?.jsonPrimitive?.contentOrNull
        )
    }
}
