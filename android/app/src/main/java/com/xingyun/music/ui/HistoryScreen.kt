package com.xingyun.music.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.xingyun.music.AppContainer
import com.xingyun.music.data.HistoryEntity
import com.xingyun.music.model.platformDisplayName
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HistoryScreen(container: AppContainer) {
    val store = container.historyStore
    val records by store.observe().collectAsStateWithLifecycle(initialValue = emptyList())
    val scope = rememberCoroutineScope()

    var query by remember { mutableStateOf("") }
    val filtered = records.filter { r ->
        val q = query.trim()
        q.isEmpty() || r.modelName.contains(q, true) ||
            (r.lyrics?.contains(q, true) == true) || (r.prompt?.contains(q, true) == true)
    }

    Column(Modifier.fillMaxSize().padding(16.dp)) {
        Text("历史", style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = query, onValueChange = { query = it },
            label = { Text("搜索歌词 / 模型") }, modifier = Modifier.fillMaxWidth()
        )
        TextButton(onClick = { scope.launch { store.clearOrphans() } }) { Text("清理孤儿文件") }
        Spacer(Modifier.height(8.dp))

        if (filtered.isEmpty()) {
            Text("暂无记录", color = MaterialTheme.colorScheme.outline)
        } else {
            LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(filtered, key = { it.id }) { r ->
                    HistoryCard(r) {
                        scope.launch { store.delete(r.id, removeFile = true) }
                    }
                }
            }
        }
    }
}

@Composable
private fun HistoryCard(r: HistoryEntity, onDelete: () -> Unit) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(12.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(r.modelName, style = MaterialTheme.typography.titleMedium)
                Text(
                    r.statusText,
                    style = MaterialTheme.typography.bodySmall,
                    color = if (r.status == "success") MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.error
                )
            }
            Text(
                "${platformDisplayName(r.providerId)} · ${r.mode} · ${(r.format ?: "").uppercase()}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.outline
            )
            if (r.status == "failed" && !r.errorMessage.isNullOrBlank()) {
                Text(r.errorMessage, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
            }
            TextButton(onClick = onDelete) { Text("删除（含文件）", color = MaterialTheme.colorScheme.error) }
        }
    }
}
