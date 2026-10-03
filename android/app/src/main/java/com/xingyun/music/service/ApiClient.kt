package com.xingyun.music.service

import com.xingyun.music.provider.ProviderException
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.IOException
import java.util.concurrent.TimeUnit

/// 统一网络客户端（OkHttp）。
object ApiClient {
    private val JSON = "application/json; charset=utf-8".toMediaType()
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(120, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .build()

    class HttpException(val statusCode: Int, body: String) : IOException("HTTP $statusCode: $body")

    fun postJson(url: String, headers: Map<String, String>, body: String): String {
        val builder = Request.Builder().url(url)
        headers.forEach { (k, v) -> builder.header(k, v) }
        builder.post(body.toRequestBody(JSON))
        client.newCall(builder.build()).execute().use { resp ->
            val text = resp.body?.string() ?: ""
            if (!resp.isSuccessful) throw HttpException(resp.code, text)
            return text
        }
    }

    fun download(url: String): ByteArray {
        client.newCall(Request.Builder().url(url).build()).execute().use { resp ->
            if (!resp.isSuccessful) throw HttpException(resp.code, "")
            return resp.body?.bytes() ?: ByteArray(0)
        }
    }
}

fun ApiClient.HttpException.toProviderException(): ProviderException = when (statusCode) {
    429 -> ProviderException("429", "请求过于频繁，已触发限流", retryable = true)
    401, 403 -> ProviderException("$statusCode", "鉴权失败（Key 无效或无权限）")
    400 -> ProviderException("400", message ?: "")
    else -> ProviderException("$statusCode", message ?: "", retryable = statusCode >= 500)
}
