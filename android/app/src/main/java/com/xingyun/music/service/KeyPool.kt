package com.xingyun.music.service

import com.xingyun.music.model.ApiKey

/// Key 池：多 Key 调度与记账（§6）。
class KeyPool(private val keyStore: KeyStore, private val settings: AppSettings) {
    private val rrIndex = mutableMapOf<String, Int>()

    companion object {
        /// 429 冷却时长（到期自动恢复）。
        private const val COOLDOWN_MS = 60_000L
    }

    /// 某平台下所有「可用」Key：enabled、非停用、冷却已过期。
    fun keys(providerId: String): List<ApiKey> {
        val now = System.currentTimeMillis()
        return keyStore.all(providerId).filter { isAvailable(it, now) }
    }

    private fun isAvailable(key: ApiKey, now: Long): Boolean {
        if (!key.enabled || key.status == "disabled") return false
        if (key.status == "cooldown") return (key.cooldownUntil ?: Long.MIN_VALUE) <= now
        return true
    }

    @Synchronized
    fun selectKey(providerId: String, preferred: String?): ApiKey? {
        val pool = keys(providerId)
        val chosen: ApiKey? = if (preferred != null) {
            pool.firstOrNull { it.id == preferred }
        } else {
            when (settings.schedulingStrategy) {
                "failover" -> pool.minByOrNull { it.failCount }
                "least_used" -> pool.sortedWith(
                    compareByDescending<ApiKey> { it.quotaLimit?.minus(it.quotaUsed) ?: Double.MAX_VALUE }
                        .thenBy { it.lastUsedAt ?: Long.MIN_VALUE }
                ).firstOrNull()
                else -> {
                    if (pool.isEmpty()) null
                    else {
                        val idx = (rrIndex[providerId] ?: 0) % pool.size
                        rrIndex[providerId] = idx + 1
                        pool[idx]
                    }
                }
            }
        }
        return chosen?.let { reactivateIfCooldownExpired(it) }
    }

    /// 冷却已过期的 Key 恢复为 active 并落盘。
    private fun reactivateIfCooldownExpired(key: ApiKey): ApiKey {
        if (key.status == "cooldown" &&
            (key.cooldownUntil ?: Long.MIN_VALUE) <= System.currentTimeMillis()
        ) {
            val k = key.copy(status = "active", cooldownUntil = null)
            keyStore.save(k)
            return k
        }
        return key
    }

    fun recordUsage(key: ApiKey, amount: Double) {
        keyStore.save(key.copy(quotaUsed = key.quotaUsed + amount, lastUsedAt = System.currentTimeMillis()))
    }

    /// 处理失败：401/403 停用，429 进入冷却（到期自动恢复），其余累计 failCount（§6.2）。
    fun handleFailure(key: ApiKey, statusCode: Int?) {
        val updated = when (statusCode) {
            401, 403 -> key.copy(status = "disabled", enabled = false)
            429 -> key.copy(status = "cooldown", cooldownUntil = System.currentTimeMillis() + COOLDOWN_MS)
            else -> key.copy(failCount = key.failCount + 1)
        }
        keyStore.save(updated)
    }
}
