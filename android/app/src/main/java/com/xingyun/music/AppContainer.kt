package com.xingyun.music

import android.content.Context
import com.xingyun.music.data.HistoryStore
import com.xingyun.music.pipeline.AudioPipeline
import com.xingyun.music.provider.AlibabaProvider
import com.xingyun.music.provider.GenericOpenAIProvider
import com.xingyun.music.provider.LocalProvider
import com.xingyun.music.provider.ProviderRegistry
import com.xingyun.music.provider.TencentProvider
import com.xingyun.music.provider.VolcanoProvider
import com.xingyun.music.service.AppSettings
import com.xingyun.music.service.KeyPool
import com.xingyun.music.service.KeyStore
import com.xingyun.music.service.ModelAliasStore
import com.xingyun.music.service.WatermarkClient

/// 全局服务容器：注册 Provider、初始化 Key 池 / 别名 / 历史 / 设置 / 管线。
class AppContainer(context: Context) {
    val appContext: Context = context.applicationContext
    val settings = AppSettings(appContext)
    val keyStore = KeyStore(appContext)
    val aliasStore = ModelAliasStore(appContext)
    val historyStore = HistoryStore(appContext)
    val keyPool = KeyPool(keyStore, settings)
    val watermarkClient = WatermarkClient(settings)
    val pipeline = AudioPipeline(watermarkClient)
    val registry = ProviderRegistry

    init {
        ProviderRegistry.register(TencentProvider())
        ProviderRegistry.register(AlibabaProvider(settings))
        ProviderRegistry.register(VolcanoProvider())
        ProviderRegistry.register(LocalProvider())
        ProviderRegistry.register(GenericOpenAIProvider())
    }
}
