package com.xingyun.music.data

import android.content.Context
import kotlinx.coroutines.flow.Flow

/// 历史存储（Room）与文件管理（§10）。
class HistoryStore(context: Context) {
    private val appContext = context.applicationContext
    private val dao = AppDatabase.get(context).historyDao()

    fun observe(): Flow<List<HistoryEntity>> = dao.observeAll()

    suspend fun insert(e: HistoryEntity) = dao.insert(e)

    suspend fun delete(id: String, removeFile: Boolean) {
        if (removeFile) {
            dao.getById(id)?.outputPath?.let { p ->
                runCatching { java.io.File(p).delete() }
            }
        }
        dao.delete(id)
    }

    /// 清理孤儿文件（§10.3）。
    suspend fun clearOrphans() {
        val known = dao.getAll().mapNotNull { it.outputPath }
            .map { java.io.File(it).name }.toSet()
        val dir = java.io.File(appContext.filesDir, "Music").apply { mkdirs() }
        dir.listFiles()?.forEach { f ->
            if (f.name !in known) f.delete()
        }
    }
}
