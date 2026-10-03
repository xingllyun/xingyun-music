package com.xingyun.music.service

import com.xingyun.music.model.ApiKey

/// Key 池：多 Key 调度与记账（§6）。
class KeyPool(private val keyStore: KeyStore, private val settings: AppSettings) {
    private val rrIndex = mutableMapOf<String, Int>()

    fun keys(providerId: String): List<ApiKey> =
        keyStore.all(providerId).filter { it.enabled && it.status == "active" }

    @Synchronized
    fun selectKey(providerId: String, preferred: String?): ApiKey? {
        val pool = keys(providerId)
        if (preferred != null) pool.firstOrNull { it.id == preferred }?.let { return it }
        if (pool.isEmpty()) return null
        return when (settings.schedulingStrategy) {
            "failover" -> pool.minByOrNull { it.failCount }
            "least_used" -> pool.sortedWith(
                compareByDescending<ApiKey> { it.quotaLimit?.minus(it.quotaUsed) ?: Double.MAX_VALUE }
                    .thenBy { it.lastUsedAt ?: Long.MIN_VALUE }
            ).firstOrNull()
            else -> {
                val idx = (rrIndex[providerId] ?: 0) % pool.size
                rrIndex[providerId] = idx + 1
                pool[idx]
            }
        }
    }

    fun recordUsage(key: ApiKey, amount: Double) {
        keyStore.save(key.copy(quotaUsed = key.quotaUsed + amount, lastUsedAt = System.currentTimeMillis()))
    }

    fun handleFailure(key: ApiKey, statusCode: Int?) {
        val updated = when (statusCode) {
            401, 403 -> key.copy(status = "disabled", enabled = false)
            429 -> key.copy(status = "cooldown")
            else -> key.copy(failCount = key.failCount + 1)
        }
        keyStore.save(updated)
    }
}
