package com.xingyun.music.common;

/**
 * 业务错误码。遵循开发文档第 9 章错误码体系。
 */
public enum ErrorCode {

    PARAM_ERROR(1001, "参数错误"),
    NOT_LOGIN(1002, "未登录或登录已过期"),
    TOKEN_INVALID(1003, "Token 无效"),
    ACCOUNT_DISABLED(1005, "账号已被封禁"),

    DEVICE_BOUND(2001, "该设备已绑定其他账号"),
    DEVICE_RISK(2002, "设备存在风险，已限制操作"),

    POINT_NOT_ENOUGH(3001, "点数不足"),
    POINT_FREEZE_FAIL(3002, "点数冻结失败"),

    ORDER_NOT_FOUND(4001, "订单不存在"),
    PAY_FAILED(4002, "支付失败"),
    CARD_INVALID(4003, "卡密无效或已被使用"),
    CARD_EXPIRED(4004, "卡密已过期"),

    SONG_OFFLINE(5001, "歌曲已下架"),
    SOURCE_UNAVAILABLE(5002, "音源不可用，请稍后重试"),

    AI_TASK_FAILED(6001, "AI 生成失败"),
    AI_PROVIDER_UNAVAILABLE(6002, "AI 服务暂不可用"),

    LICENSE_FAILED(7001, "授权失败"),

    INTERNAL_ERROR(9000, "系统繁忙，请稍后重试");

    private final int code;
    private final String msg;

    ErrorCode(int code, String msg) {
        this.code = code;
        this.msg = msg;
    }

    public int code() {
        return code;
    }

    public String msg() {
        return msg;
    }
}