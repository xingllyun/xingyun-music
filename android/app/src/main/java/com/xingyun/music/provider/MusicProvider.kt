package com.xingyun.music.provider

import com.xingyun.music.model.ApiKey
import com.xingyun.music.model.ModelInfo
import com.xingyun.music.model.MusicRequest
import com.xingyun.music.model.MusicResult
import com.xingyun.music.model.ProviderCapabilities

/// 统一音乐抽象层协议（§4.3）。UI 与业务层只依赖本协议。
interface MusicProvider {
    val id: String
    fun capabilities(): ProviderCapabilities
    fun listModels(): List<ModelInfo>
    suspend fun generate(req: MusicRequest, key: ApiKey): MusicResult
    suspend fun healthCheck(key: ApiKey) {
        if (key.secret.isBlank()) throw ProviderException("invalid_key", "API Key 为空")
    }
}

open class ProviderException(
    val code: String,
    override val message: String,
    val retryable: Boolean = false
) : Exception(message)

object ProviderRegistry {
    private val providers = linkedMapOf<String, MusicProvider>()

    fun register(p: MusicProvider) { providers[p.id] = p }
    fun provider(id: String): MusicProvider? = providers[id]
    fun all(): List<MusicProvider> = providers.values.toList()
    fun registeredIds(): List<String> = providers.keys.toList()
}

/// 预留扩展位（§4.4），先空实现。
class LocalProvider : MusicProvider {
    override val id = com.xingyun.music.model.ProviderID.LOCAL
    override fun capabilities() = ProviderCapabilities(id, emptyList(), emptyList(), 0, 0, false, emptyList(), emptyList(), emptyList())
    override fun listModels(): List<ModelInfo> = emptyList()
    override suspend fun generate(req: MusicRequest, key: ApiKey): MusicResult =
        throw ProviderException("unsupported", "本地模型尚未实现")
}

class GenericOpenAIProvider : MusicProvider {
    override val id = com.xingyun.music.model.ProviderID.GENERIC_OPENAI
    override fun capabilities() = ProviderCapabilities(id, emptyList(), emptyList(), 0, 0, false, emptyList(), emptyList(), emptyList())
    override fun listModels(): List<ModelInfo> = emptyList()
    override suspend fun generate(req: MusicRequest, key: ApiKey): MusicResult =
        throw ProviderException("unsupported", "OpenAI 风格网关尚未实现")
}
