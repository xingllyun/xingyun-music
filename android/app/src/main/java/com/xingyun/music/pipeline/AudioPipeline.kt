package com.xingyun.music.pipeline

import com.xingyun.music.model.WatermarkConfig
import com.xingyun.music.service.ApiClient
import com.xingyun.music.service.WatermarkClient
import com.xingyun.music.service.WatermarkDetectResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File

/// 音频处理与导出管线（§8）。顺序：下载 → 校验 → 水印（服务端转码+嵌入）→ 写入临时文件。
class AudioPipeline(private val watermarkClient: WatermarkClient) {

    data class ProcessedAudio(
        val data: ByteArray,
        val file: File,
        val payload: WatermarkPayload,
        val verified: WatermarkDetectResult?,
        val finalFormat: String
    )

    suspend fun process(
        sourceURL: String,
        config: WatermarkConfig,
        payload: WatermarkPayload,
        outFormat: String
    ): ProcessedAudio = withContext(Dispatchers.IO) {
        // 1. 下载（临时 URL 必须及时转存，§5）
        val raw = ApiClient.download(sourceURL)

        // 2. 校验
        require(raw.size > 1024) { "音频为空或损坏" }

        // 3–5. 水印（服务端 FFmpeg 转码到目标格式 + 冗余嵌入），可选立即校验
        var processed = raw
        var verified: WatermarkDetectResult? = null
        if (config.copyright && watermarkClient.isConfigured) {
            processed = watermarkClient.embed(raw, payload.encoded, outFormat)
            if (config.verifyAfter) {
                verified = watermarkClient.detect(processed)
            }
        }

        // 6. 写入临时文件（最终目录由导出管理落盘）
        val file = File.createTempFile("xingyun-", ".$outFormat")
        file.writeBytes(processed)
        ProcessedAudio(processed, file, payload, verified, outFormat)
    }
}
