package com.xingyun.music.service

import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import java.io.File

/// 音频导出：本地 / 媒体库（§12.4）。自建音频无需存储权限。
object MediaExporter {

    /// 保存到系统媒体库（Music/星云音乐）。
    /// API 26–28 无 WRITE_EXTERNAL_STORAGE 权限或媒体库异常时静默降级：
    /// 本地文件(saveToLocal)已保存，不影响生成结果。
    fun saveToMediaStore(context: Context, data: ByteArray, fileName: String, mimeType: String): Uri? {
        return try {
            val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            }
            val values = ContentValues().apply {
                put(MediaStore.Audio.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Audio.Media.MIME_TYPE, mimeType)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Audio.Media.RELATIVE_PATH, "Music/星云音乐")
                }
            }
            val resolver = context.contentResolver
            val uri = resolver.insert(collection, values) ?: return null
            val os = resolver.openOutputStream(uri)
            if (os == null) {
                resolver.delete(uri, null, null)
                null
            } else {
                os.use { it.write(data) }
                uri
            }
        } catch (e: Exception) {
            null
        }
    }

    /// 保存到应用私有目录（Documents/Music 等价物）。
    fun saveToLocal(context: Context, data: ByteArray, fileName: String): File {
        val dir = File(context.filesDir, "Music").apply { mkdirs() }
        val f = File(dir, fileName)
        f.writeBytes(data)
        return f
    }
}
