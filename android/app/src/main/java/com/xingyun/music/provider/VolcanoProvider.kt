package com.xingyun.music.provider

import com.xingyun.music.model.ApiKey
import com.xingyun.music.model.ModelInfo
import com.xingyun.music.model.MusicRequest
import com.xingyun.music.model.MusicResult
import com.xingyun.music.model.ProviderCapabilities
import com.xingyun.music.model.ProviderID
import com.xingyun.music.model.json
import com.xingyun.music.service.ApiClient
import com.xingyun.music.service.toProviderException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.*
import java.security.MessageDigest
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/// 火山引擎 · GenSong（异步 + 火山签名 V4，§5.3）
class VolcanoProvider : MusicProvider {
    override val id = ProviderID.VOLCANO
    private val host = "open.volcengineapi.com"
    private val region = "cn-beijing"
    private val service = "imagination"
    private val version = "2024-08-12"
    private val submitAction = "GenSongForTime"
    private val queryAction = "QuerySong"

    override fun capabilities() = ProviderCapabilities(
        providerId = id,
        supportedModes = listOf("custom_lyrics", "auto_lyrics", "instrumental"),
        supportedFormats = listOf("mp3", "wav"),
        minDurationSec = 30, maxDurationSec = 240, isAsync = true,
        supportedGenres = listOf("Pop", "Rock", "R&B", "Country", "Jazz", "Folk", "Electronic", "Classical", "Hip-Hop"),
        supportedMoods = listOf("Romantic", "Sad", "Happy", "Energetic", "Calm", "Melancholic"),
        supportedTimbres = listOf("Sweet_AUDIO_TIMBRE", "Deep_AUDIO_TIMBRE")
    )

    override fun listModels() = listOf(
        ModelInfo("v4.3", "GenSong V4.3", listOf("参数最全", "推荐")),
        ModelInfo("v4.0", "GenSong V4.0", listOf("默认"))
    )

    override suspend fun healthCheck(key: ApiKey) {
        parseCredentials(key.secret)
    }

    override suspend fun generate(req: MusicRequest, key: ApiKey): MusicResult = withContext(Dispatchers.IO) {
        val (ak, sk) = parseCredentials(key.secret)

        val body = buildJsonObject {
            put("ModelVersion", req.modelId)
            when (req.mode) {
                "instrumental" -> {
                    put("Prompt", req.prompt ?: "")
                    put("Lang", "Instrumental")
                }
                else -> {
                    put("Lyrics", req.lyrics ?: "")
                    put("Lang", "Chinese")
                    req.gender?.let { put("Gender", it.replaceFirstChar { c -> c.uppercase() }) }
                }
            }
            req.genre?.let { put("Genre", it) }
            req.mood?.let { put("Mood", it) }
            req.timbre?.let { put("Timbre", it) }
            req.durationSec?.let { put("Duration", it) }
            put("VodFormat", if (req.outFormat == "wav") "wav" else "mp3")
            put("SkipCopyCheck", false)
            put("ImplicitWaterMark", buildJsonObject {
                put("Enable", true)
                put("ContentProducer", "星云云络科技")
                put("ProduceId", "xy001")
            })
        }.toString()

        val taskId = parseSubmit(postSigned(ak, sk, submitAction, body))

        val deadline = System.currentTimeMillis() + 200_000
        while (System.currentTimeMillis() < deadline) {
            val queryBody = """{"TaskID":"$taskId"}"""
            val r = parseQuery(postSigned(ak, sk, queryAction, queryBody), taskId)
            if (r != null) return@withContext r
            delay(4000)
        }
        throw ProviderException("timeout", "火山生成超时", retryable = true)
    }

    // MARK: - 火山签名 V4

    private fun postSigned(ak: String, sk: String, action: String, body: String): String {
        val (authorization, xDate) = sign(ak, sk, action, body)
        val url = "https://$host?Action=$action&Version=$version"
        try {
            return ApiClient.postJson(url, mapOf(
                "Host" to host,
                "X-Date" to xDate,
                "Authorization" to authorization,
                "Content-Type" to "application/json"
            ), body)
        } catch (e: ApiClient.HttpException) {
            throw e.toProviderException()
        }
    }

    private fun sign(ak: String, sk: String, action: String, body: String): Pair<String, String> {
        val df = SimpleDateFormat("yyyyMMdd'T'HHmmss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }
        val xDate = df.format(Date())
        val shortDate = xDate.take(8)

        val payloadHash = sha256Hex(body)
        val canonicalHeaders = "content-type:application/json\nhost:$host\nx-date:$xDate\n"
        val signedHeaders = "content-type;host;x-date"
        val canonicalRequest = "POST\n/\nAction=$action&Version=$version\n$canonicalHeaders\n$signedHeaders\n$payloadHash"

        val credentialScope = "$shortDate/$region/$service/request"
        val canonicalHash = sha256Hex(canonicalRequest)
        val stringToSign = "HMAC-SHA256\n$xDate\n$credentialScope\n$canonicalHash"

        val kDate = hmac(sk.toByteArray(Charsets.UTF_8), shortDate)
        val kRegion = hmac(kDate, region)
        val kService = hmac(kRegion, service)
        val kSigning = hmac(kService, "request")
        val signature = hmac(kSigning, stringToSign).toHex()

        val authorization = "HMAC-SHA256 Credential=$ak/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature"
        return authorization to xDate
    }

    // MARK: - 解析

    private fun parseSubmit(text: String): String {
        val obj = json.parseToJsonElement(text).jsonObject
        val result = obj["Result"]?.jsonObject ?: throw ProviderException("bad_response", "火山提交响应结构异常")
        return result["TaskID"]?.jsonPrimitive?.content ?: throw ProviderException("bad_response", "缺少 TaskID")
    }

    private fun parseQuery(text: String, taskId: String): MusicResult? {
        val obj = json.parseToJsonElement(text).jsonObject
        val result = obj["Result"]?.jsonObject ?: throw ProviderException("bad_response", "火山查询响应结构异常")
        return when (result["Status"]?.jsonPrimitive?.int) {
            0, 1 -> null
            2 -> {
                val song = result["SongDetail"]?.jsonObject
                val durationMs = song?.get("Duration")?.let {
                    it.jsonPrimitive.doubleOrNull?.let { d -> (d * 1000).toInt() }
                        ?: it.jsonPrimitive.intOrNull?.let { i -> i * 1000 }
                }
                MusicResult(
                    status = "success",
                    audioUrl = song?.get("AudioUrl")?.jsonPrimitive?.contentOrNull,
                    durationMs = durationMs,
                    rawId = taskId,
                    traceId = taskId
                )
            }
            3 -> {
                val fr = result["FailureReason"]?.jsonObject
                throw ProviderException(
                    fr?.get("Code")?.jsonPrimitive?.content ?: "3",
                    fr?.get("Msg")?.jsonPrimitive?.content ?: "生成失败"
                )
            }
            else -> null
        }
    }

    private fun parseCredentials(secret: String): Pair<String, String> {
        val parts = secret.split(":", limit = 2)
        require(parts.size == 2 && parts[0].isNotBlank() && parts[1].isNotBlank()) {
            "火山凭证需为「AK:SK」格式"
        }
        return parts[0] to parts[1]
    }

    // MARK: - 工具

    private fun sha256Hex(s: String): String =
        MessageDigest.getInstance("SHA-256").digest(s.toByteArray(Charsets.UTF_8)).toHex()

    private fun hmac(key: ByteArray, msg: String): ByteArray {
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(key, "HmacSHA256"))
        return mac.doFinal(msg.toByteArray(Charsets.UTF_8))
    }

    private fun ByteArray.toHex() = joinToString("") { "%02x".format(it) }
}
