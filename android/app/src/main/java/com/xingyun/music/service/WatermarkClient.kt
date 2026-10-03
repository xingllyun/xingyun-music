package com.xingyun.music.service

import android.util.Base64
import com.xingyun.music.model.json
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull
import kotlinx.serialization.json.put

data class WatermarkDetectResult(
    val aiLabel: Boolean,
    val ownerDev: Int,
    val ownerMusic: Int,
    val workId: Int,
    val confidence: Double?,
    val rawPayload: Long?
)

/// 水印微服务客户端（方案 A，§9.3 / §9.5）。
class WatermarkClient(private val settings: AppSettings) {
    private val baseURL: String get() = settings.watermarkServiceURL.trimEnd('/')
    val isConfigured: Boolean get() = baseURL.isNotEmpty()

    suspend fun embed(audio: ByteArray, payload: Long, targetFormat: String): ByteArray =
        withContext(Dispatchers.IO) {
            val body = buildJsonObject {
                put("audio", Base64.encodeToString(audio, Base64.NO_WRAP))
                put("payload", payload)
                put("format", targetFormat)
            }.toString()
            val resp = ApiClient.postJson(
                "$baseURL/watermark/embed",
                mapOf("Content-Type" to "application/json"),
                body
            )
            val obj = json.parseToJsonElement(resp).jsonObject
            val b64 = obj["audio_base64"]?.jsonPrimitive?.contentOrNull ?: ""
            Base64.decode(b64, Base64.NO_WRAP)
        }

    suspend fun detect(audio: ByteArray): WatermarkDetectResult = withContext(Dispatchers.IO) {
        val body = buildJsonObject {
            put("audio", Base64.encodeToString(audio, Base64.NO_WRAP))
        }.toString()
        val resp = ApiClient.postJson(
            "$baseURL/watermark/detect",
            mapOf("Content-Type" to "application/json"),
            body
        )
        val obj = json.parseToJsonElement(resp).jsonObject
        WatermarkDetectResult(
            aiLabel = obj["ai_label"]?.jsonPrimitive?.booleanOrNull ?: false,
            ownerDev = obj["owner_dev"]?.jsonPrimitive?.intOrNull ?: 0,
            ownerMusic = obj["owner_music"]?.jsonPrimitive?.intOrNull ?: 0,
            workId = obj["work_id"]?.jsonPrimitive?.intOrNull ?: 0,
            confidence = obj["confidence"]?.jsonPrimitive?.doubleOrNull,
            rawPayload = obj["raw_payload"]?.jsonPrimitive?.longOrNull
        )
    }
}
