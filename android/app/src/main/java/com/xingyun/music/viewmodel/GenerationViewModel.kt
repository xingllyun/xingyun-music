package com.xingyun.music.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.xingyun.music.AppContainer
import com.xingyun.music.data.HistoryEntity
import com.xingyun.music.model.ApiKey
import com.xingyun.music.model.CreationMode
import com.xingyun.music.model.MusicRequest
import com.xingyun.music.model.MusicResult
import com.xingyun.music.model.ModelInfo
import com.xingyun.music.model.ProviderID
import com.xingyun.music.model.WatermarkConfig
import com.xingyun.music.pipeline.WatermarkPayload
import com.xingyun.music.provider.ProviderException
import com.xingyun.music.service.MediaExporter
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class GenerationViewModel(private val container: AppContainer) : ViewModel() {

    data class UiState(
        val selectedProviderId: String = ProviderID.TENCENT,
        val models: List<ModelInfo> = emptyList(),
        val selectedModelId: String = "",
        val mode: String = CreationMode.CUSTOM_LYRICS.wire,
        val lyrics: String = "",
        val prompt: String = "",
        val gender: String = "female",
        val genre: String = "",
        val mood: String = "",
        val timbre: String = "",
        val durationSec: Int = 120,
        val outFormat: String = "mp3",
        val aiLabelOn: Boolean = true,
        val copyrightOn: Boolean = true,
        val verifyAfterOn: Boolean = true,
        val isGenerating: Boolean = false,
        val progressText: String = "",
        val errorMessage: String? = null,
        val lastSuccess: String? = null
    )

    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state

    init {
        onProviderChange(ProviderID.TENCENT)
    }

    fun providers(): List<String> = container.registry.registeredIds()

    fun onProviderChange(providerId: String) {
        val models = container.registry.provider(providerId)?.listModels() ?: emptyList()
        _state.update {
            it.copy(selectedProviderId = providerId, models = models,
                selectedModelId = models.firstOrNull()?.internalId ?: "")
        }
    }

    fun update(f: (UiState) -> UiState) = _state.update(f)

    fun displayName(providerId: String, model: ModelInfo): String =
        container.aliasStore.displayName(providerId, model.internalId, model.defaultName)

    fun generate() {
        val s = _state.value
        viewModelScope.launch {
            _state.update { it.copy(isGenerating = true, errorMessage = null, lastSuccess = null,
                progressText = "正在分配 Key…") }
            try {
                val provider = container.registry.provider(s.selectedProviderId)
                    ?: throw ProviderException("unknown", "未知平台")
                if (container.keyPool.keys(s.selectedProviderId).isEmpty()) {
                    throw ProviderException("no_key", "该平台暂无可用 Key，请先在设置中添加")
                }

                val req = MusicRequest(
                    providerId = s.selectedProviderId,
                    modelId = s.selectedModelId,
                    mode = s.mode,
                    lyrics = if (s.mode == CreationMode.CUSTOM_LYRICS.wire) s.lyrics else null,
                    prompt = s.prompt,
                    gender = if (s.mode == CreationMode.INSTRUMENTAL.wire) null else s.gender,
                    genre = s.genre.ifBlank { null },
                    mood = s.mood.ifBlank { null },
                    timbre = s.timbre.ifBlank { null },
                    durationSec = s.durationSec,
                    outFormat = s.outFormat,
                    watermark = WatermarkConfig(s.aiLabelOn, s.copyrightOn, s.verifyAfterOn)
                )

                val maxAttempts = container.keyPool.keys(s.selectedProviderId).size
                var result: MusicResult? = null
                var usedKey: ApiKey? = null
                var lastError: Exception? = null

                for (i in 0 until maxAttempts) {
                    val key = container.keyPool.selectKey(s.selectedProviderId, null) ?: break
                    try {
                        _state.update { it.copy(progressText = "正在生成（Key：${key.label}）…") }
                        result = provider.generate(req, key)
                        usedKey = key
                        break
                    } catch (e: ProviderException) {
                        container.keyPool.handleFailure(key, e.code.toIntOrNull())
                        lastError = e
                        if (!e.retryable) break
                    } catch (e: Exception) {
                        lastError = e
                        break
                    }
                }

                val r = result
                if (r == null || usedKey == null) {
                    val msg = (lastError as? ProviderException)?.message ?: lastError?.message ?: "生成失败"
                    _state.update { it.copy(errorMessage = msg) }
                    insertHistory(s, req, null, null, null, "failed", msg)
                    return@launch
                }

                if (r.status == "failed") {
                    val msg = r.error?.message ?: "生成失败"
                    _state.update { it.copy(errorMessage = msg) }
                    insertHistory(s, req, null, null, null, "failed", msg)
                    return@launch
                }

                r.usage?.let { container.keyPool.recordUsage(usedKey, it.amount) }

                val audioUrl = r.audioUrl ?: throw ProviderException("bad_response", "平台未返回音频地址")

                _state.update { it.copy(progressText = "正在导出与水印处理…") }
                val payload = WatermarkPayload(
                    aiLabel = s.aiLabelOn,
                    ownerDev = WatermarkPayload.OWNER_DEV_XINGYUN,
                    ownerMusic = WatermarkPayload.OWNER_MUSIC_XIAOKU,
                    workId = nextWorkId()
                )
                val processed = container.pipeline.process(audioUrl, req.watermark, payload, s.outFormat)

                val fileName = "小枯 - ${fileStamp()}-${millisSuffix()}.${s.outFormat}"
                val localFile = MediaExporter.saveToLocal(container.appContext, processed.data, fileName)
                MediaExporter.saveToMediaStore(container.appContext, processed.data, fileName, mimeOf(s.outFormat))

                val model = s.models.firstOrNull { it.internalId == s.selectedModelId }
                val modelName = model?.let { displayName(s.selectedProviderId, it) } ?: s.selectedModelId
                insertHistory(s, req, localFile.absolutePath, modelName, payload.encoded, "success", null, r)
                _state.update { it.copy(progressText = "完成", lastSuccess = modelName) }
            } catch (e: Exception) {
                _state.update { it.copy(errorMessage = e.message ?: "生成失败") }
            } finally {
                _state.update { it.copy(isGenerating = false) }
            }
        }
    }

    private suspend fun insertHistory(
        s: UiState,
        req: MusicRequest,
        outputPath: String?,
        modelName: String?,
        watermarkPayload: Long?,
        status: String,
        errorMessage: String?,
        result: MusicResult? = null
    ) {
        val model = s.models.firstOrNull { it.internalId == s.selectedModelId }
        val name = modelName ?: model?.let { displayName(s.selectedProviderId, it) } ?: s.selectedModelId
        container.historyStore.insert(HistoryEntity(
            id = java.util.UUID.randomUUID().toString(),
            createdAt = System.currentTimeMillis(),
            providerId = s.selectedProviderId,
            modelId = s.selectedModelId,
            modelName = name,
            mode = s.mode,
            lyrics = req.lyrics,
            prompt = req.prompt,
            genre = req.genre,
            mood = req.mood,
            timbre = req.timbre,
            gender = req.gender,
            outputPath = outputPath,
            durationMs = result?.durationMs,
            format = s.outFormat,
            watermarkPayload = watermarkPayload,
            costAmount = result?.usage?.amount,
            costUnit = result?.usage?.unit,
            status = status,
            errorMessage = errorMessage
        ))
    }

    private fun nextWorkId(): Int {
        val prefs = container.appContext.getSharedPreferences("xingyun_settings", Context.MODE_PRIVATE)
        val next = (prefs.getInt("work_id_counter", 0) + 1) % 512
        prefs.edit().putInt("work_id_counter", next).apply()
        return next
    }

    private fun mimeOf(format: String) = when (format) {
        "wav" -> "audio/wav"
        "flac" -> "audio/flac"
        "m4a" -> "audio/mp4"
        else -> "audio/mpeg"
    }

    private fun fileStamp(): String =
        SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(Date())

    /// 毫秒后缀，避免同一秒内多次导出互相覆盖文件名。
    private fun millisSuffix(): String =
        (System.currentTimeMillis() % 1000).toString().padStart(3, '0')

    companion object {
        fun factory(container: AppContainer) = viewModelFactory {
            initializer { GenerationViewModel(container) }
        }
    }
}
