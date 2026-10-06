package com.xingyun.music.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Data;

import java.time.LocalDateTime;

@Data
@TableName("point_accounts")
public class PointAccount {

    @TableId(value = "user_id", type = IdType.INPUT)
    private Long userId;
    private Integer balance;
    private Integer frozen;
    private Integer totalRecharge;
    private Integer totalConsume;
    private LocalDateTime updatedAt;
}