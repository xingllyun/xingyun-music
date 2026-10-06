package com.xingyun.music.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 设备上报请求（一机一号）。
 */
public record DeviceReportRequest(
        @NotBlank(message = "platform 不能为空") String platform,
        @NotBlank(message = "udid 不能为空") String udid,
        String idfv,
        String androidId,
        String fingerprint,
        String model,
        String osVersion,
        Boolean isEmulator,
        Boolean isRoot
) {
}