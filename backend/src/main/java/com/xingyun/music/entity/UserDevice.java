package com.xingyun.music.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("user_devices")
public class UserDevice {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long userId;
    private String platform;
    private String udidNorm;
    private String rawUdid;
    private String idfv;
    private String androidId;
    private String fingerprint;
    private String model;
    private String osVersion;
    private Integer isEmulator;
    private Integer isRoot;
    private Integer risk;
    private LocalDateTime firstSeen;
    private LocalDateTime lastSeen;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
}