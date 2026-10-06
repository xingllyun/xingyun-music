package com.xingyun.music.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 注册（绑定设备）请求。
 */
public record RegisterRequest(
        @NotBlank(message = "platform 不能为空") String platform,
        @NotBlank(message = "udid 不能为空") String udid,
        @Size(max = 64, message = "昵称过长") String nickname
) {
}