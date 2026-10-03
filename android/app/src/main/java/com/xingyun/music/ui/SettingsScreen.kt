package com.xingyun.music.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xingyun.music.AppContainer
import com.xingyun.music.model.ApiKey
import com.xingyun.music.model.ModelInfo
import com.xingyun.music.model.ProviderID
import com.xingyun.music.model.platformDisplayName
import com.xingyun.music.service.KeySchedulingStrategy
import com.xingyun.music.viewmodel.SettingsViewModel

@Composable
fun SettingsScreen(container: AppContainer) {
    val vm: SettingsViewModel = viewModel(factory = SettingsViewModel.factory(container))
    val keys by vm.keys.collectAsStateWithLifecycle(initialValue = emptyList())

    var showAddKey by remember { mutableStateOf(false) }

    // 本地可编辑的全局设置（写入时回存 SharedPreferences）
    var strategy by remember { mutableStateOf(vm.settings.schedulingStrategy) }
    var workspaceId by remember { mutableStateOf(vm.settings.aliWorkspaceId) }
    var watermarkUrl by remember { mutableStateOf(vm.settings.watermarkServiceURL) }

    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp)) {
        Text("设置", style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(12.dp))

        Text("Key 调度策略", style = MaterialTheme.typography.titleMedium)
        DropdownField(
            label = "策略",
            options = KeySchedulingStrategy.entries.map { it.displayName to it.wire },
            selected = strategy,
            onSelect = { strategy = it; vm.settings.schedulingStrategy = it }
        )
        Spacer(Modifier.height(16.dp))

        Text("API Key 管理", style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        listOf(ProviderID.TENCENT, ProviderID.ALIBABA, ProviderID.VOLCANO).forEach { pid ->
            val providerKeys = keys.filter { it.providerId == pid }
            Card(Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                Column(Modifier.padding(12.dp)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(platformDisplayName(pid), style = MaterialTheme.typography.titleSmall)
                        TextButton(onClick = { showAddKey = true }) { Text("添加 Key") }
                    }
                    if (providerKeys.isEmpty()) {
                        Text("暂无 Key", style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.outline)
                    } else {
                        providerKeys.forEach { k -> KeyRow(k, vm) }
                    }
                }
            }
        }
        Spacer(Modifier.height(16.dp))

        Text("模型自定义名", style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        listOf(ProviderID.TENCENT, ProviderID.ALIBABA, ProviderID.VOLCANO).forEach { pid ->
            vm.models(pid).forEach { m -> ModelAliasRow(pid, m, vm) }
        }
        Spacer(Modifier.height(16.dp))

        Text("服务配置", style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = workspaceId, onValueChange = { workspaceId = it; vm.settings.aliWorkspaceId = it },
            label = { Text("阿里云业务空间 ID（可选）") }, modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(8.dp))
        OutlinedTextField(
            value = watermarkUrl, onValueChange = { watermarkUrl = it; vm.settings.watermarkServiceURL = it },
            label = { Text("水印服务地址（可选，如 https://example.com）") }, modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(16.dp))

        Text(
            "软件著作权：星云云络科技\n音乐作品版权：小枯",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.outline
        )
    }

    if (showAddKey) {
        AddKeyDialog(vm) { showAddKey = false }
    }
}

@Composable
private fun KeyRow(key: ApiKey, vm: SettingsViewModel) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(key.label, style = MaterialTheme.typography.bodyMedium)
            Text(key.maskedSecret, style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.outline)
        }
        Switch(checked = key.enabled, onCheckedChange = { vm.toggleKey(key) })
        TextButton(onClick = { vm.deleteKey(key) }) {
            Text("删除", color = MaterialTheme.colorScheme.error)
        }
    }
}

@Composable
private fun ModelAliasRow(providerId: String, model: ModelInfo, vm: SettingsViewModel) {
    var visible by remember { mutableStateOf(!vm.aliasStore.isHidden(providerId, model.internalId)) }
    var name by remember {
        mutableStateOf(vm.aliasStore.displayName(providerId, model.internalId, model.defaultName))
    }
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Switch(
            checked = visible,
            onCheckedChange = {
                visible = it
                vm.aliasStore.setEnabled(it, providerId, model.internalId)
            }
        )
        Column(Modifier.weight(1f)) {
            Text(model.defaultName, style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.outline)
            OutlinedTextField(
                value = name, onValueChange = {
                    name = it
                    vm.aliasStore.setCustomName(it, providerId, model.internalId)
                },
                label = { Text("自定义名（留空用默认）") },
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
    Spacer(Modifier.height(4.dp))
}

@Composable
private fun AddKeyDialog(vm: SettingsViewModel, onDismiss: () -> Unit) {
    val s = vm.addKeyState.collectAsState()
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("添加 Key") },
        text = {
            Column {
                DropdownField(
                    label = "平台",
                    options = listOf(
                        platformDisplayName(ProviderID.TENCENT) to ProviderID.TENCENT,
                        platformDisplayName(ProviderID.ALIBABA) to ProviderID.ALIBABA,
                        "火山引擎（AK:SK）" to ProviderID.VOLCANO
                    ),
                    selected = s.value.providerId,
                    onSelect = { v -> vm.updateAddKey { st -> st.copy(providerId = v) } }
                )
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = s.value.label, onValueChange = { vm.updateAddKey { st -> st.copy(label = it) } },
                    label = { Text("标签（可选）") }, modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = s.value.secret, onValueChange = { vm.updateAddKey { st -> st.copy(secret = it) } },
                    label = { Text("密钥（火山填 AK:SK）") }, modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = s.value.quotaLimit, onValueChange = { vm.updateAddKey { st -> st.copy(quotaLimit = it) } },
                    label = { Text("额度上限（可选）") }, modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            Button(onClick = { vm.addKey(); onDismiss() }) { Text("保存") }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("取消") }
        }
    )
}
