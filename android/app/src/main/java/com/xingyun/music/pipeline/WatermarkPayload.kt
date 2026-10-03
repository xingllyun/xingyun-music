package com.xingyun.music.pipeline

/// 双版权隐形水印 Payload（§9.2）。
/// bit 0–1 版本标志；bit 2 AI 标识；bit 3–12 软件主体；bit 13–22 音乐版权主体；bit 23–31 作品编号。
data class WatermarkPayload(
    val aiLabel: Boolean,
    val ownerDev: Int,
    val ownerMusic: Int,
    val workId: Int
) {
    val encoded: Long
        get() {
            var v = 0b01L
            if (aiLabel) v = v or (1L shl 2)
            v = v or ((ownerDev.toLong() and 0x3FF) shl 3)
            v = v or ((ownerMusic.toLong() and 0x3FF) shl 13)
            v = v or ((workId.toLong() and 0x1FF) shl 23)
            return v
        }

    companion object {
        const val OWNER_DEV_XINGYUN = 1   // 星云云络科技
        const val OWNER_MUSIC_XIAOKU = 2  // 小枯

        fun decode(v: Long) = WatermarkPayload(
            aiLabel = ((v shr 2) and 1L) == 1L,
            ownerDev = ((v shr 3) and 0x3FF).toInt(),
            ownerMusic = ((v shr 13) and 0x3FF).toInt(),
            workId = ((v shr 23) and 0x1FF).toInt()
        )

        fun ownerDevName(id: Int) = if (id == OWNER_DEV_XINGYUN) "星云云络科技" else "主体#$id"
        fun ownerMusicName(id: Int) = if (id == OWNER_MUSIC_XIAOKU) "小枯" else "主体#$id"
    }
}
