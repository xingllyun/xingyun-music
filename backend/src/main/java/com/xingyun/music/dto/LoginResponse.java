package com.xingyun.music.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 登录响应。
 */
public record LoginResponse(
        String token,
        Long userId,
        String nickname,
        String avatar,
        Integer pointBalance
) {
}