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
import com.xingyun.music.service.AppSettings
import com.xingyun.music.service.toProviderException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.*

/// 阿里云百炼 · Fun-Music（同步，§5.2，最便宜）
class AlibabaProvider(private val settings: AppSettings) : MusicProvider {
    override val id = ProviderID.ALIBABA
    private val path = "/api/v1/services/audio/music/generation"

    private val endpoint: String
        get() {
            val ws = settings.aliWorkspaceId.trim()
            val host = if (ws.isEmpty()) "dashscope.aliyuncs.com" else "$ws.cn-beijing.maas.aliyuncs.com"
            return "https://$host$path"
        }

    override fun capabilities() = ProviderCapabilities(
        providerId = id,
        supportedModes = listOf("custom_lyrics", "auto_lyrics", "instrumental"),
        supportedFormats = listOf("mp3", "wav"),
        minDurationSec = 0, maxDurationSec = 0, isAsync = false,
        supportedGenres = emptyList(), supportedMoods = emptyList(), supportedTimbres = emptyList()
    )

    override fun listModels() = listOf(
        ModelInfo("fun-music-v1", "Fun-Music V1", listOf("最便宜", "支持性别")),
        ModelInfo("fun-music-preview", "Fun-Music Preview", listOf("预览"))
    )

    override suspend fun generate(req: MusicRequest, key: ApiKey): MusicResult = withContext(Dispatchers.IO) {
        val input = buildJsonObject {
            when (req.mode) {
                "instrumental" -> { put("is_instrumental", true); put("prompt", req.prompt ?: "") }
                "auto_lyrics" -> put("prompt", req.prompt ?: "")
                else -> put("lyrics", req.lyrics ?: "")
            }
            if (req.mode != "instrumental") req.gender?.let { put("gender", it) }
            put("format", if (req.outFormat == "wav") "wav" else "mp3")
            put("enable_aigc_watermark", req.watermark.aiLabel)
        }
        val body = buildJsonObject {
            put("model", req.modelId)
            put("input", input)
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
        val output = obj["output"]?.jsonObject ?: throw ProviderException("bad_response", "阿里响应结构异常")
        val reason = output["finish_reason"]?.jsonPrimitive?.contentOrNull
        if (reason != "stop") throw ProviderException("finish_reason", reason ?: "未完成")

        val audio = output["audio"]?.jsonObject
        val extra = output["extra_info"]?.jsonObject
        val usage = obj["usage"]?.jsonObject
        val durationSec = usage?.get("duration")?.jsonPrimitive?.doubleOrNull

        return MusicResult(
            status = "success",
            audioUrl = audio?.get("url")?.jsonPrimitive?.contentOrNull,
            durationMs = durationSec?.let { (it * 1000).toInt() },
            sampleRate = extra?.get("sample_rate")?.jsonPrimitive?.contentOrNull?.toIntOrNull(),
            channels = extra?.get("channels")?.jsonPrimitive?.int,
            usage = durationSec?.let { MusicUsage(it, "seconds", null) },
            rawId = audio?.get("id")?.jsonPrimitive?.contentOrNull,
            traceId = obj["request_id"]?.jsonPrimitive?.contentOrNull
        )
    }
}
