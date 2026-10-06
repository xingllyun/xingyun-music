package com.xingyun.music.util;

/**
 * 设备 UDID 归一化工具。
 * 一机一号锚点：去横线转小写，统一为 40 位小写 hex（iOS）或设备指纹（Android）。
 */
public final class UdidUtil {

    private UdidUtil() {
    }

    /**
     * 归一化 UDID：去除连字符与空白并转小写。
     */
    public static String normalize(String raw) {
        if (raw == null) {
            return null;
        }
        return raw.replace("-", "").trim().toLowerCase();
    }

    /**
     * 校验归一化后的 UDID 是否合法（40 位小写 hex）。
     */
    public static boolean isValid(String normalized) {
        return normalized != null && normalized.matches("[0-9a-f]{40}");
    }
}