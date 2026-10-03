package com.xingyun.music.service

import android.content.Context
import android.content.SharedPreferences

enum class KeySchedulingStrategy(val wire: String, val displayName: String) {
    ROUND_ROBIN("round_robin", "轮询"),
    FAILOVER("failover", "故障转移"),
    LEAST_USED("least_used", "最少使用 / 额度优先");
}

/// 全局设置（SharedPreferences 持久化）。
class AppSettings(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("xingyun_settings", Context.MODE_PRIVATE)

    var aliWorkspaceId: String
        get() = prefs.getString("ali_workspace_id", "") ?: ""
        set(v) = prefs.edit().putString("ali_workspace_id", v).apply()

    var watermarkServiceURL: String
        get() = prefs.getString("watermark_url", "") ?: ""
        set(v) = prefs.edit().putString("watermark_url", v).apply()

    var schedulingStrategy: String
        get() = prefs.getString("key_strategy", KeySchedulingStrategy.ROUND_ROBIN.wire) ?: "round_robin"
        set(v) = prefs.edit().putString("key_strategy", v).apply()
}
