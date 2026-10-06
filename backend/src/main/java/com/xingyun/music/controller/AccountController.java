package com.xingyun.music.controller;

import com.xingyun.music.common.ApiResponse;
import com.xingyun.music.common.BizException;
import com.xingyun.music.common.ErrorCode;
import com.xingyun.music.dto.LoginResponse;
import com.xingyun.music.dto.RegisterRequest;
import com.xingyun.music.service.AccountService;
import com.xingyun.music.util.JwtUtil;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
@RequiredArgsConstructor
public class AccountController {

    private final AccountService accountService;
    private final JwtUtil jwtUtil;

    @PostMapping("/register")
    public ApiResponse<LoginResponse> register(@Valid @RequestBody RegisterRequest req) {
        return ApiResponse.ok(accountService.register(req));
    }

    @GetMapping("/profile")
    public ApiResponse<LoginResponse> profile(@RequestHeader(value = "Authorization", required = false) String auth) {
        Long userId = resolveUserId(auth);
        return ApiResponse.ok(accountService.profile(userId));
    }

    private Long resolveUserId(String auth) {
        if (!StringUtils.hasText(auth) || !auth.startsWith("Bearer ")) {
            throw BizException.of(ErrorCode.NOT_LOGIN);
        }
        Long userId = jwtUtil.parse(auth.substring(7));
        if (userId == null) {
            throw BizException.of(ErrorCode.TOKEN_INVALID);
        }
        return userId;
    }
}