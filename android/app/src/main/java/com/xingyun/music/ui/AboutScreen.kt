package com.xingyun.music.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

/// App 内版权页（§15）。
@Composable
fun AboutScreen() {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        Text("星云音乐", style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(16.dp))

        Section("软件", "本软件由 星云云络科技 开发并享有软件著作权。\n软件版本：1.0.0")
        Section("音乐作品", "本软件生成的音乐作品（含词、曲、编曲、录音制品）相关权利归 小枯 所有。")
        Section("AI 生成说明", "本软件通过第三方音乐大模型生成音频，生成内容可能包含 AI 合成人声。作品在导出时已按规定添加 AI 生成标识及版权水印。")
        Section("开源与授权", "本软件代码公开，但仅授予查看与个人非商业使用权，禁止商用、再分发及用于训练 AI 模型，详见随附 LICENSE。")
        Section("第三方服务", "音频生成能力由 腾讯云、阿里云、火山引擎 提供，相关模型与服务的知识产权归各自权利人所有。")

        HorizontalDivider(Modifier.padding(vertical = 16.dp))
        Text(
            "版权所有 © 2026 星云云络科技；音乐版权 © 小枯。保留所有权利。",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.outline
        )
    }
}

@Composable
private fun Section(title: String, body: String) {
    Column(Modifier.padding(vertical = 8.dp)) {
        Text(title, style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(4.dp))
        Text(body, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}
