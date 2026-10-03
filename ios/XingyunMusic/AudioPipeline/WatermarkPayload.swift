import Foundation

/// 双版权隐形水印 Payload（§9.2）。
/// AudioSeal 单段 32-bit，固定分段：
///   bit 0–1  版本/标志（01 表示含版权水印）
///   bit 2    AI 生成标识（1 = AI 辅助生成，配合 GB 45438）
///   bit 3–12 软件/分发主体 ID（星云云络科技）
///   bit 13–22 音乐版权主体 ID（小枯）
///   bit 23–31 作品编号/序号（与本地历史 ID 关联）
struct WatermarkPayload {
    let aiLabel: Bool
    let ownerDev: UInt32
    let ownerMusic: UInt32
    let workId: UInt32

    static let flagVersion: UInt32 = 0b01

    // 主体编号映射表（§9.2）：水印只存编号，校验时本地还原名称
    static let ownerDevXingyun: UInt32 = 1   // 星云云络科技
    static let ownerMusicXiaoKu: UInt32 = 2  // 小枯

    init(aiLabel: Bool, ownerDev: UInt32, ownerMusic: UInt32, workId: UInt32) {
        self.aiLabel = aiLabel
        self.ownerDev = ownerDev & 0x3FF
        self.ownerMusic = ownerMusic & 0x3FF
        self.workId = workId & 0x1FF
    }

    /// 编码为 32-bit payload。
    var encoded: UInt32 {
        var v = Self.flagVersion
        if aiLabel { v |= (1 << 2) }
        v |= (ownerDev & 0x3FF) << 3
        v |= (ownerMusic & 0x3FF) << 13
        v |= (workId & 0x1FF) << 23
        return v
    }

    /// 从 32-bit payload 解码。
    static func decode(_ v: UInt32) -> WatermarkPayload {
        WatermarkPayload(aiLabel: ((v >> 2) & 1) == 1,
                         ownerDev: (v >> 3) & 0x3FF,
                         ownerMusic: (v >> 13) & 0x3FF,
                         workId: (v >> 23) & 0x1FF)
    }

    /// 软件/分发主体名称。
    static func ownerDevName(_ id: UInt32) -> String {
        switch id {
        case ownerDevXingyun: return "星云云络科技"
        default: return "主体#\(id)"
        }
    }

    /// 音乐版权主体名称。
    static func ownerMusicName(_ id: UInt32) -> String {
        switch id {
        case ownerMusicXiaoKu: return "小枯"
        default: return "主体#\(id)"
        }
    }
}
