package com.xingyun.music.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xingyun.music.AppContainer
import com.xingyun.music.model.CreationMode
import com.xingyun.music.model.Gender
import com.xingyun.music.model.platformDisplayName
import com.xingyun.music.viewmodel.GenerationViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateScreen(container: AppContainer) {
    val vm: GenerationViewModel = viewModel(factory = GenerationViewModel.factory(container))
    val s by vm.state.collectAsState()

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)
    ) {
        Text("创作", style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(12.dp))

        // 模式
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            CreationMode.entries.forEach { m ->
                FilterChip(
                    selected = s.mode == m.wire,
                    onClick = { vm.update { it.copy(mode = m.wire) } },
                    label = { Text(m.displayName) }
                )
            }
        }
        Spacer(Modifier.height(12.dp))

        // 平台 / 模型
        DropdownField(
            label = "平台",
            options = vm.providers().map { platformDisplayName(it) to it },
            selected = s.selectedProviderId,
            onSelect = { vm.onProviderChange(it) }
        )
        Spacer(Modifier.height(8.dp))
        DropdownField(
            label = "模型",
            options = s.models.map { vm.displayName(s.selectedProviderId, it) to it.internalId },
            selected = s.selectedModelId,
            onSelect = { id -> vm.update { it.copy(selectedModelId = id) } }
        )
        Spacer(Modifier.height(12.dp))

        // 歌词 / 灵感
        when (s.mode) {
            CreationMode.CUSTOM_LYRICS.wire -> {
                OutlinedTextField(
                    value = s.lyrics,
                    onValueChange = { v -> vm.update { it.copy(lyrics = v) } },
                    label = { Text("歌词（可用 [Verse][Chorus] 分行）") },
                    modifier = Modifier.fillMaxWidth().height(150.dp)
                )
            }
            CreationMode.AUTO_LYRICS.wire -> {
                OutlinedTextField(
                    value = s.prompt,
                    onValueChange = { v -> vm.update { it.copy(prompt = v) } },
                    label = { Text("灵感（自动写词）") },
                    modifier = Modifier.fillMaxWidth().height(100.dp)
                )
            }
            else -> {
                OutlinedTextField(
                    value = s.prompt,
                    onValueChange = { v -> vm.update { it.copy(prompt = v) } },
                    label = { Text("风格 / 情绪 / 场景描述（必填）") },
                    modifier = Modifier.fillMaxWidth().height(100.dp)
                )
            }
        }
        Spacer(Modifier.height(12.dp))

        // 风格参数
        if (s.mode != CreationMode.INSTRUMENTAL.wire) {
            OutlinedTextField(
                value = s.prompt,
                onValueChange = { v -> vm.update { it.copy(prompt = v) } },
                label = { Text("风格描述（如：华语流行浪漫抒情）") },
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Gender.entries.forEach { g ->
                    FilterChip(
                        selected = s.gender == g.wire,
                        onClick = { vm.update { it.copy(gender = g.wire) } },
                        label = { Text(g.displayName) }
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
        }
        OutlinedTextField(
            value = s.genre, onValueChange = { v -> vm.update { it.copy(genre = v) } },
            label = { Text("曲风（可选）") }, modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = s.mood, onValueChange = { v -> vm.update { it.copy(mood = v) } },
            label = { Text("情绪（可选）") }, modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = s.timbre, onValueChange = { v -> vm.update { it.copy(timbre = v) } },
            label = { Text("音色（可选）") }, modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(12.dp))

        // 时长 / 格式
        DropdownField(
            label = "时长（秒）",
            options = listOf("30", "60", "90", "120", "180", "240").map { "${it} 秒" to it.toInt() },
            selected = s.durationSec,
            onSelect = { v -> vm.update { it.copy(durationSec = v) } }
        )
        Spacer(Modifier.height(8.dp))
        DropdownField(
            label = "导出格式",
            options = listOf("MP3", "WAV", "FLAC", "M4A").map { it to it.lowercase() },
            selected = s.outFormat,
            onSelect = { v -> vm.update { it.copy(outFormat = v) } }
        )
        Spacer(Modifier.height(12.dp))

        // 水印开关
        SwitchRow("AI 生成标识", s.aiLabelOn) { v -> vm.update { it.copy(aiLabelOn = v) } }
        SwitchRow("双版权隐形水印", s.copyrightOn) { v -> vm.update { it.copy(copyrightOn = v) } }
        SwitchRow("导出后校验水印", s.verifyAfterOn) { v -> vm.update { it.copy(verifyAfterOn = v) } }
        Spacer(Modifier.height(16.dp))

        Button(
            onClick = { vm.generate() },
            enabled = !s.isGenerating,
            modifier = Modifier.fillMaxWidth()
        ) {
            if (s.isGenerating) {
                CircularProgressIndicator(Modifier.width(18.dp).height(18.dp))
                Spacer(Modifier.width(8.dp))
                Text(s.progressText)
            } else {
                Text("生成歌曲")
            }
        }

        s.errorMessage?.let {
            Spacer(Modifier.height(8.dp))
            Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
        }
        s.lastSuccess?.let {
            Spacer(Modifier.height(8.dp))
            Text("最近完成：$it", style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun SwitchRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label)
        Switch(checked = checked, onCheckedChange = onChange)
    }
}
