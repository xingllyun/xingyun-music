# 水印微服务（方案 A）

基于 FastAPI + AudioSeal（Meta，MIT）的双版权隐形水印服务，FFmpeg 负责格式转换。

## 运行

```bash
pip install -r requirements.txt
uvicorn main:app --reload
```

Docker：

```bash
docker build -t xingyun-watermark .
docker run -p 8000:8000 xingyun-watermark
```

## 接口（§9.5）

### `POST /watermark/embed`
入参：
```json
{ "audio": "<base64>", "payload": 123456, "format": "mp3" }
```
- `payload`：32-bit 双版权 payload（见 `payload.py`，§9.2 分段定义）
- `format`：目标格式 `mp3` / `wav` / `flac` / `m4a`

返回：
```json
{ "audio_base64": "...", "format": "mp3", "model_version": "audioseal_wm_16bits" }
```

### `POST /watermark/detect`
入参：`{ "audio": "<base64>" }`

返回：
```json
{ "ai_label": true, "owner_dev": 1, "owner_music": 2, "work_id": 3, "confidence": 0.99, "raw_payload": 123456 }
```

### `GET /health`
返回当前水印模型版本。

## 安全（§9.5）

- 可选鉴权：设置环境变量 `WATERMARK_API_KEY` 后，请求需带 `X-API-Key` 头。
- 文件大小限制：50MB。
- 原始音频处理完即删，不落盘留存；日志不记录音频内容。

## 实现说明

AudioSeal 官方生成器为 **16-bit 消息**。本服务将 32-bit 双版权 payload 拆为
「高 16 bit / 低 16 bit」两段，在时间轴上分段（默认 4 段）交错嵌入，检测时逐段
提取后投票还原，实现 §9.2 的「时间冗余多次嵌入」与抗剪切能力。
