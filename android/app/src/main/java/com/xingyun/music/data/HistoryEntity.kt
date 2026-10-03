package com.xingyun.music.data

import androidx.room.Entity
import androidx.room.PrimaryKey

/// 任务历史记录（§10）。
@Entity(tableName = "history")
data class HistoryEntity(
    @PrimaryKey val id: String,
    val createdAt: Long,
    val providerId: String,
    val modelId: String,
    val modelName: String,
    val mode: String,
    val lyrics: String?,
    val prompt: String?,
    val genre: String?,
    val mood: String?,
    val timbre: String?,
    val gender: String?,
    val outputPath: String?,
    val durationMs: Int?,
    val format: String?,
    val watermarkPayload: Long?,
    val costAmount: Double?,
    val costUnit: String?,
    val status: String,
    val errorMessage: String?
) {
    val statusText: String
        get() = when (status) {
            "success" -> "成功"
            "failed" -> "失败"
            else -> status
        }
}
