package com.xingyun.music.common;

import lombok.Getter;

/**
 * 业务异常。
 */
@Getter
public class BizException extends RuntimeException {

    private final int code;

    public BizException(ErrorCode errorCode) {
        super(errorCode.msg());
        this.code = errorCode.code();
    }

    public BizException(int code, String msg) {
        super(msg);
        this.code = code;
    }

    public static BizException of(ErrorCode errorCode) {
        return new BizException(errorCode);
    }
}