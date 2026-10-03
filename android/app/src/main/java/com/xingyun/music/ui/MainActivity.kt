package com.xingyun.music.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import com.xingyun.music.XingyunApp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                MainScreen()
            }
        }
    }
}

private data class TabItem(val label: String, val icon: ImageVector)

@Composable
fun MainScreen() {
    val app = LocalContext.current.applicationContext as XingyunApp
    val container = app.container

    var selected by rememberSaveable { mutableIntStateOf(0) }
    val tabs = listOf(
        TabItem("创作", Icons.Filled.MusicNote),
        TabItem("历史", Icons.Filled.DateRange),
        TabItem("设置", Icons.Filled.Settings),
        TabItem("关于", Icons.Filled.Info)
    )

    Scaffold(
        bottomBar = {
            NavigationBar {
                tabs.forEachIndexed { idx, t ->
                    NavigationBarItem(
                        selected = selected == idx,
                        onClick = { selected = idx },
                        icon = { Icon(t.icon, contentDescription = t.label) },
                        label = { Text(t.label) }
                    )
                }
            }
        }
    ) { padding ->
        Box(Modifier.padding(padding)) {
            when (selected) {
                0 -> CreateScreen(container)
                1 -> HistoryScreen(container)
                2 -> SettingsScreen(container)
                else -> AboutScreen()
            }
        }
    }
}
