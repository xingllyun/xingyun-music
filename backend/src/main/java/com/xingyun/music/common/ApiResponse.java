package com.xingyun.music.common;

/**
 * 统一响应体。约定：code = 0 表示成功，非 0 为业务错误码。
 */
public record ApiResponse<T>(int code, String msg, T data) {

    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(0, "success", data);
    }

    public static ApiResponse<Void> ok() {
        return new ApiResponse<>(0, "success", null);
    }

    public static <T> ApiResponse<T> fail(int code, String msg) {
        return new ApiResponse<>(code, msg, null);
    }
}