package com.xingyun.music.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.xingyun.music.AppContainer
import com.xingyun.music.model.ApiKey
import com.xingyun.music.model.ModelInfo
import com.xingyun.music.model.ProviderID
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update

class SettingsViewModel(private val container: AppContainer) : ViewModel() {

    val keys: StateFlow<List<ApiKey>> = container.keyStore.keys
    val settings = container.settings
    val aliasStore = container.aliasStore

    data class AddKeyState(
        val providerId: String = ProviderID.TENCENT,
        val label: String = "",
        val secret: String = "",
        val quotaLimit: String = "",
        val notes: String = ""
    )

    private val _addKey = MutableStateFlow(AddKeyState())
    val addKeyState: StateFlow<AddKeyState> = _addKey

    fun updateAddKey(f: (AddKeyState) -> AddKeyState) = _addKey.update(f)

    fun addKey() {
        val s = _addKey.value
        if (s.secret.isBlank()) return
        container.keyStore.save(ApiKey(
            providerId = s.providerId,
            label = s.label.ifBlank { "未命名" },
            secret = s.secret.trim(),
            quotaLimit = s.quotaLimit.toDoubleOrNull(),
            notes = s.notes
        ))
        _addKey.value = AddKeyState()
    }

    fun deleteKey(k: ApiKey) = container.keyStore.delete(k.id)

    fun toggleKey(k: ApiKey) {
        container.keyStore.save(k.copy(enabled = !k.enabled, status = if (!k.enabled) "active" else k.status))
    }

    fun models(providerId: String): List<ModelInfo> =
        container.registry.provider(providerId)?.listModels() ?: emptyList()

    companion object {
        fun factory(container: AppContainer) = viewModelFactory {
            initializer { SettingsViewModel(container) }
        }
    }
}
