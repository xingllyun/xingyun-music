package com.xingyun.music.service

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class ModelAlias(
    val providerId: String,
    val internalModelId: String,
    val customName: String,
    val enabled: Boolean,
    val sort: Int
)

/// 模型自定义名称映射（§7）。
class ModelAliasStore(context: Context) {
    private val prefs = context.getSharedPreferences("xingyun_aliases", Context.MODE_PRIVATE)
    private var aliases: MutableList<ModelAlias> = load()

    private fun load(): MutableList<ModelAlias> {
        val s = prefs.getString("aliases", null) ?: return mutableListOf()
        return runCatching { Json.decodeFromString<List<ModelAlias>>(s).toMutableList() }
            .getOrElse { mutableListOf() }
    }

    private fun persist() { prefs.edit().putString("aliases", Json.encodeToString(aliases)).apply() }

    fun isHidden(providerId: String, internalModelId: String): Boolean =
        aliases.any { it.providerId == providerId && it.internalModelId == internalModelId && !it.enabled }

    fun displayName(providerId: String, internalId: String, defaultName: String): String {
        val a = aliases.firstOrNull { it.providerId == providerId && it.internalModelId == internalId && it.enabled }
        return if (a != null && a.customName.isNotBlank()) a.customName else defaultName
    }

    fun setCustomName(name: String, providerId: String, internalModelId: String) {
        val idx = aliases.indexOfFirst { it.providerId == providerId && it.internalModelId == internalModelId }
        if (idx >= 0) aliases[idx] = aliases[idx].copy(customName = name)
        else aliases.add(ModelAlias(providerId, internalModelId, name, true, aliases.size))
        persist()
    }

    fun setEnabled(enabled: Boolean, providerId: String, internalModelId: String) {
        val idx = aliases.indexOfFirst { it.providerId == providerId && it.internalModelId == internalModelId }
        if (idx >= 0) aliases[idx] = aliases[idx].copy(enabled = enabled)
        else aliases.add(ModelAlias(providerId, internalModelId, "", enabled, aliases.size))
        persist()
    }
}
