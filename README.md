# 星云音乐

AI 音乐生成 App，支持 iOS 与 Android。输入歌词或灵感，对接多家云端音乐大模型，一键生成**完整歌曲（带人声）或纯音乐**，并在导出前完成「AI 生成标识 + 双版权隐形水印」，成品可直接上架音乐平台。

> 完整开发依据见随附开发文档（产品定位 / 统一抽象层 / 三家云 API 真实规格 / 水印 / CI 规格）。

## 功能

- **三种创作模式**：自定义歌词 / 自动写词 / 纯音乐（无人声）
- **多平台对接**：腾讯云 TokenHub、阿里云百炼、火山引擎，可批量配置多 Key
- **多 Key 管理**：轮询、故障转移、额度记录
- **模型名称可自定义**：内部模型 ID 与用户可见名称解耦
- **音频导出**：MP3 / WAV / FLAC / M4A，单首与批量，保存本机 / 媒体库 / 系统分享
- **双版权隐形水印 + AI 生成标识**，可开关、可校验
- **任务历史**：本地记录参数、歌词、成品路径、水印信息
- **版权页**：App 内置版权页 + 平台版权声明页

## 目录结构（单仓双端）

```
xingyun-music/
├─ ios/                     # XcodeGen 工程（SwiftUI）
├─ android/                 # Gradle 工程（Jetpack Compose）
├─ watermark-service/       # 可选水印微服务（FastAPI + AudioSeal）
├─ docs/                    # 版权页、平台声明
├─ .github/workflows/build.yml   # 双端 CI/CD
├─ README.md  LICENSE
```

## 快速开始

### iOS（本地开发）
```bash
cd ios
xcodegen generate
open XingyunMusic.xcodeproj
```

### Android（本地开发）
```bash
cd android
./gradlew assembleDebug
```

### 水印微服务（方案 A）
```bash
cd watermark-service
pip install -r requirements.txt
uvicorn main:app --reload
```

### CI/CD
推送 `v*` tag 或手动触发 workflow，将在 GitHub Actions 双 Job 并行产出：
- `build-ios`：未签名 IPA（TrollStore / 牛蛙助手签名安装）
- `build-android`：APK

## 版权

- 软件著作权：**星云云络科技**
- 音乐作品版权：**小枯**

本项目代码公开，但**仅授予查看与个人非商业使用权**，禁止商用、再分发及用于训练 AI 模型，详见 [LICENSE](LICENSE)。

## 合规

- AI 生成音频按《GB 45438—2025》添加显式/隐式标识
- 第三方 API Key 一律存本地安全区（Keychain / Keystore），禁止硬编码、禁止进日志
- 生成内容不得侵权（含翻唱受版权保护作品、套用他人歌词/歌手音色）
