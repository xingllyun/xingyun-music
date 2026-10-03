"""双版权隐形水印 Payload（§9.2）。

32-bit 固定分段：
  bit 0–1   版本/标志（01 表示含版权水印）
  bit 2     AI 生成标识（1 = AI 辅助生成，配合 GB 45438）
  bit 3–12  软件/分发主体 ID（星云云络科技 = 1）
  bit 13–22 音乐版权主体 ID（小枯 = 2）
  bit 23–31 作品编号/序号（与本地历史 ID 关联）
"""

OWNER_DEV_XINGYUN = 1
OWNER_MUSIC_XIAOKU = 2


def encode_payload(*, ai_label: bool, owner_dev: int, owner_music: int, work_id: int) -> int:
    """编码为 32-bit payload。"""
    v = 0b01
    if ai_label:
        v |= 1 << 2
    v |= (owner_dev & 0x3FF) << 3
    v |= (owner_music & 0x3FF) << 13
    v |= (work_id & 0x1FF) << 23
    return v


def decode_payload(v: int) -> dict:
    """从 32-bit payload 解码。"""
    return {
        "ai_label": bool((v >> 2) & 1),
        "owner_dev": (v >> 3) & 0x3FF,
        "owner_music": (v >> 13) & 0x3FF,
        "work_id": (v >> 23) & 0x1FF,
    }


def owner_dev_name(owner_dev: int) -> str:
    """软件/分发主体名称（§9.2 映射表）。"""
    return "星云云络科技" if owner_dev == OWNER_DEV_XINGYUN else f"主体#{owner_dev}"


def owner_music_name(owner_music: int) -> str:
    """音乐版权主体名称（§9.2 映射表）。"""
    return "小枯" if owner_music == OWNER_MUSIC_XIAOKU else f"主体#{owner_music}"
