package com.xingyun.music.dto;

/**
 * 设备上报响应。
 */
public record DeviceReportResponse(
        Long deviceId,
        boolean bound,
        Long userId,
        String token
) {
}