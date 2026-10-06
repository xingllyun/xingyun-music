package com.xingyun.music;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

/**
 * 星云音乐后端服务启动入口。
 * 软件版权：星云云络科技；音乐版权：小枯。
 */
@SpringBootApplication
@MapperScan("com.xingyun.music.mapper")
public class XingyunMusicApplication {

    public static void main(String[] args) {
        SpringApplication.run(XingyunMusicApplication.class, args);
    }
}