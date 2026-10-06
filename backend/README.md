# 星云音乐后端（xingyun-music-server）

星云音乐的后端服务，承载开发文档第 2 章规定的「重逻辑在后端」职责：鉴权、一机一号、计费、会员、订单、卡密、授权、AI 上游编排、音源调度。

- 技术栈：Java 17 · Spring Boot 3.2 · MyBatis-Plus 3.5 · MySQL 8 · Redis · JWT
- 版权：软件版权归星云云络科技，音乐版权归小枯

## 目录结构

```
backend/
├── pom.xml
└── src/main/
    ├── java/com/xingyun/music/
    │   ├── XingyunMusicApplication.java   # 启动入口
    │   ├── common/                        # 统一响应 / 错误码 / 全局异常
    │   ├── config/                        # （预留）安全、MyBatis 配置
    │   ├── controller/                    # 接口层
    │   ├── dto/                           # 请求/响应对象
    │   ├── entity/                        # 表映射实体
    │   ├── mapper/                        # MyBatis-Plus Mapper
    │   ├── service/                       # 业务逻辑
    │   └── util/                          # 工具（JWT / UDID 归一化）
    └── resources/
        ├── application.yml                # 配置（环境变量注入密钥）
        └── db/schema.sql                  # 完整数据库 DDL（文档第 7 章）
```

## 数据库初始化

```bash
mysql -u root -p -e "CREATE DATABASE xingyun_music DEFAULT CHARSET utf8mb4;"
mysql -u root -p xingyun_music < src/main/resources/db/schema.sql
```

## 本地构建与运行

要求 JDK 17 + Maven 3.8+。

```bash
export MYSQL_HOST=localhost MYSQL_USER=root MYSQL_PASSWORD=root
export REDIS_HOST=localhost
export JWT_SECRET=<至少32字节的随机串>
mvn spring-boot:run
```

## 统一响应契约（文档第 8 章）

```json
{ "code": 0, "msg": "success", "data": { } }
```

`code = 0` 表示成功，非 0 对应 `common/ErrorCode.java` 中的业务错误码。

## 已实现接口（M1 · 基础框架 / 登录 / 一机一号）

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/v1/health` | 健康检查 |
| POST | `/api/v1/device/report` | 设备上报（一机一号锚点，已绑定则自动登录） |
| POST | `/api/v1/auth/register` | 注册并绑定设备 |
| GET | `/api/v1/auth/profile` | 当前用户信息（需 `Authorization: Bearer <token>`） |

> 一机一号：`user_devices.udid_norm` 唯一索引，iOS 用归一化 UDID（去横线小写 40 位 hex），Android 用 ANDROID_ID + 复合指纹。

## 后续里程碑

- M2 音源曲库（一主三备调度）
- M3 AI 生成编排（上游多 Key 调度，Key 仅存后端）
- M4 下载授权（买断/共有 + 隐形水印 AudioSeal）
- M5 会员 / 点数 / 卡密 / 易支付
- M6 PHP 管理后台对接
- M8 安全加固（风控、限流、防刷）