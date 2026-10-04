"""星云音乐 · 双版权隐形水印微服务（方案 A，§9.3 / §13）。

接口：
  POST /watermark/embed   {audio(base64), payload(int), format} -> {audio_base64, format, model_version}
  POST /watermark/detect  {audio(base64)} -> {ai_label, owner_dev, owner_music, work_id, confidence, raw_payload}
  GET  /health            -> {model_version}

说明：
  AudioSeal（Meta）官方生成器为 16-bit 消息。本服务的 32-bit 双版权 payload 按
  「高 16 bit / 低 16 bit」拆成两段，并在时间轴上分段交错嵌入（默认 4 段），
  检测时逐段提取后投票还原，实现 §9.2 要求的「时间冗余多次嵌入」。
"""
import base64
import os
import subprocess
import tempfile

import numpy as np
import soundfile as sf
import torch

try:
    import audioseal

    _GENERATOR = audioseal.load_generator("audioseal_wm_16bits")
    _DETECTOR = audioseal.load_detector("audioseal_detector_16bits")
    MODEL_VERSION = "audioseal_wm_16bits"
except Exception as _e:  # pragma: no cover - 模型加载失败时降级为透传
    _GENERATOR = None
    _DETECTOR = None
    MODEL_VERSION = f"unavailable: {_e}"

from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel

from payload import decode_payload

app = FastAPI(title="星云音乐水印微服务")

TARGET_SR = 44100
NBITS = 16                 # AudioSeal 官方模型消息长度
SEGMENTS = 4               # 时间分段冗余数
MAX_AUDIO_BYTES = 50 * 1024 * 1024  # 50MB 限制（§9.5）
ALLOWED_FORMATS = {"mp3", "wav", "flac", "m4a"}
MIN_WATERMARK_SAMPLES = TARGET_SR  # 至少 1 秒，避免分段为空 / AudioSeal 最短长度问题
API_KEY = os.environ.get("WATERMARK_API_KEY", "")


class EmbedRequest(BaseModel):
    audio: str          # base64
    payload: int        # 32-bit payload
    format: str = "mp3" # 目标格式 mp3/wav/flac/m4a


class EmbedResponse(BaseModel):
    audio_base64: str
    format: str
    model_version: str


class DetectRequest(BaseModel):
    audio: str


class DetectResponse(BaseModel):
    ai_label: bool
    owner_dev: int
    owner_music: int
    work_id: int
    confidence: float
    raw_payload: int


def _check_auth(x_api_key: str | None) -> None:
    if API_KEY and x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="unauthorized")


# ---------------------------------------------------------------------------
# 编解码
# ---------------------------------------------------------------------------

def _decode_audio(data: bytes, target_sr: int) -> np.ndarray:
    """任意格式音频 -> 单声道 float32 波形（FFmpeg 解码）。"""
    with tempfile.NamedTemporaryFile(suffix=".in", delete=False) as f:
        in_path = f.name
    out_path = in_path + ".wav"
    try:
        with open(in_path, "wb") as f:
            f.write(data)
        subprocess.run(
            ["ffmpeg", "-y", "-i", in_path, "-ac", "1", "-ar", str(target_sr),
             "-sample_fmt", "s16", out_path],
            check=True, capture_output=True,
        )
        audio, _ = sf.read(out_path, dtype="float32")
        return audio
    finally:
        for p in (in_path, out_path):
            if os.path.exists(p):
                os.unlink(p)


def _encode_audio(audio: np.ndarray, sr: int, fmt: str) -> bytes:
    """float32 波形 -> 目标格式字节（FFmpeg 编码）。"""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        wav_path = f.name
    out_path = wav_path + "." + fmt
    try:
        sf.write(wav_path, audio, sr, subtype="PCM_16")
        subprocess.run(
            ["ffmpeg", "-y", "-i", wav_path, out_path],
            check=True, capture_output=True,
        )
        with open(out_path, "rb") as f:
            return f.read()
    finally:
        for p in (wav_path, out_path):
            if os.path.exists(p):
                os.unlink(p)


def _to_tensor(audio: np.ndarray) -> torch.Tensor:
    """(samples,) -> (1, 1, samples)。"""
    return torch.from_numpy(audio).unsqueeze(0).unsqueeze(0)


def _int_to_bits(value: int, nbits: int) -> torch.Tensor:
    bits = [(value >> i) & 1 for i in range(nbits)]
    return torch.tensor([bits], dtype=torch.int32)


def _bits_to_int(bits) -> int:
    v = 0
    for i, b in enumerate(bits):
        if b:
            v |= 1 << i
    return v


def _embed_payload(audio: torch.Tensor, payload: int) -> torch.Tensor:
    """32-bit payload -> 高低 16bit 两段，按时间分段交错嵌入。"""
    lo = payload & 0xFFFF
    hi = (payload >> 16) & 0xFFFF
    msgs = {0: _int_to_bits(lo, NBITS), 1: _int_to_bits(hi, NBITS)}

    samples = audio.shape[2]
    seg_len = samples // SEGMENTS
    parts = []
    for i in range(SEGMENTS):
        seg = audio[:, :, i * seg_len:(i + 1) * seg_len]
        parts.append(_GENERATOR(seg, TARGET_SR, msgs[i % 2]))
    return torch.cat(parts, dim=2)


def _detect_payload(audio: torch.Tensor) -> tuple[int, float]:
    """分段检测 + 投票还原 32-bit payload。"""
    samples = audio.shape[2]
    seg_len = samples // SEGMENTS
    lo_candidates, hi_candidates, confidences = [], [], []
    for i in range(SEGMENTS):
        seg = audio[:, :, i * seg_len:(i + 1) * seg_len]
        result, message = _DETECTOR.detect_watermark(seg, TARGET_SR)
        confidences.append(float(result.mean()))
        bits = (message[0] >= 0.5).int().tolist()
        val = _bits_to_int(bits)
        if i % 2 == 0:
            lo_candidates.append(val)
        else:
            hi_candidates.append(val)

    lo = max(set(lo_candidates), key=lo_candidates.count) if lo_candidates else 0
    hi = max(set(hi_candidates), key=hi_candidates.count) if hi_candidates else 0
    payload = (hi << 16) | lo
    confidence = sum(confidences) / len(confidences) if confidences else 0.0
    return payload, confidence


# ---------------------------------------------------------------------------
# 路由
# ---------------------------------------------------------------------------

@app.get("/health")
def health():
    return {"model_version": MODEL_VERSION}


@app.post("/watermark/embed", response_model=EmbedResponse)
def embed(req: EmbedRequest, x_api_key: str | None = Header(default=None)):
    _check_auth(x_api_key)
    try:
        raw = base64.b64decode(req.audio)
    except Exception:
        raise HTTPException(status_code=400, detail="invalid base64 audio")

    if len(raw) > MAX_AUDIO_BYTES:
        raise HTTPException(status_code=413, detail="audio too large")
    if not (0 <= req.payload < (1 << 32)):
        raise HTTPException(status_code=400, detail="payload must be a 32-bit unsigned integer")

    # 白名单校验目标格式，防止把用户输入拼进输出路径（路径穿越）
    fmt = req.format.lower()
    if fmt not in ALLOWED_FORMATS:
        raise HTTPException(status_code=400, detail="unsupported format")

    audio = _decode_audio(raw, TARGET_SR)

    if _GENERATOR is None:
        # 模型不可用时透传（不加水印），保证链路可用
        out_bytes = _encode_audio(audio, TARGET_SR, fmt)
        return EmbedResponse(audio_base64=base64.b64encode(out_bytes).decode(),
                             format=fmt, model_version=MODEL_VERSION)

    if audio.shape[0] < MIN_WATERMARK_SAMPLES:
        raise HTTPException(status_code=400, detail="audio too short for watermarking")

    tensor = _to_tensor(audio)
    watermarked = _embed_payload(tensor, req.payload)
    out_audio = watermarked.squeeze(0).squeeze(0).numpy()
    out_bytes = _encode_audio(out_audio, TARGET_SR, fmt)
    return EmbedResponse(audio_base64=base64.b64encode(out_bytes).decode(),
                         format=fmt, model_version=MODEL_VERSION)


@app.post("/watermark/detect", response_model=DetectResponse)
def detect(req: DetectRequest, x_api_key: str | None = Header(default=None)):
    _check_auth(x_api_key)
    if _DETECTOR is None:
        raise HTTPException(status_code=503, detail="detector unavailable")

    try:
        raw = base64.b64decode(req.audio)
    except Exception:
        raise HTTPException(status_code=400, detail="invalid base64 audio")

    if len(raw) > MAX_AUDIO_BYTES:
        raise HTTPException(status_code=413, detail="audio too large")

    audio = _decode_audio(raw, TARGET_SR)
    if audio.shape[0] < MIN_WATERMARK_SAMPLES:
        raise HTTPException(status_code=400, detail="audio too short")
    payload, confidence = _detect_payload(_to_tensor(audio))
    info = decode_payload(payload)
    return DetectResponse(ai_label=info["ai_label"], owner_dev=info["owner_dev"],
                          owner_music=info["owner_music"], work_id=info["work_id"],
                          confidence=confidence, raw_payload=payload)
