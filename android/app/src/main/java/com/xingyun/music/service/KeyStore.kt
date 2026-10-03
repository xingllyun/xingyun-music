package com.xingyun.music.service

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.xingyun.music.model.ApiKey
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/// Key 安全存储：Android 用 EncryptedSharedPreferences（§6.3）。
class KeyStore(context: Context) {
    private val masterKey = MasterKey.Builder(context)
        .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
        .build()

    private val prefs = EncryptedSharedPreferences.create(
        context,
        "xingyun_keys",
        masterKey,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    private val _keys = MutableStateFlow(loadAll())
    val keys: StateFlow<List<ApiKey>> = _keys

    private fun loadAll(): List<ApiKey> =
        prefs.all.values.mapNotNull { v ->
            (v as? String)?.let { runCatching { Json.decodeFromString<ApiKey>(it) }.getOrNull() }
        }

    fun save(key: ApiKey) {
        prefs.edit().putString(key.id, Json.encodeToString(key)).apply()
        _keys.value = loadAll()
    }

    fun delete(id: String) {
        prefs.edit().remove(id).apply()
        _keys.value = loadAll()
    }

    fun all(): List<ApiKey> = _keys.value
    fun all(providerId: String): List<ApiKey> = _keys.value.filter { it.providerId == providerId }
}
